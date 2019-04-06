module flatman.dragging;


import flatman;


class DragSystem {

    enum GRAB_MASK =
        ButtonPressMask | ButtonReleaseMask | PointerMotionMask
        | FocusChangeMask | EnterWindowMask | LeaveWindowMask;

    private {
        Mouse.button button;
        int[2] cursorPos;
        void delegate(int[2]) dragDg;
        void delegate() dropDg;
    }

    this(){
        Events ~= this;
    }

    void destroy(){
        Events.forget(this);
    }

    @Tick
    void update(){
        if(dragDg){
            dragDg(cursorPos);
        }
    }

    @MouseMove
    void mouseMove(int[2] pos){
        cursorPos = pos;
    }

    @(WindowMouseButton[AnyValue])
    void mouseButton(bool pressed, Mouse.button button){
        if(!pressed && (!this.button || button == this.button))
            drop;
    }

    void window(Mouse.button button, Client client, int[2] offset){

        auto width = client.size.w;

        "start drag %s".format(client).log;

        drag(button, (int[2] pos){
            with(Log("drag")){
                if(!clients.canFind(client))
                    return;

                auto x = pos.x;
                auto y = pos.y;

                flatman.Monitor target;
                if((target = findMonitor(pos)) != monitor && monitor){
                    /+
                    if(monitor && monitor.active)
                        monitor.active.unfocus(true);
                    monitor = target;
                    if(monitor.active)
                        monitor.active.focus;
                    +/
                    monitor = target;
                    //focus(null);
                }

                auto current = findMonitor(client);
                if(current != target){
                    current.remove(client);
                    target.add(client, target.workspaceActive);
                }

                auto snapBorder = 20;

                if((y <= monitor.pos.y+snapBorder) == client.isFloating
                        && x > monitor.pos.x+snapBorder
                        && x < monitor.pos.x+monitor.size.w-snapBorder)
                    client.togglefloating;

                if(client.isFloating){
                    if(x <= monitor.pos.x+snapBorder && x >= monitor.pos.x){
                        if(client.isFloating){
                            monitor.remove(client);
                            client.isFloating = false;
                            monitor.workspace.split.add(client, -1);
                        }
                        return;
                    }else if(x >= monitor.pos.x+monitor.size.w-snapBorder && x <= monitor.pos.x+monitor.size.w){
                        if(client.isFloating){
                            monitor.remove(client);
                            client.isFloating = false;
                            monitor.workspace.split.add(client, monitor.workspace.split.clients.length);
                        }
                        return;
                    }
                    auto xt = offset.x * client.size.w / width;
                    client.moveResize([x, y].a + [xt, offset.y], client.sizeFloating);
                }
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
