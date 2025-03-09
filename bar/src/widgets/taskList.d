module bar.widget.taskList;

import bar;


import ws.bindings.xlib, common.log, common.xevents;


class TaskList: Widget {

    Bar bar;
    int[] separators;
    int start;
    int extents;
    long currentWorkspace;

    override int width(){
        return size.w;
    }

    this(Bar bar){
        this.bar = bar;
        currentWorkspace = .root.props._NET_CURRENT_DESKTOP.get!long;
        Events[.root] ~= this;
    }

    override void destroy(){
        Events.forget(this);
    }

    @WindowProperty
    void windowProperty(XPropertyEvent* e){
        if(e.atom == Atoms._NET_CURRENT_DESKTOP){
            currentWorkspace = .root.props._NET_CURRENT_DESKTOP.get!long;
        }
    }

    void update(Client[] clients){
        separators = [];
        children = [];

        auto tabs = clients
            .filter!(a => !a._NET_WM_STATE.canFind(Atoms._NET_WM_STATE_SKIP_TASKBAR)
                          && a._NET_WM_DESKTOP.value == currentWorkspace
                          && a.screen == bar.screen
                          && a._FLATMAN_TABS.value != 0)
            .array
            .sort!((a, b) => a._FLATMAN_TABS.value < b._FLATMAN_TAB.value)
            .chunkBy!(a => a._FLATMAN_TABS.value)
            .map!(a => a[1]
                       .array
                       .sort!((w1, w2) => w1._FLATMAN_TAB.value < w2._FLATMAN_TAB.value))
            .array;

        if(!tabs.length)
        	return;
		int width = ((size.w - tabs.length*config.theme.separatorWidth).to!double/(tabs.map!(a => a.length).sum))
					.min(250)
					.to!int;
        extents = ((tabs.map!(a => a.length).sum)*width + (tabs.length-1)*config.theme.separatorWidth).to!int;
        start = pos.x + size.w/2 - extents/2;
        int offset = start;
		foreach(i, tab; tabs){
            if(i != 0)
                separators ~= offset;
			foreach(client; tab){
                auto listEntry = addNew!TaskListEntry(bar, client);
                listEntry.move([offset,0]);
                listEntry.resize([width, size.h]);
				offset += width;
			}
			offset += config.theme.separatorWidth;
		}
    }

    override void onDraw(){
        foreach(separator; separators){//} ~ [start+extents-10]){
            draw.setColor(config.theme.separatorColor);
            draw.text([separator-config.theme.separatorWidth/2-5,7], "|");
        }
        super.onDraw;
    }

}
