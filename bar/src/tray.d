module bar.tray;


import bar;


enum SYSTEM_TRAY_REQUEST_DOCK =    0;
enum SYSTEM_TRAY_BEGIN_MESSAGE =   1;
enum SYSTEM_TRAY_CANCEL_MESSAGE =  2;

enum _NET_SYSTEM_TRAY_ORIENTATION_HORZ = 0;
enum _NET_SYSTEM_TRAY_ORIENTATION_VERT = 1;


Atom systrayOpcode;


class TrayClient: Base {
    
    this(x11.X.Window window){
        this.window = window;
    }
    
    x11.X.Window window;

}


class Tray: Base {

    Bar bar;

    TrayClient[] clients;

    int[2] iconSize;

    Atom selectionAtom;
    Atom xembedInfo;

    void delegate(int)[] change;

    this(Bar bar){
        wm.on([
            ClientMessage: (XEvent* e) => evClientMessage(&e.xclient),
            ReparentNotify: (XEvent* e) => evReparent(&e.xreparent),
            PropertyNotify: (XEvent* e) => evProperty(&e.xproperty),
            DestroyNotify: (XEvent* e) => evDestroy(e.xdestroywindow.window)
        ]);
        this.bar = bar;
        iconSize = [bar.size.h, bar.size.h-1];
        selectionAtom = XInternAtom(wm.displayHandle, "_NET_SYSTEM_TRAY_S0", false);
        auto trayOrientation = XInternAtom(wm.displayHandle, "_NET_SYSTEM_TRAY_ORIENTATION", false);
        systrayOpcode =  XInternAtom(wm.displayHandle, "_NET_SYSTEM_TRAY_OPCODE", false);
        xembedInfo = XInternAtom(wm.displayHandle, "_XEMBED_INFO", false);
        if(XGetSelectionOwner(wm.displayHandle, selectionAtom) != None)
            throw new Exception("another systray already running");
        if(XSetSelectionOwner(wm.displayHandle, selectionAtom, bar.windowHandle, CurrentTime)){
            auto data = _NET_SYSTEM_TRAY_ORIENTATION_HORZ;
            XChangeProperty(
                wm.displayHandle,
                bar.windowHandle,
                trayOrientation,
                XA_CARDINAL, 32,
                PropModeReplace,
                cast(ubyte*)&data, 1);
            XClientMessageEvent xev;
            xev.type = ClientMessage;
            xev.window = .root;
            xev.message_type = XInternAtom(wm.displayHandle, "MANAGER", false);
            xev.format = 32;
            xev.data.l[0] = CurrentTime;
            xev.data.l[1] = selectionAtom;
            xev.data.l[2] = bar.windowHandle;
            xev.data.l[3] = 0;
            xev.data.l[4] = 0;
            XSendEvent(wm.displayHandle, .root, false, StructureNotifyMask, cast(XEvent*) &xev);
        }else{
            throw new Exception("tray: System tray didn't get the system tray manager selection\n");
        }
    }

    void evClientMessage(XClientMessageEvent* e){
        if (e.message_type == systrayOpcode){
            switch (e.data.l[1]){
                case SYSTEM_TRAY_REQUEST_DOCK:
                    if (e.window == bar.windowHandle){
                        dock(e.data.l[2]);
                    }
                    break;
                default: break;
            }
        }else if(e.message_type == XInternAtom(wm.displayHandle, "_XEMBED", false)){
            switch(e.data.l[1]){
                case XEMBED_REQUEST_FOCUS:
                    writeln("focus ", e.window);
                    Xembed.focus_in(e.window, XEMBED_FOCUS_CURRENT);
                    break;
                default: break;
            }
        }
    }

    void evProperty(XPropertyEvent* e){
        if(e.atom == xembedInfo){
            foreach(client; clients){
                if(client.window == e.window){
                    Xembed.property_update(client.window);
                    update;
                }
            }
        }
    }

    void evReparent(XReparentEvent* e){
        foreach(client; clients){
            if(client.window == e.window && e.parent == .root){
                writeln("removing ", e.window);
                clients = clients.without(client);
            }
        }
    }

    void evDestroy(x11.X.Window window){
        foreach(client; clients){
            if(client.window == window){
                writeln("removing ", window);
                clients = clients.without(client);
            }
        }
    }

    override void resize(int[2] size){
        super.resize(size);
        foreach(cb; change)
            cb(clients.length.to!int);
    }

    void destroy(){
        foreach(client; clients)
            Xembed.unembed(client.window);
        XSetSelectionOwner(wm.displayHandle, selectionAtom, None, CurrentTime);
    }

    void dock(x11.X.Window window){
        writeln("dock ", window);
        if(clients.canFind!(c => c.window == window))
            return;
        XSelectInput(wm.displayHandle, window, SubstructureNotifyMask | PropertyChangeMask | EnterWindowMask);
        Xembed.embed(window, bar.windowHandle);
        auto info = Xembed.get_info(window);
        if(info.flags == XEMBED_MAPPED)
            XMapWindow(wm.displayHandle, window);
        clients ~= new TrayClient(window);
        update;
    }

    void update(){
        XSync(wm.displayHandle, false);
        foreach(cb; change)
            cb(clients.length.to!int);
        int offset = pos.x;
        foreach(client; clients){
            XMoveResizeWindow(wm.displayHandle, client.window, offset, 0, iconSize.w, iconSize.h);
            XColor color;
            color.red = (0xffff*0.133333).to!ushort;
            color.green = (0xffff*0.133333).to!ushort;
            color.blue = (0xffff*0.133333).to!ushort;
            XAllocColor(wm.displayHandle, bar.windowAttributes.colormap, &color);
            XSetWindowBackground(wm.displayHandle, client.window, color.pixel);
            XClearArea(wm.displayHandle, client.window, 0, 0, 0, 0, true);
            offset += iconSize.w;
        }
    }

}


