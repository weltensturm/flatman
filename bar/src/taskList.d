module bar.taskList;

import bar;


class TaskList: Base {

    Bar bar;
    int[] separators;
    int start;
    int extents;

    this(Bar bar){
        this.bar = bar;
    }

    void update(Client[] clients){
        separators = [];
        children = [];
		Client[][] tabs;
		foreach(client; clients){
			if(client.workspace.value == bar.currentWorkspace.value && client.title.length && client.icon.length){
				if(client.screen != bar.screen)
					continue;
                if(client.flatmanTabs.value == 0)
                    continue;
				while(tabs.length < client.flatmanTabs.value){
					tabs ~= cast(Client[])[];
				}
				auto tab = tabs[client.flatmanTabs.value-1];
				bool found;
				foreach(i, compare; tab){
					if(compare.flatmanTab.value > client.flatmanTab.value){
						tabs[client.flatmanTabs.value-1] = tab[0..i] ~ client ~ tab[i..$];
						found = true;
						break;
					}
				}
				if(!found)
					tabs[client.flatmanTabs.value-1] ~= client;
			}
		}
		int width = ((size.w - config.separatorWidth - tabs.length*config.separatorWidth - (bar.left.max(bar.right)*2)).to!double/(tabs.map!(a => a.length).sum))
					.min(250)
					.to!int;
        extents = ((tabs.map!(a => a.length).sum)*width + tabs.length*config.separatorWidth).to!int;
        start = size.w/2 - extents/2;
        int offset = start;
		foreach(i, tab; tabs){
            if(i != 0)
                separators ~= offset-config.separatorWidth/2;
			foreach(client; tab){
                auto listEntry = addNew!TaskListEntry(bar, client);
                listEntry.move([offset,0]);
                listEntry.resize([width, size.h]);
				offset += width;
			}
			offset += config.separatorWidth;
		}
    }

    override void onDraw(){
        foreach(separator; separators){//} ~ [start+extents-10]){
            draw.setColor(config.separatorColor);
            draw.text([separator-config.separatorWidth/2-5,7], "●");
        }
        super.onDraw;
    }

}