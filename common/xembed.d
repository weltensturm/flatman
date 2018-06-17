module common.xembed;


import
    x11.X,
    x11.Xatom,
    x11.Xlib,
    ws.x.property,
    ws.wm,
    common.xerror;

enum XEMBED_VERSION =  0;

enum XEMBED_MAPPED =                  1;
enum XEMBED_INFO_FLAGS_ALL =          1;

enum XEMBED_EMBEDDED_NOTIFY =         0;
enum XEMBED_WINDOW_ACTIVATE =         1;
enum XEMBED_WINDOW_DEACTIVATE =       2;
enum XEMBED_REQUEST_FOCUS =           3;
enum XEMBED_FOCUS_IN =                4;
enum XEMBED_FOCUS_OUT =               5;
enum XEMBED_FOCUS_NEXT =              6;
enum XEMBED_FOCUS_PREV =              7;
enum XEMBED_MODALITY_ON =             10;
enum XEMBED_MODALITY_OFF =            11;
enum XEMBED_REGISTER_ACCELERATOR =    12;
enum XEMBED_UNREGISTER_ACCELERATOR =  13;
enum XEMBED_ACTIVATE_ACCELERATOR =    14;

enum XEMBED_FOCUS_CURRENT =           0;
enum XEMBED_FOCUS_FIRST =             1;
enum XEMBED_FOCUS_LAST =              2;

enum XEMBED_MODIFIER_SHIFT =   (1 << 0);
enum XEMBED_MODIFIER_CONTROL = (1 << 1);
enum XEMBED_MODIFIER_ALT =     (1 << 2);
enum XEMBED_MODIFIER_SUPER =   (1 << 3);
enum XEMBED_MODIFIER_HYPER =   (1 << 4);

enum XEMBED_ACCELERATOR_OVERLOADED =   (1 << 0);



struct XembedInfo {
    ulong version_;
    ulong flags;
}


struct XembedWindow {
    x11.X.Window window;
    XembedInfo info;
}


class Xembed {

    static void embedNotify(x11.X.Window client, x11.X.Window embedder, long version_){
        message_send(client, XEMBED_EMBEDDED_NOTIFY, 0, embedder, version_);
    }

    static void embed(x11.X.Window child, x11.X.Window parent){
        X.ReparentWindow(wm.displayHandle, child, parent, 0, 0);
        embedNotify(child, parent, XEMBED_VERSION);
    }

    static void unembed(x11.X.Window child){
        X.ReparentWindow(wm.displayHandle, child, DefaultRootWindow(wm.displayHandle), 0, 0);
    }

    static void focus_in(x11.X.Window client, long focus_type){
        message_send(client, XEMBED_FOCUS_IN, focus_type, 0, 0);
    }

    static void focus_out(x11.X.Window client){
        message_send(client, XEMBED_FOCUS_OUT, 0, 0, 0);
    }

    static void window_activate(x11.X.Window client){
        message_send(client, XEMBED_WINDOW_ACTIVATE, 0, 0, 0);
    }

    static void window_deactivate(x11.X.Window client){
        message_send(client, XEMBED_WINDOW_DEACTIVATE, 0, 0, 0);
    }

    static void message_send(x11.X.Window window, long message, long d1, long d2, long d3){
        XClientMessageEvent ev;
        ev.type = ClientMessage;
        ev.window = window;
        ev.format = 32;
        ev.data.l[0] = CurrentTime;
        ev.data.l[1] = message;
        ev.data.l[2] = d1;
        ev.data.l[3] = d2;
        ev.data.l[4] = d3;
        ev.message_type = X.InternAtom(wm.displayHandle, "_XEMBED", false);
        X.SendEvent(wm.displayHandle, window, false, None, cast(XEvent*)&ev);
    }

    static XembedInfo get_info(x11.X.Window win){
        auto list = new Property!(XA_CARDINAL, true)(win, "_XEMBED_INFO").get;
        if(list.length < 2)
            return XembedInfo(XEMBED_VERSION, XEMBED_MAPPED);
        return XembedInfo(list[0], list[1]);
    }

    static void property_update(x11.X.Window window){
        XembedInfo info = get_info(window);
        /+
        bool flagsChanged = 0 != (info.flags ^ window.info.flags);
        if(!flagsChanged)
            return;
        if(flagsChanged & XEMBED_MAPPED){
        +/
            if(info.flags & XEMBED_MAPPED){
                X.MapWindow(wm.displayHandle, window);
                window_activate(window);
            }else{
                X.UnmapWindow(wm.displayHandle, window);
                window_deactivate(window);
                focus_out(window);
            }
        //}
    }

}
