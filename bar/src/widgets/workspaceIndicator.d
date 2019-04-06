module bar.widget.workspaceIndicator;


import bar;


class WorkspaceIndicator: Widget {

    Properties!(
        "workspaceNames", "_NET_DESKTOP_NAMES", XA_STRING, false,
        "currentWorkspace", "_NET_CURRENT_DESKTOP", XA_CARDINAL, false
    ) properties;

    string workspace;

    this(){
        properties.window(.root);
        wm.on([PropertyNotify: (XEvent* e) => properties.update(&e.xproperty)]);
        properties.workspaceNames ~= (v) => update;
        properties.currentWorkspace ~= (v) => update;
        update;
    }

    override int width(){
        return draw.width(workspace);
    }

    override void onDraw(){
        draw.setColor(config.theme.foreground);
        auto parts = workspace.split("/");
        if(!parts.length)
            return;
        auto x = draw.text([5,5], parts[0..$-1].join("/"));
        if(parts.length > 1)
            x += draw.text([5+x, 5], "/");
        draw.setColor(config.theme.foregroundMain);
        draw.text([5+x, 5], parts[$-1]);
    }

    void update(){
        auto names = properties.workspaceNames.value.split('\0');
        if(properties.currentWorkspace.value < names.length){
            workspace = names[properties.currentWorkspace.value];
        }else{
            workspace = "/";
        }
    }

}

