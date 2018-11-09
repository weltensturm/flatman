module flatman.workspaceHistory;


import flatman;


class WorkspaceHistory {

	struct HistoryEntry {
		int monitor;
		int workspace;
	}

	HistoryEntry[] history;

	int historySelector = -1;

	string[] workspaceNames;

	WorkspaceHistoryWindow window;

	this(){
		Events ~= this;
		window = new WorkspaceHistoryWindow(this);
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
				window.update;
			}
		}
	}

	private void push(int monitor, int workspace){
		auto entry = HistoryEntry(monitor, workspace);
		history = entry ~ history.filter!(a => a.workspace != workspace).array;
	}

	@WorkspaceCreate
	void workspaceCreate(int ws){
		log(Log.RED ~ "WS CREATE " ~ ws.to!string ~ Log.DEFAULT ~ " " ~ history.to!string);
		foreach(ref entry; history){
			if(ws >= entry.workspace)
				entry.workspace++;
		}
		history ~= HistoryEntry(0, ws);
		log(Log.RED ~ "WS CREATED " ~ ws.to!string ~ Log.DEFAULT ~ " " ~ history.to!string);
	}

	@WorkspaceDestroy
	void workspaceDestroy(int ws){
		log(Log.RED ~ "WS DESTROY " ~ ws.to!string ~ Log.DEFAULT ~ " " ~ history.to!string);
		history = history.filter!(a => a.workspace != ws).array;
		foreach(ref entry; history){
			if(ws >= entry.workspace)
				entry.workspace--;
		}
		log(Log.RED ~ "WS DESTROYED " ~ ws.to!string ~ Log.DEFAULT ~ " " ~ history.to!string);

	}

    /+
	@WorkspaceSwitch
	void workspaceSwitch(int ws){
		if(historySelector == -1){
			foreach(i, m; monitors){
				if(m == monitor)
					push(i.to!int, ws);
			}
		}
	}
    +/

	@Overview
	void overview(bool activate){
		if(!activate){
			foreach(i, m; monitors){
				if(m == monitor){
					push(i.to!int, monitor.workspaceActive);
				}
			}
			historySelector = -1;
			window.hide;
		}else{
			historySelector = 0;
		}
	}

	void updateNames(){
		workspaceNames = Atoms._NET_DESKTOP_NAMES.get!string.split('\0');
		while(workspaceNames.length < history.length)
			workspaceNames ~= "Workspace";
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


class WorkspaceHistoryWindow: Base {


	Client client;

	x11.X.Window window;

	int[2] dragStart;
	double clickTime;

	bool hasMouseFocus;

    XDraw _draw;
	int[2] _cursorPos;

	WorkspaceHistory history;

	override int[2] cursorPos(){
		return _cursorPos;
	}

	override DrawEmpty draw(){
		return _draw;
	}

	this(WorkspaceHistory history){
		this.history = history;

		size = [10, 10];
		hidden = true;

		/+
		auto visual = new XVisualInfo;
		if(!XMatchVisualInfo(dpy, DefaultScreen(dpy), 32, TrueColor, visual))
			writeln("XMatchVisualInfo failed");
		+/

		XSetWindowAttributes wa;
		wa.override_redirect = true;
    	//wa.colormap = XCreateColormap(dpy, DefaultRootWindow(dpy), visual.visual, AllocNone);

		window = XCreateWindow(
				dpy,
				flatman.root,
				pos.x, pos.y, size.w, size.h, 0,
				DefaultDepth(dpy, 0),
				InputOutput,
				DefaultVisual(dpy, 0), //visual.visual,
                CWBorderPixel | CWOverrideRedirect | CWColormap | CWBackPixmap | CWEventMask,
				&wa
		);
		XSelectInput(dpy, window, ExposureMask | EnterWindowMask | LeaveWindowMask | ButtonPressMask |
								  ButtonReleaseMask | PointerMotionMask);
        _draw = new XDraw(dpy, window);
		draw.setFont(config.tabs.title.font, config.tabs.title.fontSize);
		Events[window] ~= this;
	}

	void update(){
		show;

		auto rowHeight = draw.fontHeight*2;
		auto padding = rowHeight;

		auto width = history.workspaceNames.map!(a => draw.width(a)).fold!max(0) + padding;
		auto height = history.history.length.to!int*rowHeight + padding;

		int[2] size = [width, height];
		move(monitors[0].pos.a + monitors[0].size.a/2 - size.a/2);
		resize(size);
		onDraw;
	}

	override void show(){
		"workspaceHistoryWindow.show".log;
		XMapWindow(dpy, window);
	}

	override void hide(){
		"workspaceHistoryWindow.hide".log;
		XUnmapWindow(dpy, window);
	}

	override void move(int[2] pos){
		XMoveWindow(dpy, window, pos.x, pos.y);
	}

	override void resize(int[2] size){
		XResizeWindow(dpy, window, size.w.max(1), size.h.max(1));
	}

    @WindowMap
    override void onShow(){
        hidden = false;
    }

    @WindowUnmap
    override void onHide(){
        hidden = true;
    }

	void destroy(){
		"workspaceHistoryWindow.destroy".log;
		hide;
		XDestroyWindow(dpy, window);
	}

	@WindowDestroy
	void onDestroy(){
		draw.destroy;
		Events.forget(this);
	}

	@WindowResize
	void onResize(int[2] size){
        "%s resize %s".format(draw, size).log;
		draw.resize([size.w.max(1), size.h.max(1)]);
		this.size = size;
	}

	@WindowMove
	void onMove(int[2] pos){
		this.pos = pos;
	}

	@WindowExpose
	override void onDraw(){
		if(hidden)
			return;

		auto rowHeight = draw.fontHeight*2;
		auto background = config.tabs.background.normal;
		draw.setColor(background);
		draw.rect([0,0], size);

		foreach(i, entry; history.history){
			if(i == history.historySelector){
				draw.setColor([0.3, 0.3, 0.3, 1]);
				draw.rect([0, i.to!int*rowHeight + rowHeight/2], [size.w, rowHeight]);
			}
			if(entry.workspace < history.workspaceNames.length){
				auto name = history.workspaceNames[entry.workspace];
				if(!name.length)
					continue;
				auto prefix = name.split("/")[0..$-1].join("/");
				if(prefix.length)
					prefix ~= "/";
				auto cwd = name.split("/")[$-1];
				int x = rowHeight/2;
				draw.setColor([0.5, 0.5, 0.5, 1]);
				x += draw.text([x, i.to!int*rowHeight + rowHeight/2], rowHeight, prefix, 0);
				draw.setColor([1, 1, 1, 1]);
				x += draw.text([x, i.to!int*rowHeight + rowHeight/2], rowHeight, cwd, 0);
			}else{
				draw.text([0, i.to!int*rowHeight], "Workspace " ~ entry.workspace.to!string);
			}
		}

		draw.finishFrame;

	}


}

