module composite.main;

import composite.events;
import composite;

import common.event, common.xevents, common.log, common.xerror, std.typecons;



__gshared:


CompositeManager manager;


bool running = true;


extern(C) nothrow @nogc @system void stop(int){
    running = false;
}

auto batterySave = false;


RotatingArray!(30, double) frameTimes;


x11.Xlib.Screen screen;
ulong root;

enum CompositeRedirectAutomatic = 0;
enum CompositeRedirectManual = 1;


void main(){

	version(unittest){ import core.stdc.stdlib: exit; exit(0); }

    Log.setLevel(Log.Level.info);

    try {
        signal(SIGINT, &stop);
        XSetErrorHandler(&xerror);
        Xdbe.init(wm.displayHandle);
        root = XDefaultRootWindow(wm.displayHandle);
        new CompositeManager;
        double lastFrame = now;
        while(running){
            Profile.reset;
            manager.clear;
            with(Profile("events")){
                wm.processEvents((e){
                    if(e.type == 91){
                        handleEvent(e);
                    }else{
                        with(Log(formatEvent(e, root))){
                            handleEvent(e);
                        }
                    }
                });
            }
            if(manager.restack){
                with(Profile("restack")){
                    manager.updateStack;
                    manager.restack = false;
                }
            }
            Tick();
            Profile.damagee(manager.damage);
            manager.draw;
            with(Profile("sleep")){
                auto frame = now;
                frameTimes ~= frame - lastFrame;
                if(frame-lastFrame < 1/144.0)
                    Thread.sleep(((1/144.0 - (frame-lastFrame))*1000).lround.msecs);
                lastFrame = frame;
            }
        }
    }catch(Throwable t){
        writeln(t);
    }
    manager.cleanup;
    Log.shutdown;
}


auto formatEvent(XEvent* ev, WindowHandle root){

    auto dpy = wm.displayHandle;

    auto formatButton = {
        return "%s (%s)".format(ev.xbutton.button, ev.xbutton.state);
    };

    auto formatMotion = {
        return "[%s, %s] root[%s, %s]".format(ev.xmotion.x, ev.xmotion.y, ev.xmotion.x_root, ev.xmotion.y_root);
    };

    auto formatKey = {
        KeySym keysym = XKeycodeToKeysym(dpy, cast(KeyCode)ev.xkey.keycode, 0);
        return "%s %s (%s)".format(ev.xkey.keycode, keysym, ev.xkey.state);
    };

    auto formatWindow(WindowHandle window){
        auto client = manager.find(window);
        if(client)
            return "%s".format(client);
        else if(window == root)
            return Log.RED ~ "%s:root".format(window) ~ Log.DEFAULT;
        else
            return Log.GREY ~ "%s".format(window) ~ Log.DEFAULT;
    }

    alias events = AliasSeq!(
        tuple(ButtonPress,       "ButtonPress",       "xbutton",           () => formatButton()),
        tuple(ButtonRelease,     "ButtonRelease",     "xbutton",           () => formatButton()),

        tuple(MotionNotify,      "MotionNotify",      "xmotion",           () => formatMotion()),

        tuple(ClientMessage,     "ClientMessage",     "xclient",           () => ev.xclient.to!string),
        tuple(ConfigureRequest,  "ConfigureRequest",  "xconfigurerequest", () => ev.xconfigurerequest.to!string),
        tuple(ConfigureNotify,   "ConfigureNotify",   "xconfigure",        () => ev.xconfigure.to!string),
        tuple(CreateNotify,      "CreateNotify",      "xcreatewindow",     () => ev.xcreatewindow.to!string),
        tuple(DestroyNotify,     "DestroyNotify",     "xdestroywindow",    () => ev.xdestroywindow.to!string),
        tuple(EnterNotify,       "EnterNotify",       "xcrossing",         () => ev.xcrossing.to!string),
        tuple(Expose,            "Expose",            "xexpose",           () => ev.xexpose.to!string),
        tuple(FocusIn,           "FocusIn",           "xfocus",            () => ev.xfocus.to!string),
        tuple(FocusOut,          "FocusOut",          "xfocus",            () => ev.xfocus.to!string),
        tuple(KeyPress,          "KeyPress",          "xkey",              () => formatKey()),
        tuple(KeyRelease,        "KeyRelease",        "xkey",              () => formatKey()),
        tuple(MappingNotify,     "MappingNotify",     "",                  () => ""),
        tuple(MapRequest,        "MapRequest",        "xmaprequest",       () => ""),
        tuple(PropertyNotify,    "PropertyNotify",    "xproperty",         () => XGetAtomName(dpy, ev.xproperty.atom).to!string),
        tuple(UnmapNotify,       "UnmapNotify",       "xmap",              () => ""),
        tuple(MapNotify,         "MapNotify",         "xmap",              () => ""),
        tuple(ReparentNotify,    "ReparentNotify",    "xreparent",         () => formatWindow(ev.xreparent.parent))
    );

    static foreach(event; events){
        if(event[0] == ev.type){
            auto msg = "";
            static if(event[2].length){
                auto win = __traits(getMember, ev, event[2]).window;
                msg ~= formatWindow(win);
            }
            return Log.GREY ~ Log.BOLD ~ ev.xany.serial.to!string ~ Log.DEFAULT ~ " " ~ msg ~ " " ~ event[1] ~ " " ~ event[3]();
        }
    }

    return "Event %s".format(ev.type);

}


class CompositeManager {

    FrameTimer frameTimer;
    GLXPixmap glxPixmap;

    int width;
    int height;

    RootDamage damage;
    bool initialRepaint;

    CompositeClient[] clients;
    CompositeClient[] destroyed;
    x11.X.Window[] windows;

    Overview overview;

    common.screens.Screen[int] screens;

    Properties!(
        "workspace", "_NET_CURRENT_DESKTOP", XA_CARDINAL, false,
        "rootmapId", "_XROOTPMAP_ID", XA_PIXMAP, false,
        "setrootId", "_XSETROOT_ID", XA_PIXMAP, false,
        "activeWin", "_NET_ACTIVE_WINDOW", XA_WINDOW, false
    ) properties;

    Pixmap root_pixmap;
    Picture root_picture;
    bool root_tile_fill;

    CompositeClient currentClient;
    CompositeClient lastClient;

    bool restack;

    Backend backend;

    ws.event.Event!(CompositeClient, int[2], int[2]) moved;
    ws.event.Event!(CompositeClient, double) alphaChanged;

    this(){
        config.loadAndWatch(["/etc/flatman/composite.ws", "~/.config/flatman/composite.ws"],
            (string msg, bool){ writeln("CONFIG ERROR\n", msg); });
        manager = this;
        moved = new ws.event.Event!(CompositeClient, int[2], int[2]);
        alphaChanged = new ws.event.Event!(CompositeClient, double);

        debug(XSynchronize){
            XSynchronize(wm.displayHandle, true);
        }

        frameTimer = new FrameTimer;
        damage = new RootDamage;

        width = DisplayWidth(wm.displayHandle, DefaultScreen(wm.displayHandle));
        height = DisplayHeight(wm.displayHandle, DefaultScreen(wm.displayHandle));

        if(config.redirect){
            auto reg_win = XCreateSimpleWindow(wm.displayHandle, RootWindow(wm.displayHandle, 0),
                                               0, 0, 1, 1, 0, None, None);
            if(!reg_win)
                throw new Exception("Failed to create simple window");
            "created simple window".writeln;
            Xutf8SetWMProperties(wm.displayHandle, reg_win,
                    cast(char*)"flatman-compositor".toStringz,
                    cast(char*)"flatman-compositor".toStringz,
                    null, 0, null, null, null);
            Atom a = Atoms._NET_WM_CM_S0;
            XSetSelectionOwner(wm.displayHandle, a, reg_win, 0);
            "selected CM_S0 owner".writeln;

            XCompositeRedirectSubwindows(wm.displayHandle, root, CompositeRedirectManual);
        }else{
            XCompositeRedirectSubwindows(wm.displayHandle, root, CompositeRedirectAutomatic);
        }

        "redirected subwindows".writeln;
        XSelectInput(wm.displayHandle, root,
            SubstructureNotifyMask
            | ExposureMask
            | PropertyChangeMask);

        "created backbuffer".writeln;

        properties.window(.root);

        "looking for windows".writeln;
        foreach(w; queryTree)
            evCreate(false, w);

        //setupVerticalSync;
        overview = new Overview(this);

        if(config.redirect){
            backend = new XRenderBackend;
        }else{
            backend = new XRenderWindowBackend(overview.window);
        }
        backend.resize([width, height]);

        properties.workspace ~= (workspace){
            foreach(c; clients)
                c.workspaceAnimation(workspace, properties.workspace.value);
        };
        properties.update;

        properties.rootmapId ~= (a){ updateWallpaper; };
        properties.setrootId ~= (a){ updateWallpaper; };

        updateWallpaper;
        updateScreens;

        Events ~= this;
    }

    void clear(){
        if(!config.redirect && !overview.visible)
            return;
        damage.reset(clients.map!(a => a.damage));
    }

    void updateScreens(){
		screens = .screens(wm.displayHandle);
    }

    void cleanup(){
        foreach(client; clients)
            client.destroy;
        backend.destroy;
    }

    CompositeClient find(x11.X.Window window){
        foreach(c; clients){
            if(c.windowHandle == window)
                return c;
        }
        return null;
    }

    @WindowCreate
    void evCreate(bool _, x11.X.Window window){
        if(find(window))
            return;
        XWindowAttributes wa;
        if(!XGetWindowAttributes(wm.displayHandle, window, &wa) || wa.c_class == InputOnly)
            return;
        if(overview && overview.window && overview.window.windowHandle == window)
            return;
        auto client = new CompositeClient(window, [wa.x,wa.y], [wa.width,wa.height], wa);
        client.workspaceAnimation(client.properties.workspace, client.properties.workspace);
        "found window %s".format(window).writeln;
        clients ~= client;
    }

    @WindowDestroy
    void evDestroy(x11.X.Window window){
        if(auto c = find(window)){
            if(!c.destroyed){
                Log(Log.RED ~ "destroyed" ~ Log.DEFAULT);
                c.destroyed = true;
                c.onHide;
                restack = true;
                return;
            }
        }
    }

    @WindowReparent
    void evReparent(WindowHandle window, WindowHandle parent){
        if(parent != .root)
            evDestroy(window);
        else
            evCreate(false, window);
    }

    @WindowConfigure
    void evConfigure(WindowHandle window, XConfigureEvent* e){
        if(window == .root){
            updateScreens,
            backend.resize([e.width, e.height]);
            width = e.width;
            height = e.height;
        }
    }

    @WindowMap
    void evMap(WindowHandle window){
        if(auto c = find(window))
            c.onShow;
    }

    @WindowUnmap
    void evUnmap(WindowHandle window){
        if(auto c = find(window))
            c.onHide;
    }

    @WindowProperty
    void evProperty(WindowHandle window, XPropertyEvent* e){
        if(window == root){
            properties.update(e);
        }else{
            if(auto c = find(window))
                c.properties.update(e);
        }
    }

    @XorgEvent
    void onEvent(XEvent* e){
        if(e.type == ConfigureNotify){
            if(auto c = find(e.xconfigure.window)){
                c.processEvent(e);
                restack = true;
            }
        }
    }

    void updateWallpaper(){
        root_tile_fill = false;
        bool fill = false;
        Pixmap pixmap = None;
        foreach(bgprop; [properties.rootmapId, properties.setrootId]){
            if(auto res = bgprop.get){
                writeln(bgprop.name, " ", res);
                pixmap = res;
                break;
            }
        }
		auto visual = DefaultVisual(wm.displayHandle, 0);
		auto depth = DefaultDepth(wm.displayHandle, 0);

        if(root_picture)
            X.RenderFreePicture(wm.displayHandle, root_picture);
        if(root_pixmap && root_tile_fill)
            X.FreePixmap(wm.displayHandle, root_pixmap);
        if(!pixmap){
            pixmap = X.CreatePixmap(wm.displayHandle, root, 1, 1, depth);
            fill = true;
        }
        XRenderPictureAttributes pa;
        pa.repeat = True,
        root_picture = X.RenderCreatePicture(wm.displayHandle, pixmap, X.RenderFindVisualFormat(wm.displayHandle, visual), CPRepeat, &pa);
        if(fill){
            XRenderColor c;
            c.red = c.green = c.blue = 0x8080;
            c.alpha = 0xffff;
            X.RenderFillRectangle(wm.displayHandle, PictOpSrc, root_picture, &c, 0, 0, 1, 1);
        }
        root_tile_fill = fill;
        root_pixmap = pixmap;
        foreach(screen; screens){
            damage.damage([screen.x, screen.y], [screen.w, screen.h]);
        }
        writeln("updating wallpaper ", root_picture);
    }

    void updateStack(){
        // TODO: keep destroyed in-place instead of drawing above all others
        auto destroyedOld = destroyed;
        destroyed = [];
        foreach(c; clients ~ destroyedOld){
            if(c.destroyed){
                if(c.animation.fade.calculate > 0)
                    destroyed ~= c;
                else{
					applyDamage(c);
                    c.destroy;
				}
            }
        }
        clients = clients.filter!"!a.destroyed".array;

        foreach(i, window; queryTree){
            if(auto c = find(window))
                c.sortIndex = i;
        }

        clients.sort!((a, b) => a.sortIndex < b.sortIndex);
    }

    x11.X.Window vsyncWindow;

    void setupVerticalSync(){
        GLint[] att = [GLX_RGBA, GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, 0];
        auto graphicsInfo = glXChooseVisual(wm.displayHandle, 0, att.ptr);
        auto graphicsContext = glXCreateContext(wm.displayHandle, graphicsInfo, null, True);
        writeln(graphicsContext);
        vsyncWindow = XCreateSimpleWindow(wm.displayHandle, root, 0, 0, 1, 1, 0, 0, 0);
        //XMapWindow(wm.displayHandle, vsyncWindow);
        glXMakeCurrent(wm.displayHandle, cast(uint)vsyncWindow, cast(__GLXcontextRec*)graphicsContext);

    }

    void setupVerticalSyncPixmap(){
        /+
        import derelict.opengl3.glx;
        import derelict.opengl3.glxext;

        int[] pixmap_attribs = [
            GLX_TEXTURE_TARGET_EXT, GLX_TEXTURE_2D_EXT,
            GLX_TEXTURE_FORMAT_EXT, GLX_TEXTURE_FORMAT_RGB_EXT,
            None
        ];
        glxPixmap = glXCreatePixmap(wm.displayHandle, null, cast(uint)backBuffer, pixmap_attribs.ptr);

        GLint[] att = [GLX_RGBA, GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, 0];
        auto graphicsInfo = glXChooseVisual(wm.displayHandle, 0, att.ptr);
        auto graphicsContext = glXCreateContext(wm.displayHandle, graphicsInfo, null, True);
        glXMakeCurrent(wm.displayHandle, cast(uint)glxPixmap, cast(__GLXcontextRec*)graphicsContext);
        +/

    }

    void verticalSync(){
        glXSwapBuffers(wm.displayHandle, cast(uint)vsyncWindow);
        glFinish();
    }

    void verticalSyncDraw(){
        glViewport(0,0,width,height);
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0,1,0,1,0,1);
        glMatrixMode(GL_MODELVIEW);

        glBegin(GL_QUADS);
        glVertex2f(0,0);
        glVertex2f(1,0);
        glVertex2f(1,1);
        glVertex2f(0,1);
        glEnd();
        glXSwapBuffers(wm.displayHandle, cast(uint)vsyncWindow);
    }

    void animate(CompositeClient c){
        c.animScale = 1;//alpha/4+0.75;
        c.animAlpha = c.animation.fade.calculate;
        if(c.ghost && c.animation.rect.size != c.size){
            auto transition = ((c.animSize.w - c.ghost.size.w.to!double)/(c.size.x - c.ghost.size.w.to!double)
                            .min((c.animSize.h - c.ghost.size.h.to!double)/(c.size.h - c.ghost.size.h.to!double))
                            ).min(1).max(0);
            c.animGhostAlpha = (1-transition);
        }else{
            c.animGhostAlpha = 0;
        }
        c.animPos = [
            c.animation.rect.pos.x.lround.to!int,
            c.animation.rect.pos.y.lround.to!int
        ];
        c.animOffset = [
            c.animation.renderOffset.x.calculate.lround.to!int,
            c.animation.renderOffset.y.calculate.lround.to!int
        ];
        c.animSize = [
            c.animation.rect.size.x.lround.to!int,
            c.animation.rect.size.y.lround.to!int
        ];
        overview.calcWindow(c, c.animPos, c.animOffset, c.animSize, c.animScale, c.animAlpha, c.animGhostAlpha);
        if(c.animPos != c.oldPos || c.animSize != c.oldSize){
            moved(c, c.animPos, c.animSize);
            c.oldPos = c.animPos;
            c.oldSize = c.animSize;
        }
        if(c.animAlpha != c.oldAlpha){
            alphaChanged(c, c.animAlpha);
            c.oldAlpha = c.animAlpha;
        }
    }

    void applyDamage(CompositeClient c){
        if(c.destroyed){
            damage.damage(c.animPos, c.animSize);
            return;
        }
        foreach(a; c.damage.areas){
            damage.damage(
                [
                    c.animPos.x + (a.x.to!double/c.size.w*c.animSize.w).lround.to!int,
                    c.animPos.y + (a.y.to!double/c.size.h*c.animSize.h).lround.to!int
                ],
                [
                    (a.width.to!double/c.size.w*c.animSize.w).lround.to!int,
                    (a.height.to!double/c.size.h*c.animSize.h).lround.to!int
                ]
            );
        }
    }

    void draw(){
        frameTimer.tick;
        double statePerSecond = 1/0.25*config.animationSpeed;
        if(overview.doOverview)
            overview.state = (overview.state+frameTimer.dur*statePerSecond).min(1);
        else
            overview.state = (overview.state-frameTimer.dur*statePerSecond).max(0);
        OverviewState(overview.state);

        Animation.update;
        overview.tick;
        
        if(!config.redirect && !overview.visible)
            return;
    
        CompositeClient[] windowsDraw;

        with(Profile("calc draw")){

            with(Profile("animate")){
                foreach(c; clients){
                    if(c.destroyed){
                        restack = true;
                        continue;
                    }
                    if(c.a.override_redirect && !c.picture || (c.animation.fade.calculate <= 0.0001 && c.floating))
                        continue;
                    c.animation.rect.approach(c.pos, c.size);
                }
            }

            with(Profile("calc windows")){
                foreach(c; clients.chain(destroyed)){
                    with(Profile(c.title)){
                        if(c.a.override_redirect && !c.picture)
                            continue;
                        with(Profile("animate")){
                            animate(c);
                        }
                        if(c.animation.fade.calculate <= 0.0001 && c.floating)
                            continue;
                        if((!overview.visible && c.animation.fade.calculate <= 0.0001
    								|| !overview.visible
    									&& ![manager.properties.workspace.value, -1].canFind(c.properties.workspace.value)
    									&& !c.a.override_redirect
                                    || c.animPos.x+c.animSize.w <= 0
                                    || c.animPos.y+c.animSize.h <= 0
                                    || c.animPos.x >= width
                                    || c.animPos.y >= height))
                            continue;
                        with(Profile("damage")){
                            applyDamage(c);
                            windowsDraw ~= c;
                        }
                    }
                }
            }

            if(overview.visible){
                with(Profile("calc draw overview damage")){
                    overview.damage(damage);
                }
            }

            with(Profile("calc draw damage")){
                backend.damage(damage);
            }

            backend.render(root_picture, false, 1, [0, 0], [0, 0], [width, height]);
            if(overview.visible){
                backend.setColor([0,0,0,0.7*overview.state.sinApproach]);
                backend.rect([0,0], [width, height]);
            }

        }

        if(overview.visible){
            with(Profile("overview draw")){
                overview.draw(backend, windowsDraw);
            }
        }else{
            with(Profile("draw")){
                foreach(c; windowsDraw){
                    .draw(backend, c);
                }
            }    
        }
        
        with(Profile("profile draw")){
            Profile.display(backend);
        }

        with(Profile("XSync")){
            XSync(wm.displayHandle, false);
        }
        backend.swap;
    }

}


void draw(Backend backend, CompositeClient c){

    if(!c.damage.damaged)
        return;

    with(Profile(c.title)){

        double transition = 1;

        if(c.ghost && c.animation.rect.size != c.size){
            auto distanceVector = c.size.a - c.ghost.size;
            auto transitionVec = [c.animation.rect.size.w.lround.to!int,
                                  c.animation.rect.size.h.lround.to!int].a
                                 - c.ghost.size;

            double length(Point vec){
                return asqrt(vec[].map!"a^^2.0".sum);
            }

            if(length(distanceVector) > 0){
                transition = length(transitionVec) / length(distanceVector);
                transition = transition.sigmoid;
            }else{
                transition = 1;
            }
            if(transition < 1){
                auto w = c.animSize.w.to!double/c.ghost.size.w;
                auto h = c.animSize.h.to!double/c.ghost.size.h;
                c.ghost.scale([w, h]);
                backend.render(c.ghost, c.ghost.hasAlpha, c.ghost.hasAlpha ? (1-transition)*c.animAlpha : 1, c.animOffset.to!(int[2]), c.animPos, c.animSize);
            }
        }

        if(c.picture){
            if(!c.stale){
                auto w = c.animSize.w/c.size.w.to!double;
                auto h = c.animSize.h/c.size.h.to!double;
                c.picture.scale([w, h]);
                backend.render(c.picture, c.picture.hasAlpha, c.animAlpha*transition, c.animOffset.to!(int[2]), c.animPos, c.animSize);
            }else{
                if(c.ghost){
                    auto w = c.animSize.w.to!double/c.ghost.size.w;
                    auto h = c.animSize.h.to!double/c.ghost.size.h;
                    c.ghost.scale([w, h]);
                    backend.render(c.ghost, c.ghost.hasAlpha, c.animAlpha*transition, c.animOffset.to!(int[2]), c.animPos, c.animSize);
                }else{
                    backend.setColor([0,0,0,c.animAlpha*transition]);
                    backend.rect([c.animPos.x, manager.height - c.animSize.h - c.animPos.y], c.animSize);
                }
            }
        }
        //drawShadow(c.animPos, c.animSize);
    }
}
