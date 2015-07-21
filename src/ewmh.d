module flatman.ewmh;

import flatman;


struct NetAtoms {
	@("_NET_SUPPORTED") Atom supported;
	@("_NET_WM_NAME") Atom wmName;
	@("_NET_WM_STATE") Atom wmState;
	@("_NET_WM_STATE_FULLSCREEN") Atom wmFullscreen;
	@("_NET_ACTIVE_WINDOW") Atom activeWindow;
	@("_NET_WM_WINDOW_TYPE") Atom wmWindowType;
	@("_NET_WM_WINDOW_TYPE_DIALOG") Atom wmWindowTypeDialog;
	@("_NET_CLIENT_LIST") Atom clientList;
	@("_NET_WORKAREA") Atom workArea;
	@("_NET_CURRENT_DESKTOP") Atom currentDesktop;
	@("_NET_NUMBER_OF_DESKTOPS") Atom desktopCount;
	@("_NET_DESKTOP_NAMES") Atom desktopNames;
	//@("_NET_MOVERESIZE_WINDOW") Atom moveResize;
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
		names ~= ("~/.dinu/".expandTilde ~ i.to!string).readText ~ '\0'; 
	}
	replace(net.desktopNames, names);
}

void updateWindowDesktop(Client client, long n){
	replace(client.win, net.appDesktop, n);
}

/+
/*
 * Updates _NET_DESKTOP_VIEWPORT, which is an array of pairs of cardinals that
 * define the top left corner of each desktop's viewport.
 */
void ewmh_update_desktop_viewport(void) {
    Con *output;
    int num_desktops = 0;
    /* count number of desktops */
    TAILQ_FOREACH(output, &(croot->nodes_head), nodes) {
        Con *ws;
        TAILQ_FOREACH(ws, &(output_get_content(output)->nodes_head), nodes) {
            if (STARTS_WITH(ws->name, "__"))
                continue;

            num_desktops++;
        }
    }

    uint32_t viewports[num_desktops * 2];

    int current_position = 0;
    /* fill the viewport buffer */
    TAILQ_FOREACH(output, &(croot->nodes_head), nodes) {
        Con *ws;
        TAILQ_FOREACH(ws, &(output_get_content(output)->nodes_head), nodes) {
            if (STARTS_WITH(ws->name, "__"))
                continue;

            viewports[current_position++] = output->rect.x;
            viewports[current_position++] = output->rect.y;
        }
    }

    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root,
                        A__NET_DESKTOP_VIEWPORT, XCB_ATOM_CARDINAL, 32, current_position, &viewports);
}
+/

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

/+
/*
 * Updates the _NET_CLIENT_LIST_STACKING hint.
 *
 */
void ewmh_update_client_list_stacking(xcb_window_t *stack, int num_windows) {
    xcb_change_property(
        conn,
        XCB_PROP_MODE_REPLACE,
        root,
        A__NET_CLIENT_LIST_STACKING,
        XCB_ATOM_WINDOW,
        32,
        num_windows,
        stack);
}
+/


private alias CARDINAL = int;

private void replace()(Window window, Atom atom, string text){
	XChangeProperty(dpy, window, atom, XA_STRING, 8, PropModeReplace, cast(ubyte*)text.toStringz, cast(int)text.length);
}

private void replace(T)(Window window, Atom atom, T value){
	XChangeProperty(dpy, window, atom, XA_CARDINAL, 32, PropModeReplace, cast(ubyte*)&value, 1);
}

private void append(Window window, Atom atom, CARDINAL value){
	XChangeProperty(dpy, window, atom, XA_CARDINAL, 32, PropModeAppend, cast(ubyte*)&value, 1);
}

private void append(Window window, Atom atom, CARDINAL[] value){
	XChangeProperty(dpy, window, atom, XA_CARDINAL, 32, PropModeAppend, cast(ubyte*)value.ptr, cast(int)value.length);
}

private void remove(Window window, Atom atom){
	XDeleteProperty(dpy, window, atom);
}

private void append(T)(Atom atom, T value){
	replace(root, atom, value);
}

private void replace(T)(Atom atom, T value){
	replace(root, atom, value);
}

private void remove(Atom atom){
	remove(root, atom);
}

static assert(CARDINAL.sizeof == 32/8);
