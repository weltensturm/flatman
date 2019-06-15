module flatman.client;

import flatman;

import common.xevents;


__gshared:


enum BUTTONMASK = ButtonPressMask|ButtonReleaseMask;
enum MOUSEMASK = BUTTONMASK|PointerMotionMask;


Atom[] unknown;



string getTitle(Window window){
    Atom actType;
    size_t nItems, bytes;
    int actFormat;
    ubyte* data;
    XGetWindowProperty(
            dpy, window, Atoms._NET_WM_NAME, 0, 0x77777777, False, Atoms.UTF8_STRING,
            &actType, &actFormat, &nItems, &bytes, &data
    );
    auto text = to!string(cast(char*)data);
    XFree(data);
    if(!text.length){
        if(!gettextprop(window, Atoms._NET_WM_NAME, text))
            gettextprop(window, XA_WM_NAME, text);
    }
    return text;
}


class Client: Base {

    Window win;
    Window orig;

    string name;
    float[2] aspectRange;
    int[2] posFloating;
    int[2] sizeFloating;
    int basew, baseh, incw, inch;
    int[2] sizeMin;
    int[2] sizeMax;
    int bw, oldbw;
    bool isUrgent;
    bool isFloating;
    bool decorations;
    bool global;
    bool isfixed, neverfocus, isfullscreen;
    bool sentDelete;
    Frame frame;
    bool strut;
    bool destroyed;
    bool iconified;
    bool isDock;

    Atom[] wmProtocols;

    ubyte[] icon;
    Icon xicon;
    long[2] iconSize;

    this(Window client){
        hidden = false;

        XWindowAttributes attr;
        XGetWindowAttributes(dpy, client, &attr);
        pos = [attr.x, attr.y];
        size = [attr.width, attr.height];
        posFloating = pos;
        sizeFloating = size;

        orig = client;
        win = client;

        Window trans = None;
        if(XGetTransientForHint(dpy, orig, &trans) && find(trans)){
        }else
            applyRules;

        updateSizeHints;
        updateFloating;
        updateType;
        updateWmHints;
        updateWmProtocols;
        updateIcon;
        updateTitle;
        updateDecorated;

        Events[orig] ~= this;
    }

    override string toString(){
        return Log.GREY ~ "%s:%s".format(win, name) ~ Log.DEFAULT;
    }

    void applyRules(){
        string _class, instance;
        uint i;
        const(Rule)* r;
        XClassHint ch = { null, null };
        /* rule matching */
        XGetClassHint(dpy, orig, &ch);
        _class = to!string(ch.res_class ? ch.res_class : "broken");
        instance = to!string(ch.res_name  ? ch.res_name  : "broken");
        for(i = 0; i < rules.length; i++){
            r = &rules[i];
            if(
                (!r.title.length || name.canFind(r.title))
                && (!r._class.length || _class.canFind(r._class))
                && (!r.instance.length || instance.canFind(r.instance)))
            {
                isFloating = r.isFloating;
                Monitor m;
                //for(m = monitors; m && m.num != r.monitor; m = m.next){}
                //if(m)
                //	monitor = m;
            }
        }
        if(ch.res_class)
            XFree(ch.res_class);
        if(ch.res_name)
            XFree(ch.res_name);
    }

    void clearUrgent(){
        XWMHints* wmh = XGetWMHints(dpy, orig);
        isUrgent = false;
        if(!wmh)
            return;
        wmh.flags &= ~XUrgencyHint;
        XSetWMHints(dpy, orig, wmh);
        XFree(wmh);
    }

    void onConfigureRequest(XConfigureRequestEvent* e){
        if(global || isFloating){
            if(e.value_mask & (CWX | CWY))
                //moveResize([e.x, e.y], [e.width, e.height]);
                move([e.x, e.y]);
            if(e.value_mask & (CWWidth | CWHeight))
                resize([e.width, e.height]);
        }else{
            XEvent event;
            event.xconfigure.type = ConfigureNotify;
            event.xconfigure.serial = LastKnownRequestProcessed(dpy);
            event.xconfigure.send_event = True;
            event.xconfigure.display = dpy;
            event.xconfigure.event = e.window;
            event.xconfigure.window = e.window;
            event.xconfigure.x = pos.x;
            event.xconfigure.y = pos.y;
            event.xconfigure.width = size.w;
            event.xconfigure.height = size.h;
            event.xconfigure.above = None;
            event.xconfigure.override_redirect = False;
            XSendEvent(dpy, e.window, False, 0, &event);
        }
    }

    void configure(){
        "%s configure %s %s".format(this, pos, size).log;
        auto hide = (parent && parent.hidden ? rootSize.h : 0).to!int;
        XMoveResizeWindow(dpy, win, pos.x, pos.y+hide, size.w, size.h);
        if(frame){
            frame.moveResize(pos.a-[0,config.tabs.title.height-hide], [size.w, config.tabs.title.height]);
        }
    }

    @WindowConfigure
    void onConfigure(XConfigureEvent* e){
        if(isFloating || global){
            auto current = findMonitor(this);
            auto target = findMonitor([e.x, e.y - (parent && parent.hidden ? rootSize.h : 0)], [e.width, e.height]);
            if(current != target){
                current.remove(this);
                target.add(this, current.workspaceActive);
            }
        }
        if(strut)
            .updateStrut = true;
    }

    override void move(int[2] pos){
        if(this.pos == pos)
            return;
        "%s move %s".format(this, pos).log;
        if(isFloating && !isfullscreen)
            posFloating = pos;
        this.pos = pos;
        auto hide = (parent && parent.hidden ? rootSize.h : 0).to!int;
        XMoveWindow(dpy, win, pos.x, pos.y + hide);
        if(frame){
            frame.moveResize(pos.a-[0,config.tabs.title.height+hide], [size.w,config.tabs.title.height]);
        }
    }

    override void resize(int[2] size){
        if(this.size == size)
            return;
        if(isFloating && !isfullscreen)
            sizeFloating = size;
        size.w = size.w.max(1).max(sizeMin.w).min(sizeMax.w);
        size.h = size.h.max(1).max(sizeMin.h).min(sizeMax.h);
        "%s resize %s".format(this, size).log;
        this.size = size;
        XResizeWindow(dpy, win, size.w, size.h);
        if(frame){
            frame.moveResize(pos.a-[0, config.tabs.title.height], [size.w, config.tabs.title.height]);
        }
    }

    void moveResize(int[2] pos, int[2] size, bool force = false){
        move(pos);
        resize(size);
        if(force)
            configure;
    }

    Atom[] getPropList(Atom prop){
        int di;
        ulong dl;
        ubyte* p;
        Atom da;
        Atom[] atom;
        ulong count;
        if(XGetWindowProperty(dpy, orig, prop, 0L, -1, false, XA_ATOM,
                              &da, &di, &count, &dl, &p) == Success && p){
            atom = (cast(Atom*)p)[0..count].dup;
            XFree(p);
        }
        return atom;
    }

    Atom getatomprop(Atom prop){
        int di;
        ulong dl;
        ubyte* p;
        Atom da, atom = None;
        if(XGetWindowProperty(dpy, orig, prop, 0L, atom.sizeof, false, XA_ATOM,
                              &da, &di, &dl, &dl, &p) == Success && p){
            atom = *cast(Atom*)p;
            XFree(p);
        }
        return atom;
    }

    long[4] getStrut(){
        int actualFormat;
        ulong bytes, items, count;
        ubyte* data;
        Atom actualType, atom;
        if(XGetWindowProperty(dpy, orig, Atoms._NET_WM_STRUT_PARTIAL, 0, 12, false, XA_CARDINAL, &actualType,
                              &actualFormat, &count, &bytes, &data) == Success && data){
            assert(actualType == XA_CARDINAL);
            assert(actualFormat == 32);
            assert(count == 12);
            auto array = (cast(CARDINAL*)data)[0..12];
            XFree(data);
            "found strut %s %s".format(name, array);
            if(array.any!"a < 0")
                return [0,0,0,0];
            return array[0..4];
        }
        return [0,0,0,0];

    }

    string getTitle(){
        return orig.getTitle;
    }

    @WindowFocusOut
    void buttonsGrab(){
        if(isDock)
            return;
        foreach(button; [1, 2, 3]){
            XGrabButton(
                dpy,
                button,
                AnyModifier,
                orig,
                true,
                ButtonPressMask,
                GrabModeAsync,
                GrabModeAsync,
                .root,
                None
            );
        }
    }

    @WindowFocusIn
    void buttonsUngrab(){
        if(isDock)
            return;
        foreach(button; [1, 2, 3]){
            XUngrabButton(
                dpy,
                button,
                AnyModifier,
                orig
            );
        }
    }

    void hideSoft(){
        XMoveWindow(dpy, win, pos.x, rootSize.h+pos.y);
        if(frame)
            XMoveWindow(dpy, frame.window, frame.pos.x, rootSize.h+frame.pos.y);
    }

    auto monitor(){
        return findMonitor(this);
    }

    override void show(){
        "%s show".format(this).log;
        setState(NormalState);
        hidden = false;
        iconified = false;
        XMapWindow(dpy, win);
    }

    override void hide(){
        "%s hide".format(this).log;
        setState(IconicState);
        iconified = true;
        hidden = true;
        XUnmapWindow(dpy, win);
    }

    @WindowUnmap
    void onUnmap(){
        if(frame)
            frame.hide;
    }

    @WindowMap
    void shown(){
        if(frame)
            frame.show;
    }

    auto isVisible(){
        return (monitor.workspace.clients.canFind(this) || globals.canFind(this));
    }

    int originWorkspace(){
        string env;
        /+
        try {
            env = "/proc/%d/environ".format(orig.getprop!CARDINAL(Atoms._NET_WM_PID)).readText;
            auto match = matchFirst(env, r"FLATMAN_WORKSPACE=([0-9]+)");
            "%s origin=%s".format(this, match).log;
            return match[1].to!int;
        }catch(Exception e)
            try
                "%s pid error: %s".format(this, orig.getprop!CARDINAL(Atoms._NET_WM_PID)).log;
            catch
                "%s pid error".format(this).log;
        +/
        try
            return cast(int)orig.getprop!CARDINAL(Atoms._NET_WM_DESKTOP);
        catch(Throwable){}
        return .monitor.workspaceActive;
    }

    void requestAttention(){
        if(this == this.monitor.active){
            isUrgent = false;
            return;
        }
        if(!isVisible && this != requestFocus){
            "%s requests attention".format(this).log;
            ["notify-send", "%s requests attention".format(name)].spawnProcess;

        }
        isUrgent = true;
    }

    bool sendEvent(Atom atom){
        bool exists = wmProtocols.canFind(atom);
        if(exists){
            XEvent ev;
            ev.type = ClientMessage;
            ev.xclient.window = orig;
            ev.xclient.message_type = Atoms.WM_PROTOCOLS;
            ev.xclient.format = 32;
            ev.xclient.data.l[0] = atom;
            ev.xclient.data.l[1] = CurrentTime;
            XSendEvent(dpy, orig, false, NoEventMask, &ev);
        }
        return exists;
    }

    void setFullscreen(bool fullscreen){
        "%s fullscreen=%s".format(this, fullscreen).log;
        isfullscreen = fullscreen;
        updateFullscreen;
        this.monitor.update(this);
        if(this == flatman.active)
            focus(this);
        restack;
    }

    void updateFullscreen(){
        auto proplist = getPropList(Atoms._NET_WM_STATE);
        if(isfullscreen){
            if(!proplist.canFind(Atoms._NET_WM_STATE_FULLSCREEN))
                append(win, Atoms._NET_WM_STATE, [Atoms._NET_WM_STATE_FULLSCREEN]);
        }else{
            if(proplist.canFind(Atoms._NET_WM_STATE_FULLSCREEN))
                replace(win, Atoms._NET_WM_STATE, proplist.without(Atoms._NET_WM_STATE_FULLSCREEN));
        }
    }

    void setState(long state){
        long[] data = [ state, None ];
        XChangeProperty(dpy, orig, Atoms.WM_STATE, Atoms.WM_STATE, 32, PropModeReplace, cast(ubyte*)data, 2);
    }

    void setWorkspace(long i){
        auto monitor = this.monitor;
        if(i >= 0 && i < monitor.workspaces.length && monitor.workspaces[i].clients.canFind(this))
            return;
        "%s set workspace %s".format(this, i).log;
        monitor.remove(this);
        monitor.add(this, i < 0 ? monitor.workspaces.length-1 : i);
        ewmh.updateWindowDesktop(this, i);
        "set workspace done".log;
    }

    void togglefloating(){
        if(isfullscreen)
            setFullscreen(false);
        else {
            isFloating = !isFloating;
            "%s floating=%s".format(this, isFloating).log;
            this.monitor.update(this);
        }
    }

    @WindowDestroy
    void onDestroy(){
        destroyed = true;
        Events.forget(this);
    }

    void updateStrut(){
        bool oldStrut = strut;
        strut = getStrut[0..4].any;
        .updateStrut = true;
        "%s strut=%s".format(this, strut);
    }


    void updateType(){
        Atom[] state = this.getPropList(Atoms._NET_WM_STATE);
        if(state.canFind(Atoms._NET_WM_STATE_FULLSCREEN)/+ || size == this.monitor.size +/)
            isfullscreen = true;
        if(state.canFind(Atoms._NET_WM_STATE_MODAL))
            isFloating = true;
        Atom[] type = getPropList(Atoms._NET_WM_WINDOW_TYPE);
        if(type.canFind(Atoms._NET_WM_WINDOW_TYPE_DIALOG) || type.canFind(Atoms._NET_WM_WINDOW_TYPE_SPLASH))
            isFloating = true;
        if(type.canFind(Atoms._NET_WM_WINDOW_TYPE_DOCK) || type.canFind(Atoms._NET_WM_WINDOW_TYPE_NOTIFICATION)){
            global = true;
            if(type.canFind(Atoms._NET_WM_WINDOW_TYPE_DOCK)){
                isDock = true;
            }
        }
    }

    void updateSizeHints(){
        long msize;
        XSizeHints size;
        if(!XGetWMNormalHints(dpy, orig, &size, &msize))
            /* size is uninitialized, ensure that size.flags aren't used */
            size.flags = PSize;
        if(size.flags & PBaseSize){
            basew = size.base_width;
            baseh = size.base_height;
        }else if(size.flags & PMinSize){
            basew = size.min_width;
            baseh = size.min_height;
        }else
            basew = baseh = 0;

        if(size.flags & PResizeInc){
            incw = size.width_inc;
            inch = size.height_inc;
        }else
            incw = inch = 0;
        if(size.flags & PMaxSize){
            sizeMax.w = size.max_width;
            sizeMax.h = size.max_height;
        }else
            sizeMax.w = sizeMax.h = int.max;

        if(size.flags & PMinSize){
            sizeMin.w = size.min_width;
            sizeMin.h = size.min_height;
        }else if(size.flags & PBaseSize){
            sizeMin.w = size.base_width;
            sizeMin.h = size.base_height;
        }else
            sizeMin.w = sizeMin.h = 0;

        if(size.flags & PAspect){
            aspectRange = [
                cast(float)size.min_aspect.y / size.min_aspect.x,
                cast(float)size.max_aspect.x / size.max_aspect.y
            ];
        }else
            aspectRange = [0,0];

        if(sizeMin.w > int.max || sizeMin.w < 0)
            sizeMin.w = 0;
        if(sizeMin.h > int.max || sizeMin.h < 0)
            sizeMin.h = 0;

        if(sizeMax.w > int.max || sizeMax.w < 0)
            sizeMax.w = int.max;
        if(sizeMax.h > int.max || sizeMax.h < 0)
            sizeMax.h = int.max;

        isfixed = (sizeMax.w && sizeMin.w && sizeMax.h && sizeMin.h &&
                   sizeMax.w == sizeMin.w && sizeMax.h == sizeMin.h);
        "%s sizeMin=%s sizeMax=%s".format(this, sizeMin, sizeMax).log;
    }

    void updateWmHints(){
        XWMHints* wmh = XGetWMHints(dpy, orig);
        if(wmh){
            if(this == flatman.monitor.active && wmh.flags & XUrgencyHint){
                wmh.flags &= ~XUrgencyHint;
                XSetWMHints(dpy, orig, wmh);
            }else{
                if(wmh.flags & XUrgencyHint){
                    requestAttention;
                }
            }
            if(wmh.flags & InputHint)
                neverfocus = !wmh.input;
            else
                neverfocus = false;
            XFree(wmh);
        }
    }

    void updateWmProtocols(){
        int n;
        Atom* protocols;
        if(XGetWMProtocols(dpy, orig, &protocols, &n)){
            wmProtocols = protocols[0..n].dup;
            XFree(protocols);
        }
    }

    void updateIcon(){
        int format;
        ubyte* p = null;
        ulong count, extra;
        Atom type;
        if(XGetWindowProperty(dpy, orig, Atoms._NET_WM_ICON, 0, long.max, false, AnyPropertyType,
                              &type, &format, &count, &extra, cast(ubyte**)&p) != 0)
            return;
        if(xicon)
            destroy(xicon);
        if(p){
            long* data = cast(long*)p;
            long start = 0;
            long width = data[0];
            long height = data[1];
            for(int i=0; i<count;){
                if(data[i]*data[i+1] > width*height){
                    start = i;
                    width = data[i];
                    height = data[i+1];
                }
                i += data[i]*data[i+1]+2;
            }
            icon = [];
            foreach(argb; data[start+2..start+width*height+2]){
                auto alpha = (argb >> 24 & 0xff)/255.0;
                icon ~= [
                    cast(ubyte)((argb & 0xff)*alpha),
                    cast(ubyte)((argb >> 8 & 0xff)*alpha),
                    cast(ubyte)((argb >> 16 & 0xff)*alpha),
                    cast(ubyte)((argb >> 24 & 0xff))
                ];
            }
            iconSize = [width,height];
        }
        XFree(p);
    }

    void updateTitle(){
        name = getTitle;
    }

    void updateDecorated(){
        decorations = win.getIsDecorated;
    }

    void updateFloating(){
        Window trans;
        if(!isFloating){
            XGetTransientForHint(dpy, orig, &trans);
            isFloating = (find(trans) !is null) || isfixed;
        }
    }

    void updateState(){
        auto state = win.getstate;
        /+
        if(state == IconicState)
            hide;
        +/
    }

    @WindowProperty
    void onProperty(XPropertyEvent* ev){
        auto handler = [
            XA_WM_TRANSIENT_FOR:            &updateFloating,
            XA_WM_NORMAL_HINTS:             &updateSizeHints,
            XA_WM_HINTS:                    &updateWmHints,
            XA_WM_NAME:                     &updateTitle,
            Atoms.WM_STATE:                 &updateState,
            Atoms.WM_PROTOCOLS:             &updateWmProtocols,
            Atoms._NET_WM_NAME:             &updateTitle,
            Atoms._NET_WM_STATE:            &updateType,
            Atoms._NET_WM_WINDOW_TYPE:      &updateType,
            Atoms._NET_WM_STRUT_PARTIAL:    &updateStrut,
            Atoms._NET_WM_ICON:             &updateIcon,
            Atoms._MOTFI_WM_HINTS:          &updateDecorated
        ];
        auto change = ev.atom in handler;
        if(change)
            (*change)();
        else if(!unknown.canFind(ev.atom)){
            "unknown property %s".format(ev.atom.name).log;
            unknown ~= ev.atom;
        }
    }

}
