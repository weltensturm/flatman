module flatman.x.ewmh;

import flatman;

__gshared:

enum _NET_WM_STATE_REMOVE = 0;
enum _NET_WM_STATE_ADD = 1;
enum _NET_WM_STATE_TOGGLE = 2;



Atom[] netSupported(){
	return [
		Atoms._NET_SUPPORTED,
		Atoms._NET_CLIENT_LIST,
		Atoms._NET_CLIENT_LIST_STACKING,
		Atoms._NET_WORKAREA,
		Atoms._NET_DESKTOP_GEOMETRY,
		Atoms._NET_DESKTOP_VIEWPORT,
		Atoms._NET_CURRENT_DESKTOP,
		Atoms._NET_NUMBER_OF_DESKTOPS,
		Atoms._NET_DESKTOP_NAMES,
		Atoms._NET_MOVERESIZE_WINDOW,
		Atoms._NET_RESTACK_WINDOW,
		Atoms._NET_ACTIVE_WINDOW,
		Atoms._NET_WM_MOVERESIZE,
		Atoms._NET_WM_PID,
		Atoms._NET_WM_NAME,
		Atoms._NET_WM_ICON,
		Atoms._NET_WM_STATE,
		Atoms._NET_WM_STATE_MODAL,
		Atoms._NET_WM_STATE_FULLSCREEN,
		Atoms._NET_WM_STATE_DEMANDS_ATTENTION,
		Atoms._NET_WM_STRUT_PARTIAL,
		Atoms._NET_WM_WINDOW_TYPE,
		Atoms._NET_WM_WINDOW_TYPE_DIALOG,
		Atoms._NET_WM_WINDOW_TYPE_DOCK,
		Atoms._NET_WM_WINDOW_TYPE_SPLASH,
		Atoms._NET_WM_WINDOW_TYPE_NOTIFICATION,
		Atoms._NET_WM_DESKTOP,
		Atoms._NET_WM_USER_TIME,
		Atoms._NET_SUPPORTING_WM_CHECK
	];
}


Window getWindow(Window window, Atom prop){
	int di;
	ulong dl;
	ubyte* p;
	Atom da, atom = None;
	if(XGetWindowProperty(dpy, window, prop, 0L, atom.sizeof, false, XA_WINDOW,
	                      &da, &di, &dl, &dl, &p) == Success && p){
		atom = *cast(Atom*)p;
		XFree(p);
	}
	return atom;
}


void setSupportingWm(){
	XSetWindowAttributes wa;
	wa.override_redirect = true;
	auto window = XCreateWindow(dpy, root, 0, 0, 1, 1, 0,
				DefaultDepth(dpy, screen),
				CopyFromParent,
				DefaultVisual(dpy, screen),
				CWOverrideRedirect,
				&wa
	);
	foreach(w; [root, window]){
		w.replace(Atoms._NET_SUPPORTING_WM_CHECK, window);
		w.replace(Atoms._NET_WM_NAME, "flatman");
	}
}


void updateCurrentDesktop(){
	replace(Atoms._NET_CURRENT_DESKTOP, cast(long)monitor.workspaceActive); 
}

void updateDesktopCount(){
	replace(Atoms._NET_NUMBER_OF_DESKTOPS, cast(CARDINAL)monitor.workspaces.length);
}

void updateDesktopNames(){
	string names;
	foreach(i, ws; monitor.workspaces){
		try{
			names ~= std.array.replace(ws.context.expandTilde.readText, "~".expandTilde, "~");
		}catch(Throwable) {
			names ~= "~";
		}
		names ~= "\0";
	}
	Atoms._NET_DESKTOP_NAMES.replace(names);
}

void updateWindowDesktop(Client client, long n){
	client.win.replace!CARDINAL(Atoms._NET_WM_DESKTOP, n);
	if(client.frame)
		client.frame.window.replace!CARDINAL(Atoms._NET_WM_DESKTOP, n);
}

void updateWorkspaces(){
	foreach(monitor; monitors){
		foreach(n, ws; monitor.workspaces){
			foreach(s; ws.split.separators){
				s.window.replace!CARDINAL(Atoms._NET_WM_DESKTOP, n);
			}
			foreach(c; ws.clients)
				c.updateWindowDesktop(n);
		}
	}
	updateDesktopNames;
}

void updateActiveWindow(){
	replace(Atoms._NET_ACTIVE_WINDOW, monitor.active.win);
}

void updateWorkarea(){
	CARDINAL[] data;
	foreach(ws; monitor.workspaces)
		//data ~= [ws.split.pos.x, ws.split.pos.y, ws.split.size.w, ws.split.size.h];
		data ~= [0, 0, sw, sh];
	Atoms._NET_WORKAREA.replace(data);
	Atoms._NET_DESKTOP_VIEWPORT.replace(monitor.pos.to!(long[]));
	"RESIZE %s".format(monitor.size.to!(long[])).log;
	Atoms._NET_DESKTOP_GEOMETRY.replace(monitor.size.to!(long[]));
}

void updateClientList(){
	auto clients = clients;
	foreach(c; clients)
		assert(!c.destroyed);
	Atoms._NET_CLIENT_LIST.replace(clients);
	Atoms._NET_CLIENT_LIST_STACKING.replace(clients);
}

