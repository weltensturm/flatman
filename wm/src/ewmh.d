module flatman.ewmh;

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
}

NetAtoms net;


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
			names ~= ws.context.expandTilde.readText;
		}catch{
			names ~= "~";
		}
		names ~= "\0";
	}
	net.desktopNames.replace(names);
}

void updateWindowDesktop(Client client, long n){
	replace(client.win, net.windowDesktop, n);
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


alias CARDINAL = long;


void change(Window window, Atom atom, Atom[] data, int mode){
	int r = XChangeProperty(dpy, window, atom, XA_ATOM, 32, mode, cast(ubyte*)data.ptr, cast(int)data.length);
	if(r)
		"property change error: Window %s Atom %s data %s mode %s".format(window, atom, data, mode);
}

void change(Window window, Atom atom, CARDINAL[] data, int mode){
	int r = XChangeProperty(dpy, window, atom, XA_CARDINAL, 32, mode, cast(ubyte*)data.ptr, cast(int)data.length);
	if(r)
		"property change error: Window %s Atom %s data %s mode %s".format(window, atom, data, mode);
}

void change(Window window, Atom atom, CARDINAL data, int mode){
	int r = XChangeProperty(dpy, window, atom, XA_CARDINAL, 32, mode, cast(ubyte*)&data, 1);
	if(r)
		"property change error: Window %s Atom %s data %s mode %s".format(window, atom, data, mode);
}

void change(Window window, Atom atom, string data, int mode){
	int r = XChangeProperty(dpy, window, atom, XInternAtom(dpy, "UTF8_STRING", False), 8, mode, cast(ubyte*)data.toStringz, cast(int)data.length);
	if(r)
		"property change error: Window %s Atom %s data %s mode %s".format(window, atom, data, mode);
}

void change(Window window, Atom atom, Window data, int mode){
	int r = XChangeProperty(dpy, window, atom, XA_WINDOW, 32, mode, cast(ubyte*)&data, 1);
	if(r)
		"property change error: Window %s Atom %s data %s mode %s".format(window, atom, data, mode);
}

void change(Window window, Atom atom, Client[] clients, int mode){
	Window[] data;
	foreach(c; clients)
		data ~= c.win;
	int r = XChangeProperty(dpy, window, atom, XA_WINDOW, 32, mode, cast(ubyte*)data.ptr, cast(int)data.length);
	if(r)
		"property change error: Window %s Atom %s data %s mode %s".format(window, atom, data, mode);
}

void replace(T)(Window window, Atom atom, T data){
	change(window, atom, data, PropModeReplace);
}

void append(T)(Window window, Atom atom, T data){
	change(window, atom, data, PropModeAppend);
}

void remove(Window window, Atom atom){
	XDeleteProperty(dpy, window, atom);
}

void append(T)(Atom atom, T data){
	replace(root, atom, data);
}

void replace(T)(Atom atom, T data){
	replace(root, atom, data);
}

void remove(Atom atom){
	remove(root, atom);
}
