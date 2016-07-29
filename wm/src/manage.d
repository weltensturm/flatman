module flatman.manage;


import flatman;


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
				handler[ev.type](&ev);
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
				handler[ev.type](&ev);
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
	if(!client.sendEvent(wm.delete_)){
		XGrabServer(dpy);
		XSetErrorHandler(&xerrordummy);
		XSetCloseDownMode(dpy, CloseDownMode.DestroyAll);
		XKillClient(dpy, client.win);
		XSync(dpy, false);
		XSetErrorHandler(&xerror);
		//XSetErrorHandler(xerrorxlib);
		XUngrabServer(dpy);
	}
	client.unmanage;
}

void toggleFullscreen(){
	auto client = active;
	if(!client)
		return;
	client.setFullscreen(!client.isfullscreen);
}

void newWorkspace(long pos){
	"new workspace: %s".format(pos).log;
	foreach(monitor; monitors){
		auto ws = new Workspace(monitor.pos, monitor.size);
		if(pos <= 0)
			monitor.workspaces = ws ~ monitor.workspaces;
		else if(pos > monitor.workspaces.length-1)
			monitor.workspaces ~= ws;
		else
			monitor.workspaces.insertInPlace(pos, ws);
		if(monitor.workspaceActive >= pos)
			monitor.workspaceActive++;
	}
	updateDesktopCount;
	updateWorkspaces;
}

void switchWorkspace(int pos){
	if(pos == monitor.workspaceActive)
		return;
	with(Log("workspace = %s".format(pos))){
		bool destroy = true;
		foreach(monitor; monitors){
			if(monitor.workspace.clients.length != 0 || monitor.workspaces.length <= 1){
				destroy = false;
				break;
			}
		}
		foreach(monitor; monitors){
			monitor.workspace.hide;
			if(destroy){
				monitor.workspace.destroy;
				monitor.workspaces = monitor.workspaces.without(monitor.workspace);
				if(pos > monitor.workspaceActive)
					pos--;
			}
			monitor.workspaceActive = pos;
			if(monitor.workspaceActive < 0)
				monitor.workspaceActive = cast(int)monitor.workspaces.length-1;
			if(monitor.workspaceActive >= monitor.workspaces.length)
				monitor.workspaceActive = 0;
			monitor.workspace.show;
		}
		assert(monitors.map!(a => a.workspaces.length).uniq.array.length == 1);
		updateDesktopCount;
		updateWorkspaces;
		updateCurrentDesktop;
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
		win.focus;
}
