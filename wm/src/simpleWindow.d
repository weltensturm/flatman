module flatman.simpleWindow;


import flatman;

import common.xevents;

class SimpleWindow: Base {

    x11.X.Window window;
    /+
    GlDraw _draw;
    GlContext context;
    +/
    XDraw _draw;
    int[2] cursor;
    float[4] color;

    override DrawEmpty draw(){
        return _draw;
    }

    Split split;
    size_t index;

    this(){
        size = [10,10];

        XVisualInfo* visual;
        visual = new XVisualInfo;
        if(!XMatchVisualInfo(dpy, DefaultScreen(dpy), 32, TrueColor, visual))
            writeln("XMatchVisualInfo failed");

        XSetWindowAttributes wa;
        wa.override_redirect = true;
        wa.background_pixmap = None;
		wa.border_pixmap = None;
		wa.border_pixel = 0;
		wa.bit_gravity = NorthWestGravity;
		wa.colormap = XCreateColormap(dpy, flatman.root, visual.visual, AllocNone);

        window = XCreateWindow(
                dpy,
                flatman.root,
                pos.x, pos.y,
                size.w, size.h,
                0,
                visual.depth,
                CopyFromParent,
                visual.visual,
				CWOverrideRedirect | CWBorderPixel | CWBitGravity | CWColormap | CWBackPixmap,
                &wa
        );

        /+
        context = new GlContext(dpy, window);
        _draw = new GlDraw(context);
        +/
        _draw = new XDraw(dpy, window);
        XSelectInput(dpy, window, ExposureMask | EnterWindowMask | LeaveWindowMask | ButtonPressMask);
        window.replace(Atoms._FLATMAN_OVERVIEW_HIDE, 1L);
        hide;
        Events[window] ~= this;
    }

    @WindowMouseButton
    void mouse(bool pressed, Mouse.button button){
        /+
        if(button == Mouse.buttonLeft && pressed){
            .drag.drag(button, (int[2] cursor){
                int diff;
                if(split.horizontal)
                    diff = pos.x - cursor.x + size.w/2;
                else
                    diff = pos.y - cursor.y + size.h/2;
                if(!diff)
                    return;
                split.sizes[index] -= diff;
                split.sizes[index+1] += diff;
                split.rebuild;
            });

        }
        +/
    }

    override void show(){
        //replace!long(window, Atoms._NET_WM_DESKTOP, monitor.workspaceActive);
        if(size.w > 0 && size.h > 0){
            hidden = false;
            //XMoveWindow(dpy, window, pos.x, pos.y);
            XMapWindow(dpy, window);
        }else
            hide;
    }

    override void hide(){
        hidden = true;
        //XMoveWindow(dpy, window, pos.x, pos.y-monitor.size.h);
        XUnmapWindow(dpy, window);
    }

    void destroy(){
        draw.destroy;
        XDestroyWindow(dpy, window);
        Events.forget(this);
    }

    void moveResize(int[2] pos, int[2] size){
        XMoveResizeWindow(dpy, window, pos.x, pos.y, size.w.max(1), size.h.max(1));
    }

    @WindowMove
    void moved(int[2] pos){
        this.pos = pos;
    }

    @WindowResize
    void resized(int[2] size){
        this.size = size;
        draw.resize(size);
        drawWindow;
    }

    @WindowExpose
    void drawWindow(){
        draw.clear;
        /+
        draw.setColor(color);
        draw.rect([0,0], [size.w, 2]);
        draw.rect([0,size.h-2], [size.w, 2]);
        draw.rect([0,0], [2, size.h]);
        draw.rect([size.w-2,0], [2, size.h]);
        +/
        draw.finishFrame;
    }

}