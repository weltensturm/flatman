module composite.backend.xrenderMultiDraw;

version(Posix):


import
    std.string,
    std.algorithm,
    std.math,
    std.conv,
    std.range,
    ws.draw,
    ws.wm,
    ws.bindings.xlib,
    ws.gui.point,
    ws.x.backbuffer,
    ws.x.font,
    composite.util;


class Color {

    ulong pix;
    XftColor rgb;
    long[4] rgba;

    this(Display* dpy, int screen, long[4] values){
        Colormap cmap = DefaultColormap(dpy, screen);
        Visual* vis = DefaultVisual(dpy, screen);
        rgba = values;
        auto name = "#%02x%02x%02x".format(values[0], values[1], values[2]);
        if(!XftColorAllocName(dpy, vis, cmap, name.toStringz, &rgb))
            throw new Exception("Cannot allocate color " ~ name);
        pix = rgb.pixel;
    }

}

class Cur {
    Cursor cursor;
    this(Display* dpy, int shape){
        cursor = XCreateFontCursor(dpy, shape);
    }
    void destroy(Display* dpy){
        XFreeCursor(dpy, cursor);
    }
}

class Icon {
    Picture picture;
    int[2] size;
    ~this(){
        // TODO: fix crash if X connection closes before this is called
        XRenderFreePicture(wm.displayHandle, picture);
    }
}


class ManagedPicture {
    Display* dpy;
    Picture picture;
    alias picture this;
    this(Display* dpy, Drawable drawable, XRenderPictFormat* format){
        this.dpy = dpy;
        XRenderPictureAttributes pa;
        pa.subwindow_mode = IncludeInferiors;
        picture = XRenderCreatePicture(dpy, drawable, format, CPSubwindowMode, &pa);
    }
    ~this(){
        XRenderFreePicture(dpy, picture);
    }
}


struct ClipStack {
    XserverRegion[] stack;
    XRectangle[] rects;

    void push(XserverRegion region){
        XserverRegion newregion = XFixesCreateRegion(wm.displayHandle, null, 0);
        XFixesCopyRegion(wm.displayHandle, newregion, region);
        if(stack.length)
            XFixesIntersectRegion(wm.displayHandle, newregion, stack[$-1], newregion);
        stack ~= newregion;
        rects ~= XRectangle(0, 0, 0, 0);
    }

    void push(int[2] pos, int[2] size){
        XRectangle r = {
            pos.x.to!short,
            pos.y.to!short,
            size.w.max(0).to!ushort,
            size.h.max(0).to!ushort
        };
        XserverRegion region = XFixesCreateRegion(wm.displayHandle, &r, 1);
        
        if(stack.length)
            XFixesIntersectRegion(wm.displayHandle, region, stack[$-1], region);
        stack ~= region;
        rects ~= r;
    }

    void clip(XftDraw* xft, GC gc, Picture picture){
        if(stack.length){
            XftDrawSetClipRectangles(xft, 0, 0, rects.ptr, rects.length.to!uint);
            XFixesSetPictureClipRegion(wm.displayHandle, picture, 0, 0, stack[$-1]);
            if(gc)
                XFixesSetGCClipRegion(wm.displayHandle, gc, 0, 0, stack[$-1]);
        }else{
            if(gc)
                XFixesSetGCClipRegion(wm.displayHandle, gc, 0, 0, None);
            XFixesSetPictureClipRegion(wm.displayHandle, picture, 0, 0, None);
            XftDrawSetClip(xft, null);
        }
    }

    void pop(){
        XFixesDestroyRegion(wm.displayHandle, stack[$-1]);
        stack.length -= 1;
        rects.length -= 1;
    }

    XserverRegion all(){
        return stack[$-1];
    }
}


class PixmapFramebuffer {

    Pixmap pixmap;
    WindowHandle window;
    GC gc;
    int[2] size;
    Display* dpy;

    alias pixmap this;

    this(Display* dpy, WindowHandle window, GC gc, XWindowAttributes* wa, int[2] size){
        this.dpy = dpy;
        this.gc = gc;
        this.window = window;
        pixmap = XCreatePixmap(dpy, window, size.w, size.h, wa.depth);
        this.size = size;
    }

    ~this(){
        XFreePixmap(dpy, pixmap);
    }

}


class XRenderMultiDraw: DrawEmpty {

    RRCrtc crtc;
    int[2] pos;
    int[2] size;
    Display* dpy;
    int screen;
    WindowHandle window;
    Visual* visual;
    XftDraw* xft;
    GC gc;

    Color color;
    Color[long[4]] colors;

    ws.x.font.Font font;
    ws.x.font.Font[string] fonts;

    XserverRegion mask;

    ClipStack clipStack;

    PixmapFramebuffer drawable; // TODO: flatman splits/floating title bars break with this

    ManagedPicture picture;

    this(ws.wm.Window window){
        this(wm.displayHandle, window.windowHandle);
    }

    this(Display* dpy, WindowHandle window){
        XWindowAttributes wa;
        XGetWindowAttributes(dpy, window, &wa);
        this.dpy = dpy;
        screen = DefaultScreen(dpy);
        this.window = window;
        this.size = [1, 1];
        this.gc = XCreateGC(dpy, window, 0, null);
        XSetLineAttributes(dpy, gc, 1, LineSolid, CapButt, JoinMiter);
        drawable = new PixmapFramebuffer(dpy, window, gc, &wa, size);
        xft = XftDrawCreate(dpy, drawable, wa.visual, wa.colormap);
        visual = wa.visual;
        auto format = XRenderFindVisualFormat(dpy, wa.visual);
        picture = new ManagedPicture(dpy, drawable, format);
        initAlpha;
        mask = XFixesCreateRegion(wm.displayHandle, null, 0);
    }

    override int width(string text){
        debug {
            assert(font, "No font active");
        }
        return font.width(text);
    }

    override void resize(int[2] size){
        this.size = size;
        XWindowAttributes wa;
        XGetWindowAttributes(dpy, window, &wa);
        .destroy(picture);
        .destroy(drawable);
        drawable = new PixmapFramebuffer(dpy, window, gc, &wa, size);
        auto format = XRenderFindVisualFormat(dpy, wa.visual);
        picture = new ManagedPicture(dpy, drawable, format);
        XftDrawChange(xft, drawable);
    }

    override void destroy(){
        foreach(font; fonts)
            font.destroy;
        .destroy(drawable);
        .destroy(picture);
        XftDrawDestroy(xft);
        XFreeGC(dpy, gc);
    }

    override void setFont(string font, int size){
        font ~= ":size=%d".format(size);
        if(font !in fonts)
            fonts[font] = new ws.x.font.Font(dpy, screen, font);
        this.font = fonts[font];
    }

    override int fontHeight(){
        return font.h;
    }

    override void setColor(float[3] color){
        setColor([color[0], color[1], color[2], 1]);
    }

    override void setColor(float[4] color){
        long[4] values = [
            (color[0]*255).lround.max(0).min(255),
            (color[1]*255).lround.max(0).min(255),
            (color[2]*255).lround.max(0).min(255),
            (color[3]*255).lround.max(0).min(255)
        ];
        if(values !in colors)
            colors[values] = new Color(dpy, screen, values);
        this.color = colors[values];
    }

    override void clip(int[2] pos, int[2] size){
        clipStack.push(this.pos.a + pos, size);
        clipStack.clip(xft, gc, picture);
    }

    void clip(XserverRegion region){
        XFixesTranslateRegion(wm.displayHandle, region, pos.x, pos.y);
        clipStack.push(region);
        clipStack.clip(xft, gc, picture);
    }

    override void noclip(){
        clipStack.pop;
        clipStack.clip(xft, gc, picture);
    }

    override void rect(int[2] pos, int[2] size){
        auto a = this.color.rgba[3]/255.0;
        XRenderColor color = {
            (this.color.rgba[0]*255*a).to!ushort,
            (this.color.rgba[1]*255*a).to!ushort,
            (this.color.rgba[2]*255*a).to!ushort,
            (this.color.rgba[3]*255).to!ushort
        };
        XRenderFillRectangle(dpy, PictOpOver, picture, &color, this.pos.x + pos.x, this.pos.y + pos.y, size.w, size.h);
    }

    override void rectOutline(int[2] pos, int[2] size){
        clip(pos.a + [1,1], size.a - [2,2]);
        rect(pos, size);
        noclip;
    }

    override void line(int[2] start, int[2] end){
        XSetForeground(dpy, gc, color.pix);
        XDrawLine(dpy, drawable, gc, start.x, start.y, end.x, end.y);
    }

    override int text(int[2] pos, string text, double offset=-0.2){
        if(text.length){
            text = text.replace("\t", "    ");
            auto width = width(text);
            auto fontHeight = font.h;
            auto offsetRight = max(0.0,-offset)*fontHeight;
            auto offsetLeft = max(0.0,offset-1)*fontHeight;
            auto x = this.pos.x + pos.x - min(1,max(0,offset))*width + offsetRight - offsetLeft;
            auto y = this.pos.y + pos.y - 2 + fontHeight;
            XftDrawStringUtf8(xft, &color.rgb, font.xfont, cast(int)x.lround, cast(int)y.lround, cast(ubyte*)text.toStringz, cast(int)text.length);
            return this.width(text);
        }
        return 0;
    }

    override int text(int[2] pos, int h, string text, double offset=-0.2){
        pos.y += ((h-font.h)/2.0).lround;
        return this.text(pos, text, offset);
    }

    void render(Picture picture, bool transparent, double alpha, int[2] offset, int[2] pos, int[2] size){
        auto alphaMask = alpha < 1 ? this.alpha[(alpha*ALPHA_STEPS).to!int] : None;
        XRenderComposite(
            wm.displayHandle,
            (transparent || alpha < 1) ? PictOpOver : PictOpSrc,
            picture,
            alphaMask,
            this.picture,
            offset.x,
            offset.y,
            0,
            0,
            pos.x + this.pos.x,
            pos.y + this.pos.y,
            size.w,
            size.h
        );
    }

    enum ALPHA_STEPS = 256;
    Picture[ALPHA_STEPS] alpha;

    void initAlpha(){
        foreach(i; 0..ALPHA_STEPS){
            if(i < ALPHA_STEPS-1)
                alpha[i] = colorPicture(false, i/cast(float)(ALPHA_STEPS-1), 0, 0, 0);
            else
                alpha[i] = None;
        }
    }

}
