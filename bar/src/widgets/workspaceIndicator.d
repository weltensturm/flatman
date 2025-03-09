module bar.widget.workspaceIndicator;


import ws.bindings.xlib, bar, common.xevents;


class WorkspaceIndicator: Widget {

    mixin WindowProperties!q{
        _NET_DESKTOP_NAMES   XA_STRING
        _NET_CURRENT_DESKTOP XA_CARDINAL
    };

    string workspace;

    this(){
        setPropertyWindow(.root);
        _NET_DESKTOP_NAMES ~= (v) => update;
        _NET_CURRENT_DESKTOP ~= (v) => update;
        update;
        Events ~= this;
    }

    override void destroy(){
        Events.forget(this);
    }

    @WindowProperty
    void windowProperty(WindowHandle window, XPropertyEvent* e){
        updateProperties(e);
    }

    override int width(){
        return draw.width(workspace);
    }

    override void onDraw(){
        draw.setColor(config.theme.foreground);
        auto parts = workspace.split("/");
        if(!parts.length)
            return;
        auto x = pos.x;
        x += draw.text([5+x,5], parts[0..$-1].join("/"), 0);
        if(parts.length > 1)
            x += draw.text([5+x, 5], "/", 0);
        draw.setColor(config.theme.foregroundMain);
        draw.text([5+x, 5], parts[$-1], 0);
    }

    void update(){
        auto names = _NET_DESKTOP_NAMES.value.split('\0');
        if(_NET_CURRENT_DESKTOP.value < names.length){
            workspace = names[_NET_CURRENT_DESKTOP.value];
        }else{
            workspace = "/";
        }
    }

}

