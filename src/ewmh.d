module flatman.ewmh;

import flatman;

__gshared:


struct NetAtoms {
	@("_NET_SUPPORTED") Atom supported;
	@("_NET_WM_NAME") Atom wmName;
	@("_NET_WM_STATE") Atom wmState;
	@("_NET_WM_STATE_FULLSCREEN") Atom wmFullscreen;
	//@("_NET_WM_STRUT") Atom wmStrut;
	@("_NET_WM_STRUT_PARTIAL") Atom wmStrutPartial;
	@("_NET_ACTIVE_WINDOW") Atom activeWindow;
	@("_NET_WM_WINDOW_TYPE") Atom wmWindowType;
	@("_NET_WM_WINDOW_TYPE_DIALOG") Atom wmWindowTypeDialog;
	@("_NET_CLIENT_LIST") Atom clientList;
	@("_NET_WORKAREA") Atom workArea;
	@("_NET_CURRENT_DESKTOP") Atom currentDesktop;
	@("_NET_NUMBER_OF_DESKTOPS") Atom desktopCount;
	@("_NET_DESKTOP_NAMES") Atom desktopNames;
	@("_NET_MOVERESIZE_WINDOW") Atom moveResize;
	@("_NET_WM_DESKTOP") Atom appDesktop;
}

NetAtoms net;


void updateCurrentDesktop(){
	replace(net.currentDesktop, monitorActive.workspaceActive); 
}

void updateDesktopCount(){
	replace(net.desktopCount, tags.length);
}

void updateDesktopNames(){
	remove(net.desktopNames);
	char[] names;
	foreach(i, ws; monitorActive.workspaces){
		try{
			names ~= i.to!string ~ ": " ~ ("~/.dinu/".expandTilde ~ i.to!string).readText ~ '\0'; 
		}catch{
			names ~= "\0";
		}
	}
	replace(net.desktopNames, names);
}

void updateWindowDesktop(Client client, long n){
	replace(client.win, net.appDesktop, n);
}

void updateActiveWindow(){
	replace(net.activeWindow, monitorActive.active);
}

void updateWorkarea(){
	remove(net.workArea);
	foreach(ws; monitorActive.workspaces){
		append(net.workArea, [ws.split.pos.x, ws.split.pos.y, ws.split.size.w, ws.split.size.h]);
	}
}

void updateClientList(){
	XDeleteProperty(dpy, root, net.clientList);
	foreach(m; monitors)
		foreach(c; m.allClients)
			XChangeProperty(dpy, root, net.clientList, XA_WINDOW, 32, PropModeAppend, cast(ubyte*)&c.win, 1);
}


alias CARDINAL = int;

void replace()(Window window, Atom atom, string text){
	XChangeProperty(dpy, window, atom, XA_STRING, 8, PropModeReplace, cast(ubyte*)text.toStringz, cast(int)text.length);
}

void replace(T)(Window window, Atom atom, T value){
	XChangeProperty(dpy, window, atom, XA_CARDINAL, 32, PropModeReplace, cast(ubyte*)&value, 1);
}

void append(Window window, Atom atom, CARDINAL value){
	XChangeProperty(dpy, window, atom, XA_CARDINAL, 32, PropModeAppend, cast(ubyte*)&value, 1);
}

void append(Window window, Atom atom, CARDINAL[] value){
	XChangeProperty(dpy, window, atom, XA_CARDINAL, 32, PropModeAppend, cast(ubyte*)value.ptr, cast(int)value.length);
}

void remove(Window window, Atom atom){
	XDeleteProperty(dpy, window, atom);
}

void append(T)(Atom atom, T value){
	replace(root, atom, value);
}

void replace(T)(Atom atom, T value){
	replace(root, atom, value);
}

void remove(Atom atom){
	remove(root, atom);
}

static assert(CARDINAL.sizeof == 32/8);
