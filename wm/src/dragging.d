module flatman.dragging;


import flatman;


void dragClient(Client client, int[2] offset){

    auto width = client.size.w;

    drag((int[2] pos){
        with(Log("drag")){
            if(!clients.canFind(client))
                return;

            auto x = pos.x;
            auto y = pos.y;

            Monitor target;
            if((target = findMonitor(pos)) != monitor && monitor){
                if(monitor && monitor.active)
                    monitor.active.unfocus(true);
                monitor = target;
                if(monitor.active)
                    monitor.active.focus;
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


void drag(void delegate(int[2]) dragDg, void delegate() dropDg=null){
    drop();
    .dragDg = dragDg;
    .dropDg = dropDg;
    XGrabPointer(dpy, root, true,
                    ButtonPressMask | ButtonReleaseMask | PointerMotionMask | FocusChangeMask | EnterWindowMask | LeaveWindowMask,
                    GrabModeAsync, GrabModeAsync, None, None, CurrentTime);
}


void drop(){
    XUngrabPointer(dpy, CurrentTime);
    if(dropDg)
        dropDg();
    dragDg = null;
    dropDg = null;
}


void dragInit(){
    mouseMoved ~= (int[2] p){ cursorPos = p; };
    mouseReleased ~= (Mouse.button b){
        if(b == Mouse.buttonLeft)
            drop();
    };
    tick ~= &update;
}


bool dragging(){
    return dragDg != null;
}


private {

    int[2] cursorPos;
	void delegate(int[2]) dragDg;
	void delegate() dropDg;

    void update(){
        if(dragDg){
            dragDg(cursorPos);
        }
    }

}
