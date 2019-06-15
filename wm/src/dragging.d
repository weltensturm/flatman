module flatman.dragging;

import
    std.math,
    std.string,
    std.algorithm,
    x11.X,
    x11.Xlib,
    ws.gui.base,

    common.event,
    common.log,
    common.xevents,

    flatman.util,
    flatman.flatman,
    flatman.client,
    flatman.manage,
    flatman.events;


class DragSystem {

    enum GRAB_MASK =
        ButtonPressMask | ButtonReleaseMask | PointerMotionMask
        | FocusChangeMask | EnterWindowMask | LeaveWindowMask;

    private {
        Mouse.button button;
        int[2] cursorPos;
        void delegate(int[2]) dragDg;
        void delegate() dropDg;
        bool mouseStale;
    }

    this(){
        Events ~= this;
    }

    void destroy(){
        Events.forget(this);
    }

    @Tick
    void update(){
        if(dragDg && !mouseStale){
            dragDg(cursorPos);
        }
    }

    @MouseMove
    void mouseMove(int[2] pos){
        cursorPos = pos;
        mouseStale = false;
    }

    @(WindowMouseButton[AnyValue])
    void mouseButton(bool pressed, Mouse.button button){
        if(!pressed && (!this.button || button == this.button))
            drop;
    }

    void window(Mouse.button button, Client client, int[2] offset){

        auto width = client.size.w;
        mouseStale = true;

        "start drag %s".format(client).log;

        int[2] lastCursorPos;

        drag(button, (int[2] pos){
            with(Log("drag")){
                if(!clients.canFind(client))
                    return;

                // TODO: add window to closest container

                auto x = pos.x;
                auto y = pos.y;

                bool allowSnap =
                        (lastCursorPos.x-x).abs < 10
                        && (lastCursorPos.y-y).abs < 10;

                flatman.Monitor target;
                if((target = findMonitor(pos)) != monitor && target){
                    monitor = target;
                }

                auto current = findMonitor(client);
                
                auto snapBorder = 20;

                auto xt = offset.x * client.size.w / width;

                bool toggle =
                        (y <= monitor.pos.y+snapBorder) == client.isFloating
                        && x > monitor.pos.x+snapBorder
                        && x < monitor.pos.x+monitor.size.w-snapBorder;

                if(toggle){
                    if(!client.isFloating)
                        client.posFloating = [x, y].a + [xt, offset.y];
                    client.togglefloating;
                    restack;
                }

                if(client.isFloating){
                    if(allowSnap && x <= monitor.pos.x+snapBorder && x >= monitor.pos.x){
                        if(client.isFloating){
                            current.remove(client);
                            client.isFloating = false;
                            monitor.workspace.split.add(client, -1);
                            monitor.update(client);
                            focus(client);
                            restack;
                        }
                        return;
                    }else if(allowSnap && x >= monitor.pos.x+monitor.size.w-snapBorder && x <= monitor.pos.x+monitor.size.w){
                        if(client.isFloating){
                            current.remove(client);
                            client.isFloating = false;
                            monitor.workspace.split.add(client, monitor.workspace.split.clients.length);
                            monitor.update(client);
                            focus(client);
                            restack;
                        }
                        return;
                    }
                    client.move([x, y].a + [xt, offset.y]);
                }

                lastCursorPos = pos;

            }
        });

    }


    void drag(Mouse.button button, void delegate(int[2]) dragDg, void delegate() dropDg=null){
        drop;
        this.dragDg = dragDg;
        this.dropDg = dropDg;
        this.button = button;
        XGrabPointer(dpy, root, true, GRAB_MASK, GrabModeAsync, GrabModeAsync, None, None, CurrentTime);
    }


    void drop(){
        XUngrabPointer(dpy, CurrentTime);
        if(dropDg){
            with(Log("drop")){
                dropDg();
            }
        }
        dragDg = null;
        dropDg = null;
    }

    bool dragging(){
        return dragDg != null;
    }

}
