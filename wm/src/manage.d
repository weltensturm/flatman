module flatman.manage;


import flatman;


Client previousFocus;
Client currentFocus;
Client requestFocus;


void focus(Client client){
    if(client.destroyed || client == currentFocus && !requestFocus || requestFocus == client)
        return;
	"queue focus %s".format(client).log;
	requestFocus = client;
}


void focus(Monitor monitor){
	if(monitor != .monitor){
		Log("focus monitor " ~ monitor.to!string);
		.monitor = monitor;
	}
}


void focusTab(string direction){
	auto client = monitor.workspace.clientDir(direction == "next" ? 1 : -1);
	if(!client && !monitor.workspace.active){
		auto sorted = monitors
			.enumerate
			.array
			.multiSort!(
				(a, b) => a.value.pos.x < b.value.pos.x,
				(a, b) => a.value.pos.y < b.value.pos.y,
				(a, b) => a.index < b.index
			);
		
		auto index = sorted.countUntil!(a => monitors[a.index] == monitor) + (direction == "next" ? 1 : -1);

		if(index >= 0 && index < sorted.length){
			client = monitors[sorted[index][0]].active;
		}
		
	}
	if(client)
		client.focus;
}


void focusDir(string direction){
	auto client = monitor.workspace.clientContainerDir(direction);
	if(!client){
		auto sorted = monitors
			.enumerate
			.array
			.multiSort!(
				(a, b) => a.value.pos.x < b.value.pos.x,
				(a, b) => a.value.pos.y < b.value.pos.y,
				(a, b) => a.index < b.index
			);
		
		auto index = sorted.countUntil!(a => monitors[a.index] == monitor) + (direction == "right" ? 1 : -1);

		if(index >= 0 && index < sorted.length){
			client = monitors[sorted[index][0]].active;
		}
		
	}
	if(client)
		client.focus;
}


void manage(Window w, XWindowAttributes* wa, bool map, bool scan=false){
	if(!w)
		throw new Exception("No window given");
	if(find(w))
		return;
	with(Log(Log.RED ~ "manage" ~ Log.DEFAULT)){
		XSelectInput(dpy, w, EnterWindowMask|FocusChangeMask|PropertyChangeMask|StructureNotifyMask|KeyReleaseMask|KeyPressMask);
		auto c = new Client(w);
		auto monitor = findMonitor(c.pos, c.size);
		if(!monitor || !scan)
			monitor = .monitor;
		if(c.isFloating && c.pos.x == 0 && c.pos.y == 0)
			c.pos = monitor.size.a/2 - c.size.a/2;
		monitor.add(c, c.originWorkspace);
		XChangeProperty(dpy, root, Atoms._NET_CLIENT_LIST, XA_WINDOW, 32, PropModeAppend, cast(ubyte*)&c.win, 1);
		c.updateStrut;

		if(map){
			c.show;
			if(!active || active.parent == c.parent)
				c.focus;
		}else if(!scan)
			c.requestAttention;
		ensureEmptyWorkspace;
	}
}


void mouseMove(){
	Client c = monitor.active;
	if(!c || !c.isFloating || c.isfullscreen)
		return;
	XEvent ev;
	Time lasttime = 0;
	int ocx = c.pos.x;
	int ocy = c.pos.y;
	if(XGrabPointer(dpy, root, false, MOUSEMASK, GrabModeAsync, GrabModeAsync,
	None, cursor[CurMove].cursor, CurrentTime) != GrabSuccess)
		return;
	int x, y;
	if(!getrootptr(&x, &y))
		return;
	do {
		XMaskEvent(dpy, MOUSEMASK|ExposureMask|SubstructureRedirectMask, &ev);
		switch(ev.type){
			case ConfigureRequest:
			case Expose:
			case MapRequest:
				//handler[ev.type](&ev);
				break;
			case MotionNotify:
				if ((ev.xmotion.time - lasttime) <= (1000 / 60))
					continue;
				lasttime = ev.xmotion.time;
				int nx = ocx + (ev.xmotion.x - x);
				int ny = ocy + (ev.xmotion.y - y);
				c.moveResize([nx, ny], c.size);
				break;
			default: break;
		}
	} while(ev.type != ButtonRelease);
	XUngrabPointer(dpy, CurrentTime);
}


void mouseResize(){
	int ocx, ocy, nw, nh;
	Client c = monitor.active;
	if(!c || !c.isFloating || c.isfullscreen)
		return;
	Monitor* m;
	XEvent ev;
	Time lasttime = 0;
	ocx = c.pos.x;
	ocy = c.pos.y;
	if(XGrabPointer(dpy, root, false, MOUSEMASK, GrabModeAsync, GrabModeAsync,
	                None, cursor[CurResize].cursor, CurrentTime) != GrabSuccess)
		return;
	XWarpPointer(dpy, None, c.win, 0, 0, 0, 0, c.size.w - 1, c.size.h - 1);
	do {
		XMaskEvent(dpy, MOUSEMASK|ExposureMask|SubstructureRedirectMask, &ev);
		switch(ev.type){
			case ConfigureRequest:
			case Expose:
			case MapRequest:
				//handler[ev.type](&ev);
				break;
			case MotionNotify:
				if ((ev.xmotion.time - lasttime) <= (1000 / 60))
					continue;
				lasttime = ev.xmotion.time;

				nw = max(ev.xmotion.x - ocx - 2 * c.bw + 1, 1);
				nh = max(ev.xmotion.y - ocy - 2 * c.bw + 1, 1);
				c.moveResize(c.pos, [nw, nh]);
				break;
			default:break;
		}
	} while(ev.type != ButtonRelease);
	XWarpPointer(dpy, None, c.win, 0, 0, 0, 0, c.size.w - 1, c.size.h - 1);
	XUngrabPointer(dpy, CurrentTime);
	while(XCheckMaskEvent(dpy, EnterWindowMask, &ev)){}
}


void killClient(Client client=null){
	if(!client){
		if(!monitor.active)
			return;
		client = monitor.active;
	}
	if(!client.sentDelete){
		client.sendEvent(wm.delete_);
		client.sentDelete = true;
	}else{
		XGrabServer(dpy);
		XSetErrorHandler(&xerrordummy);
		XSetCloseDownMode(dpy, CloseDownMode.DestroyAll);
		XKillClient(dpy, client.win);
		XSetErrorHandler(&xerror);
		//XSetErrorHandler(xerrorxlib);
		XUngrabServer(dpy);
	}
}


void toggleFullscreen(){
	auto client = active;
	if(!client)
		return;
	client.setFullscreen(!client.isfullscreen);
}


void newWorkspace(long pos, string path=""){
	with(Log(Log.YELLOW ~ "new workspace %s".format(pos) ~ Log.DEFAULT)){
		foreach(monitor; monitors){
			auto ws = new Workspace(monitor.pos, monitor.size);
			if(pos <= 0)
				monitor.workspaces = ws ~ monitor.workspaces;
			else if(pos > monitor.workspaces.length-1)
				monitor.workspaces ~= ws;
			else
				monitor.workspaces.insertInPlace(pos, ws);
			monitor.resize(ws);
			if(monitor.workspaceActive >= pos)
				monitor.workspaceActive++;
			if(path.length){
				ws.updateContext(path);
			}
		}
		WorkspaceCreate(pos.max(0).min(monitor.workspaces.length-1).to!int);
		//monitor.resize(monitor.size);
		ewmh.updateDesktopCount;
		ewmh.updateWorkspaces;
	}
}


void switchWorkspace(int pos){
	if(!config.workspaceWrap){
		pos = pos.min(monitor.workspaces.length.to!int-1).max(0);
	}
	if(pos == monitor.workspaceActive)
		return;
	with(Log("workspace = %s".format(pos))){
		bool destroy = emptyWorkspaceCount > 1;
		foreach(monitor; monitors){
			if(monitor.workspace.clients.length != 0 || monitor.workspaces.length <= 1){
				destroy = false;
				break;
			}
		}
		if(destroy){
			WorkspaceDestroy(monitor.workspaceActive);
		}
		foreach(monitor; monitors){
			monitor.workspace.hide;
			if(destroy){
				monitor.workspace.destroy;
				monitor.workspaces = monitor.workspaces.without(monitor.workspace);
				if(pos > monitor.workspaceActive)
					pos--;
			}
			if(pos < 0)
				pos = cast(int)monitor.workspaces.length-1;
			if(pos >= monitor.workspaces.length)
				pos = 0;
			monitor.workspaceActive = pos;
			monitor.workspace.show;
		}
		assert(monitors.map!(a => a.workspaces.length).uniq.array.length == 1);
		if(monitor.active)
			focus(monitor.active);
		ewmh.updateDesktopCount;
		ewmh.updateWorkspaces;
		ewmh.updateCurrentDesktop;
		WorkspaceSwitch(pos);
		ensureEmptyWorkspace;
	}
}


size_t emptyWorkspaceCount(){
	size_t count;
	ws_iter:foreach(i; 0..monitor.workspaces.length){
		foreach(monitor; monitors)
			if(monitor.workspaces[i].clients.length)
				continue ws_iter;
		count++;
	}
	return count;
}


void ensureEmptyWorkspace(){
	if(emptyWorkspaceCount == 0){
		newWorkspace(monitor.workspaces.length, "~");
	}
}


void moveWorkspace(int pos){
	if(flatman.active)
		flatman.active.setWorkspace(pos);
}


void moveLeft(){
	monitor.workspace.split.moveClient(-1);
}


void moveRight(){
	monitor.workspace.split.moveClient(1);
}


void moveDown(){
	if(monitor.workspaceActive == monitor.workspaces.length-1)
		newWorkspace(monitor.workspaces.length);
	auto win = active;
	if(win)
		win.setWorkspace(monitor.workspaceActive+1);
	switchWorkspace(monitor.workspaceActive+1);
	if(win)
		win.focus;
}


void moveUp(){
	if(monitor.workspaceActive == 0)
		newWorkspace(0);
	auto win = active;
	if(win)
		win.setWorkspace(monitor.workspaceActive-1);
	switchWorkspace(monitor.workspaceActive-1);
	if(win)
		focus(win);
}
