module flatman.x.ewmh;

import flatman;

__gshared:

enum _NET_WM_STATE_REMOVE = 0;
enum _NET_WM_STATE_ADD = 1;
enum _NET_WM_STATE_TOGGLE = 2;


struct NetAtoms {
	@("_NET_SUPPORTED") Atom supported;
	@("_NET_CLIENT_LIST") Atom clientList;
	@("_NET_CLIENT_LIST_STACKING") Atom clientListStacking;

	@("_NET_WORKAREA") Atom workArea;
	@("_NET_DESKTOP_GEOMETRY") Atom geometry;
	@("_NET_DESKTOP_VIEWPORT") Atom viewport;
	@("_NET_CURRENT_DESKTOP") Atom currentDesktop;
	@("_NET_NUMBER_OF_DESKTOPS") Atom desktopCount;
	@("_NET_DESKTOP_NAMES") Atom desktopNames;

	@("_NET_MOVERESIZE_WINDOW") Atom moveResize;
	@("_NET_RESTACK_WINDOW") Atom restack;
	@("_NET_ACTIVE_WINDOW") Atom windowActive;

	@("_NET_WM_PID") Atom pid;
	@("_NET_WM_NAME") Atom name;
	@("_NET_WM_ICON") Atom icon;
	@("_NET_WM_STATE") Atom state;
	@("_NET_WM_STATE_MODAL") Atom modal;
	@("_NET_WM_STATE_FULLSCREEN") Atom fullscreen;
	@("_NET_WM_STATE_DEMANDS_ATTENTION") Atom attention;
	@("_NET_WM_STRUT_PARTIAL") Atom strutPartial;
	@("_NET_WM_WINDOW_TYPE") Atom windowType;
	@("_NET_WM_WINDOW_TYPE_DIALOG") Atom windowTypeDialog;
	@("_NET_WM_WINDOW_TYPE_DOCK") Atom windowTypeDock;
	@("_NET_WM_WINDOW_TYPE_SPLASH") Atom windowTypeSplash;
	@("_NET_WM_DESKTOP") Atom windowDesktop;
	@("_NET_WM_USER_TIME") Atom userTime;

	@("_NET_SUPPORTING_WM_CHECK") Atom supportingWm;
}

NetAtoms net;

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
	auto window = XCreateSimpleWindow(dpy, root, 0, 0, 1, 1, 0, 0, 0);
	foreach(w; [root, window]){
		w.replace(net.supportingWm, window);
		w.replace(net.name, "flatman");
	}
}


void updateCurrentDesktop(){
	replace(net.currentDesktop, cast(long)monitor.workspaceActive); 
}

void updateDesktopCount(){
	replace(net.desktopCount, cast(CARDINAL)monitor.workspaces.length);
}

void updateDesktopNames(){
	string names;
	foreach(i, ws; monitor.workspaces){
		try{
			names ~= std.array.replace(ws.context.expandTilde.readText, "~".expandTilde, "~");
		}catch{
			names ~= "~";
		}
		names ~= "\0";
	}
	net.desktopNames.replace(names);
}

void updateWindowDesktop(Client client, long n){
	client.win.replace!CARDINAL(net.windowDesktop, n);
}

void updateWorkspaces(){
	foreach(monitor; monitors){
		foreach(n, ws; monitor.workspaces){
			foreach(s; ws.split.separators){
				s.window.replace!CARDINAL(net.windowDesktop, n);
			}
			foreach(f; ws.floating.frames)
				f.window.replace!CARDINAL(net.windowDesktop, n);
			foreach(c; ws.clients)
				c.updateWindowDesktop(n);
		}
	}
	updateDesktopNames;
}

void updateActiveWindow(){
	replace(net.windowActive, monitor.active.win);
}

void updateWorkarea(){
	CARDINAL[] data;
	foreach(ws; monitor.workspaces)
		data ~= [ws.split.pos.x, ws.split.pos.y, ws.split.size.w, ws.split.size.h];
	net.workArea.replace(data);
	net.viewport.replace([0L,0L]);
	"RESIZE %s".format(monitor.size.to!(long[])).log;
	net.geometry.replace(monitor.size.to!(long[]));
}

void updateClientList(){
	auto clients = clients;
	net.clientList.replace(clients);
	net.clientListStacking.replace(clients);
}

