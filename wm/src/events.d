module flatman.events;


import flatman;

import common.xevents;


alias Tick                   = Event!("Tick", void function());
alias Command				 = Event!("Command", void function(string, bool, string[]));
alias Overview				 = Event!("Overview", void function(bool));
alias WorkspaceCreate		 = Event!("WorkspaceCreate", void function(int));
alias WorkspaceDestroy		 = Event!("WorkspaceDestroy", void function(int));
alias WorkspaceSwitch        = Event!("WorkspaceSwitch", void function(int));


void handleEvents(){
    XEvent ev;
    XSync(dpy, false);
    while(XPending(dpy)){
        XNextEvent(dpy, &ev);
        eventSequence.update(ev.xany.serial);
        if(eventSequence.ignored(ev.type)){
            log(Log.RED ~ "ignoring " ~ Log.DEFAULT ~ formatEvent(&ev, root));
            continue;
        }
        with(Log(formatEvent(&ev, root))){
            handleEvent(&ev);
        }
    }
}


auto formatEvent(XEvent* ev, WindowHandle root){

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

    alias events = AliasSeq!(
        tuple(ButtonPress,       "ButtonPress",       "xbutton",           () => formatButton()),
        tuple(ButtonRelease,     "ButtonRelease",     "xbutton",           () => formatButton()),

        tuple(MotionNotify,      "MotionNotify",      "xmotion",           () => formatMotion()),

        tuple(ClientMessage,     "ClientMessage",     "xclient",           () => ev.xclient.to!string),
        tuple(ConfigureRequest,  "ConfigureRequest",  "xconfigurerequest", () => ev.xconfigurerequest.to!string),
        tuple(ConfigureNotify,   "ConfigureNotify",   "xconfigure",        () => ev.xconfigure.to!string),
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
        tuple(MapNotify,         "MapNotify",         "xmap",              () => "")
    );

    static foreach(event; events){
        if(event[0] == ev.type){
            auto msg = "";
            static if(event[2].length){
                auto win = __traits(getMember, ev, event[2]).window;
                auto client = find(win);
                if(client)
                    msg ~= "%s".format(client);
                else if(win == root)
                    msg ~= Log.RED ~ "%s:root".format(win) ~ Log.DEFAULT;
                else
                    msg ~= Log.GREY ~ "%s".format(win) ~ Log.DEFAULT;
            }
            return Log.GREY ~ Log.BOLD ~ ev.xany.serial.to!string ~ Log.DEFAULT ~ " " ~ msg ~ " " ~ event[1] ~ " " ~ event[3]();
        }
    }

    return "Event %s".format(ev.type);

}


class EventSequence {

    private ulong serial;
    private int[] ignoreEvents;

    void update(ulong serial){
        if(this.serial != serial){
            this.serial = serial;
            ignoreEvents = [];
        }
    }

    void ignore(int event){
        ignoreEvents ~= event;
    }

    bool ignored(int event){
        return ignoreEvents.canFind(event);
    }

}


void registerAll(){

    WindowMouseButton ~= &onButton;
    MouseMove ~= &onMotion;
    WindowClientMessage[AnyValue] ~= &onClientMessage;
    WindowConfigureRequest[AnyValue] ~= &onConfigureRequest;
	WindowConfigure ~= &onConfigure;
    WindowCreate ~= &onCreate;
    WindowDestroy ~= &onDestroy;
    WindowEnter ~= &onEnter;
    WindowMap ~= &onMap;
    WindowUnmap ~= &onUnmap;
    WindowMapRequest ~= &onMapRequest;
    WindowMap[AnyValue] ~= &restack;
    WindowFocusIn ~= &onFocus;
    WindowFocusOut ~= &onFocusOut;

}


void onButton(Window window, bool pressed, int mask, Mouse.button button){
    Client c = find(window);
    if(c){
        focus(c);
    }
    Monitor m = findMonitor(window);
    if(m && m != monitor){
        /+
        if(monitor && monitor.active)
            monitor.active.unfocus(true);
        +/
        monitor = m;
    }
}


void onClientMessage(XClientMessageEvent* cme){
    auto c = find(cme.window);
    auto handler = [
        Atoms._NET_CURRENT_DESKTOP: {
            if(cme.data.l[2] > 0)
                newWorkspace(cme.data.l[0]);
            switchWorkspace(cast(int)cme.data.l[0]);
        },
        Atoms._NET_WM_STATE: {
            if(!c)
                return;
            auto sh = [
                Atoms._NET_WM_STATE_FULLSCREEN: {
                    bool s = (cme.data.l[0] == _NET_WM_STATE_ADD
                      || (cme.data.l[0] == _NET_WM_STATE_TOGGLE && !c.isfullscreen));
                    c.setFullscreen(s);
                },
                Atoms._NET_WM_STATE_DEMANDS_ATTENTION: {
                    c.requestAttention;
                }
            ];
            if(cme.data.l[1] in sh)
                sh[cme.data.l[1]]();
            if(cme.data.l[2] in sh)
                sh[cme.data.l[2]]();
        },
        Atoms._NET_ACTIVE_WINDOW: {
            if(!c)
                return;
            if(cme.data.l[0] < 2 && (!active || cme.data.l[2] != active.win)){
                c.requestAttention;
            }else
                focus(c);
        },
        Atoms._NET_WM_DESKTOP: {
            if(!c)
                return;
            if(cme.data.l[2] == 1)
                newWorkspace(cme.data.l[0]);
            c.setWorkspace(cme.data.l[0]);
        },
        Atoms._NET_MOVERESIZE_WINDOW: {
            if(!c || !c.isFloating)
                return;
            c.moveResize(cme.data.l[0..2].to!(int[2]), cme.data.l[2..4].to!(int[2]));
        },
        Atoms._NET_RESTACK_WINDOW: {
            if(!c || c == monitor.active)
                return;
            c.requestAttention;
        },
        Atoms._NET_WM_MOVERESIZE: {
            if(!c)
                return;
            if(cme.data.l[2] == 8)
                drag.window(cme.data.l[3].to!int, c, c.pos.a - cme.data.l[0..2].to!(int[2]));
        },
        wm.state: {
            if(cme.data.l[0] == IconicState){
                "iconify %s".format(c).log;
            }
        },
        Atoms._FLATMAN_OVERVIEW: {
            if(cme.data.l[0] != 2)
                return;
            overview(cme.data.l[1] > 0);
        },
        Atoms._FLATMAN_TELEPORT: {
            if(cme.data.l[0] != 2 || !c)
                return;
            auto target = find(cme.data.l[0]);
            if(target)
                teleport(c, target, cme.data.l[1]);
        }
    ];
    if(cme.message_type in handler)
        handler[cme.message_type]();
    else
        "unknown message type %s %s".format(cme.message_type, cme.message_type.name).log;
}

void onConfigure(Window window, XConfigureEvent* ev){
    eventSequence.ignore(EnterNotify);
    if(window == root){
        bool dirty = rootSize != [ev.width, ev.height];
        rootSize = [ev.width, ev.height];
        if(moveResizeMonitors() || dirty){
            ewmh.updateWorkarea;
            restack;
        }
    }
}

void onConfigureRequest(XConfigureRequestEvent* ev){
    Client c = find(ev.window);
    if(c){
        c.onConfigureRequest(ev);
    }else{
        XWindowChanges wc;
        wc.x = ev.x;
        wc.y = ev.y;
        wc.width = ev.width;
        wc.height = ev.height;
        wc.border_width = ev.border_width;
        wc.sibling = ev.above;
        wc.stack_mode = ev.detail;
        XConfigureWindow(dpy, ev.window, ev.value_mask, &wc);
    }
}

void onCreate(bool override_redirect, Window window){
    if(override_redirect){
        x11.X.Window[] wmWindows;
        foreach(ws; monitor.workspaces){
            foreach(separator; ws.split.separators)
                wmWindows ~= separator.window;
        }
        "unmanaged window".log;
        if(!(unmanaged ~ wmWindows).canFind(window))
            unmanaged ~= window;
    }
}

void onDestroy(Window window){
    if(unmanaged.canFind(window))
        unmanaged = unmanaged.without(window);

    if(auto client = find(window)){
        bool wasActive = client == active;
        client.monitor.remove(client);
        ewmh.updateClientList;
        if(wasActive){

            auto newFocus = monitor.active;

            if(!newFocus){
                auto result =
                    monitors
                        .map!(a => a.active)
                        .filter!(a => a !is null)
                        .takeOne;
                if(result.length)
                    newFocus = result[0];
            }

            if(newFocus)
                newFocus.focus;

        }
    }
}

void onUnmap(Window window){
    eventSequence.ignore(EnterNotify);
}


void onEnter(Window window){
    if(drag.dragging)
        return;
    Client c = find(window);
    if(c && !c.isDock){
        focus(c);
    }
}


void onFocus(x11.X.Window window){
    //if(currentFocus && ev.window == currentFocus.orig)
    //	focus(currentFocus);
    //auto c = find(ev.window);
    //if(c && c != active)
    //	c.requestAttention;
}


void onFocusOut(x11.X.Window window){
    if(!find(window) && monitor.active){
        // TODO: this does nothing
        currentFocus = null;
        focus(monitor.active);
    }
}


void onMapRequest(Window parent, Window window){
    XWindowAttributes wa;
    if(!XGetWindowAttributes(dpy, window, &wa)){
        return;
    }
    if(wa.override_redirect){
        //XMapWindow(dpy, window);
        "%s ignoring unmanaged window".format(window).log;
        return;
    }
    if(auto c = find(window)){
        c.show;
        c.focus;
        return;
    }
    if(parent != root){
        "%s parent is not root?!".format(window).log;
        return;
    }
    manage(window, &wa, true);
}


void onMap(Window window){
    eventSequence.ignore(EnterNotify);
    /+
    if(!find(window)){
        XWindowAttributes wa;
        if(!XGetWindowAttributes(dpy, window, &wa)){
            return;
        }
        if(wa.override_redirect){
            "%s ignoring unmanaged window".format(window).log;
            return;
        }
        manage(window, &wa, false);
    }
    +/
}


void onMotion(int[2] pos){
    /+
    if(ev.window != root && (!active || ev.window != active.win && ev.subwindow != active.win)){
        auto c = find(ev.window);
        if(c)
            focus(c);
    }
    +/
    focus(findMonitor(pos));
}
