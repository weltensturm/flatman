module bar.widget.taskList;

import bar;


import common.log, common.xevents;


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
            .filter!(a => !a.state.value.canFind(Atoms._NET_WM_STATE_SKIP_TASKBAR)
                          && a.workspace.value == currentWorkspace
                          && a.screen == bar.screen
                          && a.flatmanTabs.value != 0)
            .array
            .sort!((a, b) => a.flatmanTabs.value < b.flatmanTabs.value)
            .chunkBy!(a => a.flatmanTabs.value)
            .map!(a => a[1]
                       .array
                       .sort!((w1, w2) => w1.flatmanTab.value < w2.flatmanTab.value))
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
