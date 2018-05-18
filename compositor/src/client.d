module composite.client;


import composite;


class OverviewAnimation {
    double[2] size;
    double[2] pos;
    this(int[2] pos, int[2] size){
        this.pos = pos.to!(double[]);
        this.size = size.to!(double[]);
    }
    void approach(int[2] pos, int[2] size){
        auto frt = manager.frameTimer.dur/60.0*config.animationSpeed;
        this.pos.rip(pos.to!(double[2]), 1, 100, frt);
        this.size.rip(size.to!(double[2]), 1, 100, frt);
    }
}


class CompositeClient: ws.wm.Window {

    bool hasAlpha;
    Picture picture;
    Picture resizeGhost;
    Pixmap resizeGhostPixmap;
    int[2] resizeGhostSize;
    Pixmap pixmap;
    XWindowAttributes a;
    bool destroyed;
    long sortIndex;

    ClientAnimation animation;
    OverviewAnimation overviewAnimation;
    common.screens.Screen monitor;
    long syncCounter;
    WindowDamage damage;

    int[2] oldPos;
    int[2] oldSize;
    double oldAlpha;

    int[2] animPos;
    int[2] animSize;
    double[2] animOffset;
    double animScale;
    double animAlpha;
    bool stale = true;
    bool hiddenRedrawn = false;

    Properties!(
        "workspace", "_NET_WM_DESKTOP", XA_CARDINAL, false,
        "tab", "_FLATMAN_TAB", XA_CARDINAL, false,
        "tabs", "_FLATMAN_TABS", XA_CARDINAL, false,
        "dir", "_FLATMAN_TAB_DIR", XA_CARDINAL, false,
        "width", "_FLATMAN_WIDTH", XA_CARDINAL, false,
        "overviewHide", "_FLATMAN_OVERVIEW_HIDE", XA_CARDINAL, false,
        "name", "_NET_WM_NAME", XA_STRING, false,
        "xaname", "WM_NAME", XA_STRING, false,
        "wintype", "_NET_WM_WINDOW_TYPE", XA_ATOM, true
    ) properties;

    override void hide(){}

    this(x11.X.Window window, int[2] pos, int[2] size, XWindowAttributes a){
        super(window);
        this.pos = pos;
        this.size = size;
        this.a = a;
        damage = new WindowDamage(this);
        animation = new ClientAnimation(pos, size);
        overviewAnimation = new OverviewAnimation(pos, size);
        hidden = true;
        isActive = true;
        properties.window(window);
        XSync(wm.displayHandle, false);
        XSelectInput(wm.displayHandle, windowHandle, PropertyChangeMask);
        properties.workspace ~= (long workspace){
            workspaceAnimation(workspace, workspace);
        };
        properties.name ~= (string){
            title = getTitle;
        };
        properties.xaname ~= (string){
            title = getTitle;
        };
        if(a.map_state & IsViewable)
            onShow;
        properties.update;
    }

    bool floating(){
        return properties.tabs.value.max(0) == 0;
    }

    void createPicture(bool force=false){
        if(hidden)
            return;
        stale = false;
        cleanup;
        "create picture".writeln;
        if(!XGetWindowAttributes(wm.displayHandle, windowHandle, &a)){
            "could not get attributes".writeln;
            return;
        }
        if(!(a.map_state & IsViewable))
            return;
        XRenderPictFormat* format = XRenderFindVisualFormat(wm.displayHandle, a.visual);
        if(!format){
            "failed to find format".writeln;
            return;
        }
        hasAlpha = (format.type == PictTypeDirect && format.direct.alphaMask);
        XRenderPictureAttributes pa;
        pa.subwindow_mode = IncludeInferiors;
        pixmap = XCompositeNameWindowPixmap(wm.displayHandle, windowHandle);

        x11.X.Window root_return;
        int int_return;
        uint short_return;

        auto s = XGetGeometry(wm.displayHandle, pixmap, &root_return, &int_return, &int_return, &short_return, &short_return, &short_return, &short_return);
        if(!s){
            "XCompositeNameWindowPixmap failed for ".writeln(windowHandle);
            pixmap = None;
            picture = None;
            return;
        }

        picture = XRenderCreatePicture(wm.displayHandle, pixmap, format, CPSubwindowMode, &pa);
        XRenderSetPictureFilter(wm.displayHandle, picture, "best", null, 0);

        scale = 0;
        resizeGhostScale = 0;
    }

    void cleanup(){
        if(pixmap){
            XFreePixmap(wm.displayHandle, pixmap);
            pixmap = None;
        }
        if(picture){
            XRenderFreePicture(wm.displayHandle, picture);
            picture = None;
        }
    }

    double scale;

    void updateScale(double scale){
        if(this.scale == scale)
            return;
        this.scale = scale;
        XTransform xf = {[
            [XDoubleToFixed( 1 ), XDoubleToFixed( 0 ), XDoubleToFixed( 0 )],
            [XDoubleToFixed( 0 ), XDoubleToFixed( 1 ), XDoubleToFixed( 0 )],
            [XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( scale )]
        ]};
        XRenderSetPictureTransform(wm.displayHandle, picture, &xf);
    }

    double resizeGhostScale;

    void updateResizeGhostScale(double scale){
        if(scale == resizeGhostScale)
            return;
        resizeGhostScale = scale;
        XTransform xf = {[
            [XDoubleToFixed( 1 ), XDoubleToFixed( 0 ), XDoubleToFixed( 0 )],
            [XDoubleToFixed( 0 ), XDoubleToFixed( 1 ), XDoubleToFixed( 0 )],
            [XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( scale )]
        ]};
        XRenderSetPictureTransform(wm.displayHandle, resizeGhost, &xf);
    }

    void destroy(){
        if(pixmap)
            XFreePixmap(wm.displayHandle, pixmap);
        if(picture)
            XRenderFreePicture(wm.displayHandle, picture);
        if(resizeGhostPixmap)
            XFreePixmap(wm.displayHandle, resizeGhostPixmap);
        if(resizeGhost)
            XRenderFreePicture(wm.displayHandle, resizeGhost);
    }

    override void resized(int[2] size){
        if(animation.fade.completion < 0.1)
            animation.size = [size.x, size.y];
        resizeGhostSize = this.size;
        "resize %s %s old %s".format(title, size, this.size).writeln;
        this.size = size;

        if(resizeGhostPixmap)
            XFreePixmap(wm.displayHandle, resizeGhostPixmap);
        resizeGhostPixmap = pixmap;
        pixmap = None;

        if(resizeGhost)
            XRenderFreePicture(wm.displayHandle, resizeGhost);
        resizeGhost = picture;
        picture = None;
        createPicture;
    }

    override void moved(int[2] pos){
        auto monitor = manager.screens[manager.screens.findScreen(pos, size)];
        if(pos.y <= this.pos.y-monitor.h || pos == this.pos)
            return;
        if(properties.workspace.value < 0 || animation.fade.completion < 0.1){
            animation.pos = [pos.x, pos.y];
        }
        this.pos = pos;
    }

    void workspaceAnimation(long ws, long old){
        //moved(pos);
        /+
        if(properties.workspace.value < 0)
            return;
        auto target = ws > properties.workspace.value ? -manager.height+pos.y : manager.height;
        if(ws == properties.workspace.value)
            target = pos.y;
        +/
        /+
        if(target != animation.pos.y.end)
            animation.pos.y.change(target);
        +/
    }

    override void onShow(){
        hidden = false;
        "onShow %s".format(title).writeln;
        stale = true;
        createPicture;
        animation.fade.change(1);
        animation.pos = [pos.x, pos.y];
        animation.size = [size.w, size.h];
    }

    override void onHide(){
        hidden = true;
        "onHide %s".format(title).writeln;
        animation.fade.change(0);
        if(resizeGhostPixmap)
            XFreePixmap(wm.displayHandle, resizeGhostPixmap);
        resizeGhostPixmap = None;
        if(resizeGhost)
            XRenderFreePicture(wm.displayHandle, resizeGhost);
        resizeGhost = None;
    }

    override string toString(){
        return title ~ ":" ~ windowHandle.to!string;
    }

}


class ClientAnimation {

    double[2] pos;
    double[2] size;
    Animation[2] renderOffset;
    Animation fade;
    Animation scale;

    this(int[2] pos, int[2] size){
        enum duration = .3;
        this.pos = [pos.x, pos.y];
        this.size = [size.w, size.h];
        this.renderOffset = [
            new Animation(0, 0, duration/config.animationSpeed, &sinApproach),
            new Animation(0, 0, duration/config.animationSpeed, &sinApproach)
        ];
        fade = new Animation(0, 0, duration/2/config.animationSpeed, &sinApproach);
    }

}
