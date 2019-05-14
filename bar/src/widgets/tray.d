module bar.widget.tray;


import bar;

import common.xevents;


enum SYSTEM_TRAY_REQUEST_DOCK =    0;
enum SYSTEM_TRAY_BEGIN_MESSAGE =   1;
enum SYSTEM_TRAY_CANCEL_MESSAGE =  2;

enum _NET_SYSTEM_TRAY_ORIENTATION_HORZ = 0;
enum _NET_SYSTEM_TRAY_ORIENTATION_VERT = 1;


class Tray: Widget {

    Bar bar;
    bool enabled;

    TrayClient[] clients;
    int[2] iconSize;

    bool updateQueued;

    override int width(){
        return (iconSize.w)*clients.length.to!int;
    }

    int damageEvent;
    int damageError;

    this(Bar bar){
        this.bar = bar;
    }

    void enable(){
        if(enabled)
            return;
        enabled = true;
        X.CompositeRedirectSubwindows(wm.displayHandle, bar.windowHandle, CompositeRedirectManual);
        iconSize = [24, 24];
        bar.windowHandle.setSelection(Atoms._NET_SYSTEM_TRAY_S0);
        bar.windowHandle.set(Atoms._NET_SYSTEM_TRAY_ORIENTATION, XA_CARDINAL, 32, [_NET_SYSTEM_TRAY_ORIENTATION_HORZ]);
        bar.windowHandle.set(Atoms._NET_SYSTEM_TRAY_VISUAL, XA_VISUALID, 32, [wm.graphicsInfo.visualid]);
        .root.send(Atoms.MANAGER, 32, [CurrentTime, Atoms._NET_SYSTEM_TRAY_S0, bar.windowHandle]);
        XDamageQueryExtension(wm.displayHandle, &damageEvent, &damageError);
        wm.on([
            damageEvent + XDamageNotify: (XEvent* e){
                auto ev = cast(XDamageNotifyEvent*)e;
                foreach(c; clients){
                    if(c.window == e.xany.window){
                        bar.update = true;
                    }
                    repair(ev);
                }
            }
        ]);
        Events ~= this;
    }

    void disable(){
        if(!enabled)
            return;
        Events.forget(this);
        enabled = false;
        X.CompositeUnredirectSubwindows(wm.displayHandle, bar.windowHandle, CompositeRedirectManual);
        X.SetSelectionOwner(wm.displayHandle, Atoms._NET_SYSTEM_TRAY_S0, None, CurrentTime);
        foreach(client; clients){
            writeln("removing ", client);
            Xembed.unembed(client.window);
            X.UnmapWindow(dpy, client.window);
        }
    }

    @WindowClientMessage
    void clientMessage(WindowHandle, XClientMessageEvent* e){
        if (e.message_type == Atoms._NET_SYSTEM_TRAY_OPCODE){
            switch (e.data.l[1]){
                case SYSTEM_TRAY_REQUEST_DOCK:
                    if (e.window == bar.windowHandle){
                        dock(e.data.l[2]);
                    }
                    break;
                default:
                    writeln("unknown systray message ", e.data);
            }
        }else if(e.message_type == Atoms._XEMBED){
            switch(e.data.l[1]){
                case XEMBED_REQUEST_FOCUS:
                    Xembed.focus_in(e.window, XEMBED_FOCUS_CURRENT);
                    break;
                default:
                    writeln("unknown xembed message ", e.data);
            }
        }
    }

    @WindowDestroy
    void onDestroy(WindowHandle window){
        auto client = clients.filter!(a => a.window == window).array;
        if(client.length){
            writeln("destroyed dock entry");
            undock(client[0]);
        }
    }

    @WindowReparent
    void onReparent(WindowHandle window, WindowHandle target){
        if(target != bar.windowHandle){
            auto client = clients.filter!(a => a.window == window).array;
            if(client.length){
                writeln("unparented dock entry");
                undock(client[0]);
            }
        }
    }

    override void resize(int[2] size){
        if(size == this.size)
            return;
        super.resize(size);
        iconSize = [size.h-2, size.h-2];
        updateQueued = true;
    }

    override void move(int[2] pos){
        if(pos == this.pos)
            return;
        super.move(pos);
        updateQueued = true;
    }

    override void destroy(){
        disable;
    }

    void dock(x11.X.Window window){
        writeln("dock ", window);
        if(clients.canFind!(c => c.window == window)){
            writeln("WARNING: already docked");
            return;
        }

        auto client = new TrayClient(window);

        X.SelectInput(wm.displayHandle, window, StructureNotifyMask | PropertyChangeMask | EnterWindowMask);
        
        XSetWindowBackgroundPixmap(wm.displayHandle, window, None);

        Xembed.embed(window, bar.windowHandle);
        auto info = Xembed.get_info(window);
        if(info.flags & XEMBED_MAPPED)
            X.MapWindow(wm.displayHandle, window);
        X.AddToSaveSet(wm.displayHandle, window);
        clients ~= client;
        updateQueued = true;
    }

    void undock(TrayClient client){
        writeln("undock ", client.window);
        client.remove;
        clients = clients.without(client);
    }

    void update(){
        "update %s".format(clients).writeln;
        int offset = pos.x;
        foreach(client; clients){
            X.MoveResizeWindow(wm.displayHandle, client.window, offset+3, +3, iconSize.w-4, iconSize.h-4);
            offset += iconSize.w;
        }
    }

    override void onDraw(){
        foreach(c; clients){
            c.drawTo(bar.draw.to!XDraw.picture);
        }
    }

    override void tick(){
        if(updateQueued){
            update;
            updateQueued = false;
        }
    }

}



class TrayClient: Base {

    Damage damage;
    x11.X.Window window;
    Managed!Pixmap pixmap;
    Managed!Picture picture;

    this(x11.X.Window window){
        this.window = window;
        XWindowAttributes wa;
        X.GetWindowAttributes(wm.displayHandle, window, &wa);
        pos = [wa.x, wa.y];
        size = [wa.width, wa.height];
        damage = XDamageCreate(wm.displayHandle, window, XDamageReportNonEmpty);
        Events[window] ~= this;
    }

    void remove(){
        Events.forget(this);
        XDamageDestroy(wm.displayHandle, damage);
    }

    @WindowProperty
    void property(XPropertyEvent* e){
        if(e.atom == Atoms._XEMBED_INFO)
            Xembed.property_update(window);
    }

    @WindowConfigure
    void configure(XConfigureEvent* e){
        writeln("configured ", pos, size);
        pos = [e.x, e.y];
        size = [e.width, e.height];
        createPicture;
    }

    @WindowMap
    override void onShow(){
        writeln("shown");
        createPicture;
    }

    // when a client asks anything, say NO
    @WindowConfigureRequest
    void configureRequest(XConfigureRequestEvent* e){
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
        X.SendEvent(dpy, e.window, False, 0, &event);
    }

    void createPicture(){
        XWindowAttributes a;
        X.GetWindowAttributes(wm.displayHandle, window, &a);
        if(!(a.map_state & IsViewable))
            return;
        XRenderPictFormat* format = X.RenderFindVisualFormat(wm.displayHandle, a.visual);
        //hasAlpha = (format.type == PictTypeDirect && format.direct.alphaMask);
        XRenderPictureAttributes pa;
        pa.subwindow_mode = IncludeInferiors;
        pixmap = new Managed!Pixmap(X.CompositeNameWindowPixmap(wm.displayHandle, window),
                                    (Pixmap a){ X.FreePixmap(wm.displayHandle, a); });
        picture = new Managed!Picture(X.RenderCreatePicture(wm.displayHandle, pixmap, format, CPSubwindowMode, &pa),
                                      (Picture a){ X.RenderFreePicture(wm.displayHandle, a); });
        //XRenderColor color = { 0, 0, 0, 0 };
        //X.RenderFillRectangle(dpy, PictOpSrc, picture, &color, 0, 0, a.width, a.height);
        window.sendExpose;
        writeln("Created picture");
    }

    void drawTo(Picture target){
        if(!picture)
            return;
        X.RenderComposite(
            wm.displayHandle,
            PictOpOver,
            picture,
            None,
            target,
            0,
            0,
            0,
            0,
            pos.x,
            pos.y,
            size.w,
            size.h
        );
    }

}


class Managed(T){
    T object;
    private void delegate(T) deleter;
    alias object this;
    this(T object, void delegate(T) deleter){
        this.object = object;
        this.deleter = deleter;
    }
    ~this(){
        deleter(object);
    }
}


void repair(XDamageNotifyEvent* event){
    XDamageSubtract(wm.displayHandle, event.damage, None, None);
}


TrayClient find(TrayClient[] windows, x11.X.Window window){
    foreach(c; windows){
        if(c.window == window)
            return c;
    }
    return null;
}


void setSelection(x11.X.Window window, Atom atom){
    if(X.GetSelectionOwner(wm.displayHandle, atom) != None)
        throw new Exception("someone else already has selection");
    if(!X.SetSelectionOwner(wm.displayHandle, atom, window, CurrentTime))
        throw new Exception("could not get selection");
}


void set(WindowHandle window, Atom atom, int type, int format, long[] data){
    X.ChangeProperty(wm.displayHandle, window, atom, type, format, PropModeReplace, cast(ubyte*)data.ptr, cast(int)data.length);
}


void sendExpose(x11.X.Window window){
    XEvent xev;
    xev.type = Expose;
    xev.xexpose.window = window;
    X.SendEvent(wm.displayHandle, window, False, ExposureMask, &xev);

}

void send(x11.X.Window window, Atom message, int format, long[] data){
    XClientMessageEvent xev;
    xev.type = ClientMessage;
    xev.window = window;
    xev.message_type = message;
    xev.format = format;
    xev.data.l[0..data.length] = data[];
    X.SendEvent(wm.displayHandle, window, true, StructureNotifyMask, cast(XEvent*) &xev);

}
