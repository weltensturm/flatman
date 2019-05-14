module common.xevents;


import
    std.conv,
    std.string,
    std.meta,
    std.typecons,
    x11.X,
    x11.Xlib,
    ws.gui.input,
    ws.wm,
    common.event;


alias WindowMouseButton      = Event!("WindowMouseButton", void function(WindowHandle, bool, Mouse.button),
                                                           void function(WindowHandle, bool, int, Mouse.button));
alias WindowKey              = Event!("WindowKey", void function(WindowHandle, bool, Keyboard.key),
                                                   void function(WindowHandle, bool, int, Keyboard.key));
alias MouseMove              = Event!("MouseMove", void function(int[2]));
alias WindowMouseMove        = Event!("WindowMouseMove", void function(WindowHandle, int[2]));
alias WindowClientMessage    = Event!("WindowClientMessage", void function(WindowHandle, XClientMessageEvent*));
alias WindowConfigureRequest = Event!("WindowConfigureRequest", void function(WindowHandle, XConfigureRequestEvent*));
alias WindowConfigure        = Event!("WindowConfigure", void function(WindowHandle, XConfigureEvent*));
alias WindowResize           = Event!("WindowResize", void function(WindowHandle, int[2]));
alias WindowMove             = Event!("WindowMove", void function(WindowHandle, int[2]));
alias WindowCreate           = Event!("WindowCreate", void function(bool, WindowHandle));
alias WindowDestroy          = Event!("WindowDestroy", void function(WindowHandle));
alias WindowReparent        = Event!("WindowReparent", void function(WindowHandle, WindowHandle));
alias WindowEnter            = Event!("WindowEnter", void function(WindowHandle),
                                                     void function(WindowHandle, int[2]));
alias WindowLeave            = Event!("WindowLeave", void function(WindowHandle));
alias WindowExpose           = Event!("WindowExpose", void function(WindowHandle));
alias WindowFocusIn          = Event!("WindowFocusIn", void function(WindowHandle));
alias WindowFocusOut         = Event!("WindowFocusOut", void function(WindowHandle));
alias WindowMapRequest       = Event!("WindowMapRequest", void function(WindowHandle, WindowHandle));
alias WindowProperty         = Event!("WindowProperty", void function(WindowHandle, XPropertyEvent*));
alias WindowMap              = Event!("WindowMap", void function(WindowHandle));
alias WindowUnmap            = Event!("WindowUnmap", void function(WindowHandle));
alias KeyboardMapping        = Event!("KeyboardMapping", void function(XMappingEvent*));


void handleEvent(XEvent* e){
    switch(e.type){
        case ButtonPress:
            WindowMouseButton(e.xbutton.window, true, e.xbutton.button);
            WindowMouseButton(e.xbutton.window, true, e.xbutton.state, e.xbutton.button);
            break;
        case ButtonRelease:
            WindowMouseButton(e.xbutton.window, false, e.xbutton.button);
            WindowMouseButton(e.xbutton.window, false, e.xbutton.state, e.xbutton.button);
            break;

        case MotionNotify:
            WindowMouseMove(e.xmotion.window, [e.xmotion.x, e.xmotion.y].to!(int[2]));
            MouseMove([e.xmotion.x_root, e.xmotion.y_root].to!(int[2]));
            break;

        case ClientMessage:
            WindowClientMessage(e.xclient.window, &e.xclient);
            break;

        case ConfigureRequest:
            WindowConfigureRequest(e.xconfigurerequest.window, &e.xconfigurerequest);
            break;
        case ConfigureNotify:
            WindowConfigure(e.xconfigure.window, &e.xconfigure);
            WindowResize(e.xconfigure.window, [e.xconfigure.width, e.xconfigure.height]);
            WindowMove(e.xconfigure.window, [e.xconfigure.x, e.xconfigure.y]);
            break;

        case CreateNotify:
            WindowCreate(e.xcreatewindow.override_redirect > 0, e.xcreatewindow.window);
            break;
        case DestroyNotify:
            WindowDestroy(e.xdestroywindow.window);
            break;

        case ReparentNotify:
            WindowReparent(e.xreparent.window, e.xreparent.parent);
            break;

        case EnterNotify:
            WindowEnter(e.xcrossing.window);
            WindowEnter(e.xcrossing.window, [e.xcrossing.x_root, e.xcrossing.y_root]);
            break;
        case LeaveNotify:
            WindowLeave(e.xcrossing.window);
            break;

        case Expose:
            WindowExpose(e.xexpose.window);
            break;

        case FocusIn:
            WindowFocusIn(e.xfocus.window);
            break;

        case FocusOut:
            WindowFocusOut(e.xfocus.window);
            break;

        case KeyPress:
            KeySym keysym = XKeycodeToKeysym(wm.displayHandle, cast(KeyCode)e.xkey.keycode, 0);
            WindowKey(e.xkey.window, true, e.xkey.state, keysym);
            WindowKey(e.xkey.window, true, keysym);
            break;
        case KeyRelease:
            KeySym keysym = XKeycodeToKeysym(wm.displayHandle, cast(KeyCode)e.xkey.keycode, 0);
            WindowKey(e.xkey.window, false, e.xkey.state, keysym);
            WindowKey(e.xkey.window, false, keysym);
            break;

        case MapRequest:
            WindowMapRequest(e.xmaprequest.parent, e.xmaprequest.window);
            break;

        case PropertyNotify:
            WindowProperty(e.xproperty.window, &e.xproperty);
            break;

        case MapNotify:
            WindowMap(e.xmap.window);
            break;
        case UnmapNotify:
            WindowUnmap(e.xmap.window);
            break;

        case MappingNotify:
            KeyboardMapping(&e.xmapping);
            break;

        default:
            break;
    }
}

