module bar.widget.tray;


import bar;


enum SYSTEM_TRAY_REQUEST_DOCK =    0;
enum SYSTEM_TRAY_BEGIN_MESSAGE =   1;
enum SYSTEM_TRAY_CANCEL_MESSAGE =  2;

enum _NET_SYSTEM_TRAY_ORIENTATION_HORZ = 0;
enum _NET_SYSTEM_TRAY_ORIENTATION_VERT = 1;


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
            DestroyNotify: (XEvent* e) => evDestroy(e.xdestroywindow.window),
            //MapNotify: (XEvent* e) => update,
        ]);
        this.bar = bar;
        iconSize = [bar.size.h-2, bar.size.h-2];
        if(XGetSelectionOwner(wm.displayHandle, Atoms._NET_SYSTEM_TRAY_S0) != None)
            throw new Exception("another systray already running");
        if(XSetSelectionOwner(wm.displayHandle, Atoms._NET_SYSTEM_TRAY_S0, bar.windowHandle, CurrentTime)){
            auto data = _NET_SYSTEM_TRAY_ORIENTATION_HORZ;
            XChangeProperty(
                wm.displayHandle,
                bar.windowHandle,
                Atoms._NET_SYSTEM_TRAY_ORIENTATION,
                XA_CARDINAL, 32,
                PropModeReplace,
                cast(ubyte*)&data, 1);
            XClientMessageEvent xev;
            xev.type = ClientMessage;
            xev.window = .root;
            xev.message_type = Atoms.MANAGER;
            xev.format = 32;
            xev.data.l[0] = CurrentTime;
            xev.data.l[1] = Atoms._NET_SYSTEM_TRAY_S0;
            xev.data.l[2] = bar.windowHandle;
            xev.data.l[3] = 0;
            xev.data.l[4] = 0;
            XSendEvent(wm.displayHandle, .root, false, StructureNotifyMask, cast(XEvent*) &xev);
        }else{
            throw new Exception("tray: System tray didn't get the system tray manager selection\n");
        }
    }

    void evClientMessage(XClientMessageEvent* e){
        if (e.message_type == Atoms._NET_SYSTEM_TRAY_OPCODE){
            switch (e.data.l[1]){
                case SYSTEM_TRAY_REQUEST_DOCK:
                    if (e.window == bar.windowHandle){
                        dock(e.data.l[2]);
                    }
                    break;
                default: break;
            }
        }else if(e.message_type == Atoms._XEMBED){
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
            if(client.window == e.window && e.parent != bar.windowHandle){
                writeln("removing ", e.window);
                clients = clients.without(client);
                update;
            }
        }
    }

    void evDestroy(x11.X.Window window){
        foreach(client; clients){
            if(client.window == window){
                writeln("removing ", window);
                clients = clients.without(client);
                update;
            }
        }
    }

    override void resize(int[2] size){
        if(size == this.size)
            return;
        super.resize(size);
        update;
    }

    override void move(int[2] pos){
        if(pos == this.pos)
            return;
        super.move(pos);
        update;
    }

    void destroy(){
        foreach(client; clients)
            Xembed.unembed(client.window);
        XSetSelectionOwner(wm.displayHandle, selectionAtom, None, CurrentTime);
    }

    void dock(x11.X.Window window){
        writeln("dock ", window);
        if(clients.canFind!(c => c.window == window)){
            writeln("WARNING: already docked");
            return;
        }

        XColor color;
        color.red = (0xffff*config.theme.background[0]).to!ushort;
        color.green = (0xffff*config.theme.background[1]).to!ushort;
        color.blue = (0xffff*config.theme.background[2]).to!ushort;
        XAllocColor(wm.displayHandle, bar.windowAttributes.colormap, &color);
        XSetWindowBackground(wm.displayHandle, window, color.pixel);

        XSelectInput(wm.displayHandle, window, StructureNotifyMask | PropertyChangeMask | EnterWindowMask);
        auto info = Xembed.get_info(window);
        Xembed.embed(window, bar.windowHandle);
        XSync(dpy, false);
        if(info.flags == XEMBED_MAPPED)
            XMapWindow(wm.displayHandle, window);
        clients ~= new TrayClient(window);
        update;
    }

    void update(){
        XSync(wm.displayHandle, false);
        int offset = pos.x;
        foreach(client; clients){
            //XClearArea(wm.displayHandle, client.window, 0, 0, iconSize.w, iconSize.h, true);
            XMapWindow(wm.displayHandle, client.window);
            XMoveResizeWindow(wm.displayHandle, client.window, offset+1, +1, iconSize.w, iconSize.h);
            offset += iconSize.w+5;
            XSync(dpy, false);
        }
        foreach(cb; change)
            cb(clients.length.to!int);
    }

}
