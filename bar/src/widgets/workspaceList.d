module bar.widget.workspaceList;

import ws.bindings.xlib, bar, common.xevents;


struct Workspace {
    size_t index;
    string name;
}


class WorkspaceList: Widget {

    mixin WindowProperties!q{
        _NET_DESKTOP_NAMES         XA_STRING
        _FLATMAN_WORKSPACE_HISTORY XA_CARDINAL[]
        _NET_CURRENT_DESKTOP       XA_CARDINAL
    };

    Workspace[] workspaces;
    size_t workspaceCurrent;

    this(){
        setPropertyWindow(.root);
        _NET_DESKTOP_NAMES ~= (v) => update;
        _FLATMAN_WORKSPACE_HISTORY ~= (v) => update;
        _NET_CURRENT_DESKTOP ~= (v) => update;
        updateProperties;
        Events ~= this;
    }

    override void destroy(){
        Events.forget(this);
    }

    @WindowProperty
    void windowProperty(WindowHandle window, XPropertyEvent* e){
        if(window == .root)
            updateProperties(e);
    }

    override int width(){
        return workspaces.map!(a => draw.width(a.name) + 15).sum;
    }

    override void onDraw(){
        draw.setColor(config.theme.foreground);
        auto x = pos.x;
        foreach(workspace; workspaces){
            auto parts = workspace.name.split("/");
            if(!parts.length)
                continue;
            if(workspace.index == workspaceCurrent){
                draw.setColor([1, 1, 1, 0.1]);
                draw.rect([x, pos.y], [draw.width(workspace.name)+10, size.h]);
            }
            draw.setColor(config.theme.foreground);
            x += draw.text([5+x,5], parts[0..$-1].join("/"), 0);
            if(parts.length > 1)
                x += draw.text([5+x, 5], "/", 0);
            draw.setColor(config.theme.foregroundMain);
            x += draw.text([5+x, 5], parts[$-1], 0);
            x += 15;
        }
    }

    override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
        if(button == Mouse.buttonLeft){
            if(!pressed){
                XClientMessageEvent xev;
                xev.type = ClientMessage;
                xev.window = .root;
                xev.message_type = Atoms._NET_CURRENT_DESKTOP;
                xev.format = 32;
                xev.data.l[0] = 2;
                xev.data.l[1] = CurrentTime;
                xev.data.l[2] = 0;
                xev.data.l[3] = 0;    /* manager specific data */
                xev.data.l[4] = 0;    /* manager specific data */
                XSendEvent(wm.displayHandle, .root, false, StructureNotifyMask, cast(XEvent*) &xev);
            }
        }
        super.onMouseButton(button, pressed, x, y);
    }

    void update(){
        workspaces = [];
        foreach(i, ws; _NET_DESKTOP_NAMES.get.split('\0')){
            workspaces ~= Workspace(i, ws);
        }
        if(_NET_CURRENT_DESKTOP.get < workspaces.length){
            workspaceCurrent = _NET_CURRENT_DESKTOP.get;
        }else{
            workspaceCurrent = 0;
        }
        if(_FLATMAN_WORKSPACE_HISTORY.get.length){
            workspaces = workspaces.sorted(_FLATMAN_WORKSPACE_HISTORY.get);
        }
    }

}


auto sorted(T)(T[] workspaces, long[] sorting){

    alias key = (a){
        return sorting.countUntil(a.index);
    };

    auto sortedWorkspaces = workspaces.dup;

    sortedWorkspaces
        .sort!((a, b) => key(a) < key(b));

    return sortedWorkspaces;

}
