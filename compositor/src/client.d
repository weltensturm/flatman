module composite.client;


import composite;


import ws.bindings.xlib, common.log;


class ClientFramebuffer {

    Picture picture;
    Pixmap pixmap;
    int[2] size;
    double[2] pictureScale;

    alias picture this;

    bool hasAlpha;

    this(WindowHandle window, XWindowAttributes a){
        XRenderPictFormat* format = XRenderFindVisualFormat(wm.displayHandle, a.visual);
        if(!format){
            "failed to find format".writeln;
            return;
        }
        hasAlpha = (format.type == PictTypeDirect && format.direct.alphaMask);
        XRenderPictureAttributes pa;
        pa.subwindow_mode = IncludeInferiors;
        pixmap = XCompositeNameWindowPixmap(wm.displayHandle, window);

        WindowHandle root_return;
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

    CompositeClient attachedTo;

    mixin WindowProperties!q{
        _NET_WM_DESKTOP        XA_CARDINAL
        _FLATMAN_TAB           XA_CARDINAL
        _FLATMAN_TABS          XA_CARDINAL
        _FLATMAN_TAB_DIR       XA_CARDINAL
        _FLATMAN_WIDTH         XA_CARDINAL
        _FLATMAN_OVERVIEW_HIDE XA_CARDINAL
        _NET_WM_NAME           XA_STRING
        WM_NAME                XA_STRING
        _NET_WM_WINDOW_TYPE    XA_ATOM[]
        _FLATMAN_ATTACH_TO     XA_WINDOW
    };

    override void hide(){}

    this(WindowHandle window, int[2] pos, int[2] size, XWindowAttributes a){
        super(window);
        this.a = a;
        damage = new WindowDamage(this);
        animation = new ClientAnimation(pos, size);
        overviewAnimation = new OverviewAnimation(pos, size);
        hidden = true;
        isActive = true;
        setPropertyWindow(window);
        XSync(wm.displayHandle, false);
        XSelectInput(wm.displayHandle, windowHandle, PropertyChangeMask | StructureNotifyMask);
        _NET_WM_NAME ~= (string){
            title = getTitle;
        };
        WM_NAME ~= (string){
            title = getTitle;
        };
        _FLATMAN_ATTACH_TO ~= (WindowHandle window){
            foreach(client; manager.clients){
                if(client.windowHandle == window){
                    attachedTo = client;
                    return;
                }
            }
        };
        if(a.map_state & IsViewable)
            onShow;
        updateProperties;
        moved(pos);
        this.size = size;
    }

    void damaged(){
        damage.damaged = true;
        stale = false;
    }

    bool floating(){
        return _FLATMAN_TABS.value.max(0) == 0;
    }

    void createPicture(bool force=false){
        if(hidden)
            return;
        Log("create picture");
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
            Log("noswap %s %s %s".format(animation.rect.size, size, stale));
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
        Log("resize %s %s old %s".format(title, size, this.size));
        createPicture;
        this.size = size;
    }

    override void moved(int[2] pos){
        if(pos.y >= manager.height && !a.override_redirect)
            pos.y -= manager.height;
        if(_NET_WM_DESKTOP.value < 0 || animation.fade.completion < 0.1 || a.override_redirect){
            animation.rect.pos = [pos.x, pos.y];
            overviewAnimation.pos.x.replace(pos.x);
            overviewAnimation.pos.y.replace(pos.y);
        }
        if(pos == this.pos)
            return;
        this.pos = pos;
    }

    override void onShow(){
        if(destroyed) // otherwise reparented windows pop up as duplicates
            return;
        hidden = false;
        with(Log(this.to!string ~ " onShow")){
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
        return Log.GREY ~ "%s:%s".format(windowHandle, title) ~ Log.DEFAULT;
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
