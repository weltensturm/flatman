module composite.client;


import composite;


import common.log;


class ClientFramebuffer {

    Picture picture;
    Pixmap pixmap;
    int[2] size;
    double[2] pictureScale;

    alias picture this;

    bool hasAlpha;

    this(x11.X.Window window, XWindowAttributes a){
        XRenderPictFormat* format = XRenderFindVisualFormat(wm.displayHandle, a.visual);
        if(!format){
            "failed to find format".writeln;
            return;
        }
        hasAlpha = (format.type == PictTypeDirect && format.direct.alphaMask);
        XRenderPictureAttributes pa;
        pa.subwindow_mode = IncludeInferiors;
        pixmap = XCompositeNameWindowPixmap(wm.displayHandle, window);

        x11.X.Window root_return;
        int int_return;
        uint short_return;

        auto s = XGetGeometry(wm.displayHandle, pixmap, &root_return, &int_return, &int_return, &short_return,
                              &short_return, &short_return, &short_return);
        if(!s){
            "XCompositeNameWindowPixmap failed for ".writeln(window);
            pixmap = None;
            picture = None;
            return;
        }

        picture = XRenderCreatePicture(wm.displayHandle, pixmap, format, CPSubwindowMode, &pa);
        XRenderSetPictureFilter(wm.displayHandle, picture, "best", null, 0);
        pictureScale = [1,1];
        size = [a.width, a.height];
    }

    ~this(){
        if(pixmap){
            XFreePixmap(wm.displayHandle, pixmap);
            pixmap = None;
        }
        if(picture){
            XRenderFreePicture(wm.displayHandle, picture);
            picture = None;
        }
    }

    void scale(double[2] factor){
        if(pictureScale == factor)
            return;
        pictureScale = factor;
        XTransform xf = {[
            [XDoubleToFixed( 1/factor[0] ), XDoubleToFixed( 0 ), XDoubleToFixed( 0 )],
            [XDoubleToFixed( 0 ), XDoubleToFixed( 1/factor[1] ), XDoubleToFixed( 0 )],
            [XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( 1 )]
        ]};
        XRenderSetPictureTransform(wm.displayHandle, picture, &xf);
    }

}


class CompositeClient: ws.wm.Window {

    ClientFramebuffer picture;
    ClientFramebuffer ghost;

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
    double animGhostAlpha;
    bool stale = true;
    bool hiddenRedrawn;

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
        this.a = a;
        damage = new WindowDamage(this);
        animation = new ClientAnimation(pos, size);
        overviewAnimation = new OverviewAnimation(pos, size);
        hidden = true;
        isActive = true;
        properties.window(window);
        XSync(wm.displayHandle, false);
        XSelectInput(wm.displayHandle, windowHandle, PropertyChangeMask | StructureNotifyMask);
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
        moved(pos);
        this.size = size;
    }

    void damaged(){
        damage.damaged = true;
        stale = false;
    }

    bool floating(){
        return properties.tabs.value.max(0) == 0;
    }

    void createPicture(bool force=false){
        if(hidden)
            return;
        "create picture".writeln;
        if(!XGetWindowAttributes(wm.displayHandle, windowHandle, &a)){
            "could not get attributes".writeln;
            return;
        }
        if(!(a.map_state & IsViewable))
            return;
        if(animation.rect.size == size && !stale){
            // don't swap ghost mid-animation
            ghost = picture;
        }else{
            writeln("noswap ", animation.rect.size, ' ', size, ' ', stale);
        }
        picture = new ClientFramebuffer(windowHandle, a);
        stale = true;
    }

    void destroy(){
        picture = null;
        ghost = null;
    }

    override void resized(int[2] size){
        if(animation.fade.completion < 0.1 || a.override_redirect){
            animation.rect.size = [size.x, size.y];
            overviewAnimation.size.w.change(size.w);
            overviewAnimation.size.h.change(size.h);
        }
        "resize %s %s old %s".format(title, size, this.size).writeln;
        createPicture;
        this.size = size;
    }

    override void moved(int[2] pos){
        if(pos.y >= manager.height && !a.override_redirect)
            pos.y -= manager.height;
        if(properties.workspace.value < 0 || animation.fade.completion < 0.1 || a.override_redirect){
            animation.rect.pos = [pos.x, pos.y];
            overviewAnimation.pos.x.replace(pos.x);
            overviewAnimation.pos.y.replace(pos.y);
        }
        if(pos == this.pos)
            return;
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
        with(Log(this.to!string ~ " onShow")){
            "onShow %s".format(title).writeln;
            createPicture;
            animation.fade.change(1);
            animation.rect.pos = [pos.x, pos.y];
            animation.rect.size = [size.w, size.h];
        }
    }

    override void onHide(){
        hidden = true;
        Log(this.to!string ~ " onHide");
        animation.fade.change(0);
    }

    override string toString(){
        return title ~ ":" ~ windowHandle.to!string;
    }

}


class ClientAnimation {

    RectAnimation rect;
    Animation[2] renderOffset;
    Animation fade;
    Animation scale;

    this(int[2] pos, int[2] size){
        enum duration = .3;
        rect = new RectAnimation(pos, size);
        this.renderOffset = [
            new Animation(0, 0, duration/config.animationSpeed, &sinApproach),
            new Animation(0, 0, duration/config.animationSpeed, &sinApproach)
        ];
        fade = new Animation(0, 0, duration/config.animationSpeed, &sigmoid);
    }

}
