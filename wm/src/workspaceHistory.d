module flatman.workspaceHistory;

import flatman;

import common.xevents;


class WorkspaceHistory {

	struct HistoryEntry {
		int monitor;
		int workspace;
	}

	HistoryEntry[] history;

	int historySelector = -1;

	string[] workspaceNames;

	this(){
		Events ~= this;
		foreach(i, ws; monitor.workspaces)
			push(0, i.to!int);
		updateNames;
	}

	void destroy(){
		Events.forget(this);
	}

	@(Command["workspace-history", true])
	auto command(string[] args){
		with(Log(Log.YELLOW ~ "workspace-history " ~ Log.DEFAULT ~ args[0])){
			if(historySelector > -1){
				historySelector += args[0] == "next" ? 1 : -1;
				if(historySelector < 0)
					historySelector = history.length.to!int-1;
				if(historySelector >= history.length)
					historySelector = 0;
				auto entry = history[historySelector];
				monitors[entry.monitor].focus;
				switchWorkspace(entry.workspace);
			}
		}
	}

	private void update(){
		long[] wsEmpty;
		ws_iter:foreach(i; 0..monitor.workspaces.length){
			foreach(monitor; monitors)
				if(monitor.workspaces[i].clients.length || i == monitor.workspaceActive)
					continue ws_iter;
			wsEmpty ~= i;
		}
		history.sort!((a, b) => int(wsEmpty.canFind(a.workspace)) < int(wsEmpty.canFind(b.workspace)));
		Atoms._FLATMAN_WORKSPACE_HISTORY.replace(history.map!(a => a.workspace.to!long).array);
		Atoms._FLATMAN_WORKSPACE_EMPTY.replace(wsEmpty);
	}

	private void push(int monitor, int workspace){
		auto entry = HistoryEntry(monitor, workspace);
		history = entry ~ history.filter!(a => a.workspace != workspace).array;
		update;
	}

	@WorkspaceCreate
	void workspaceCreate(int ws){
		log(Log.RED ~ "WS CREATE " ~ ws.to!string ~ Log.DEFAULT ~ " " ~ history.to!string);
		foreach(ref entry; history){
			if(entry.workspace >= ws)
				entry.workspace++;
		}
		if(ws == monitor.workspaceActive)
			push(0, ws);
		else
			history ~= HistoryEntry(0, ws);
		log(Log.RED ~ "WS CREATED " ~ ws.to!string ~ Log.DEFAULT ~ " " ~ history.to!string);
	}

	@WorkspaceDestroy
	void workspaceDestroy(int ws){
		log(Log.RED ~ "WS DESTROY " ~ ws.to!string ~ Log.DEFAULT ~ " " ~ history.to!string);
		history = history.filter!(a => a.workspace != ws).array;
		foreach(ref entry; history){
			if(entry.workspace > ws)
				entry.workspace--;
		}
		log(Log.RED ~ "WS DESTROYED " ~ ws.to!string ~ Log.DEFAULT ~ " " ~ history.to!string);
		update;
	}

	@WorkspaceSwitch
	void workspaceSwitch(int ws){
		if(historySelector == -1){
			foreach(i, m; monitors){
				if(m == monitor)
					push(i.to!int, ws);
			}
		}
	}

	@Overview
	void overview(bool activate){
		if(!activate){
			foreach(i, m; monitors){
				if(m == monitor){
					push(i.to!int, monitor.workspaceActive);
				}
			}
			historySelector = -1;
		}else{
			historySelector = 0;
		}
	}

	void updateNames(){
		workspaceNames = Atoms._NET_DESKTOP_NAMES.get!string.split('\0');
		while(workspaceNames.length < history.length)
			workspaceNames ~= "Workspace";
	}

	@WindowFocusIn
	void onWindowFocus(Window){
		if(historySelector == -1){
			history[0].monitor = monitors.countUntil(monitor).to!int;
		}
	}

	@WindowProperty
	void onProperty(Window window, XPropertyEvent* ev){
		if(window == .root){
			if(ev.atom == Atoms._NET_DESKTOP_NAMES){
				updateNames;
			}
		}
	}

}

