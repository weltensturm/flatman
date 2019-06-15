module composite.overview.window;

import composite;


class OverviewWindow: ws.wm.Window {

    Overview overview;
    CompositeClient target;
    bool active;

    struct Dragging {
        bool pressed;
        bool dragging;
        CompositeClient window;
        CompositeClient nospam;
        int[2] start;
    }

    Dragging dragging;

    Properties!(
        "active", "_NET_ACTIVE_WINDOW", XA_WINDOW, false
    ) properties;

    CompositeClient windowHit;
    
    this(Overview overview){
        this.overview = overview;
        super(manager.width, manager.height, "Overview Window", true);
        XSelectInput(wm.displayHandle, windowHandle, ButtonPressMask | ButtonReleaseMask | PointerMotionMask);
        wm.on(.root, [
            PropertyNotify: (XEvent* e) => properties.update(&e.xproperty)
        ]);
        properties.window(.root);
        properties.update;
        draw.setFont("Roboto", 10);
    }

    override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
        onMouseMove(x, y);
        writeln(button, ' ', pressed);
        if(pressed && button == Mouse.buttonLeft && windowHit){
            dragging.pressed = true;
            dragging.window = windowHit;
            dragging.start = [x,y];
            if(properties.active.value != windowHit.windowHandle)
                properties.active.request(windowHit.windowHandle, [2, CurrentTime, properties.active.value]);
        }else if(!pressed && button == Mouse.buttonLeft){
            if(!dragging.dragging && windowHit)
                overview.stop;
            dragging.dragging = false;
            dragging.window = null;
        }else if(pressed && button == Mouse.buttonMiddle){
            XEvent ev;
            ev.type = ClientMessage;
            ev.xclient.window = windowHit.windowHandle;
            ev.xclient.message_type = Atoms.WM_PROTOCOLS;
            ev.xclient.format = 32;
            ev.xclient.data.l[0] = Atoms.WM_DELETE_WINDOW;
            ev.xclient.data.l[1] = CurrentTime;
            XSendEvent(wm.displayHandle, windowHit.windowHandle, false, NoEventMask, &ev);
        }
        overview.onMouseButton(button, pressed, x, y);
        super.onMouseButton(button, pressed, x, y);
    }

    override void onMouseMove(int x, int y){
        windowHit = null;
        foreach(m; overview.monitors){
            if(![x,y].inside(m.pos, m.size, manager.height))
                continue;
            foreach(wsi, ws; m.workspaces){
                foreach(w; ws.windows){
                    auto tabs = w.window.properties.tabs.value.max(0);
                    if(tabs == 0 && (w.window.hidden || !w.window.picture))
                        continue;
                    with(w.animation){
                        if(![x,y].inside(pos.calculate.to!(int[2]), size.calculate.to!(int[2]), manager.height))
                            continue;
                    }
                    windowHit = w.window;
                }
            }
        }
        if(dragging.pressed && !dragging.dragging){
            if(((dragging.start.x-x).abs > 3 || (dragging.start.y-y).abs > 3) && dragging.window){
                dragging.dragging = true;
            }
        }
        if(dragging.dragging
                && dragging.window
                && windowHit
                && dragging.window.windowHandle != windowHit.windowHandle
                && (!dragging.nospam || dragging.nospam.windowHandle != windowHit.windowHandle)){
            dragging.nospam = windowHit;
            XEvent ev;
            ev.type = ClientMessage;
            ev.xclient.window = dragging.window.windowHandle;
            ev.xclient.message_type = Atoms._FLATMAN_TELEPORT;
            ev.xclient.format = 32;
            ev.xclient.data.l[0] = windowHit.windowHandle;
            ev.xclient.data.l[1] = 0;
            XSendEvent(wm.displayHandle, .root, false, NoEventMask, &ev);
            writeln("drag \"", dragging.window.title, "\" to \"", windowHit.title, "\"");
        }
        /+
        if(windowHit)
            properties.active.request(windowHit.windowHandle, [2, CurrentTime, properties.active.value]);
        +/
        overview.onMouseMove(x, y);
        super.onMouseMove(x, y);
    }

}

