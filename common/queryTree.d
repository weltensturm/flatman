module common.queryTree;

import
	ws.wm,
    ws.bindings.xlib;


ws.bindings.c_xlib.Window[] queryTree(){
	auto root = XDefaultRootWindow(cast(Display*)wm.displayHandle);
    ws.bindings.c_xlib.Window[] result;
    ws.bindings.c_xlib.Window root_return, parent_return;
    ws.bindings.c_xlib.Window* children;
    uint count;
    XQueryTree(cast(Display*)wm.displayHandle, root, &root_return, &parent_return, &children, &count);
    if(children && root == root_return){
        result = children[0..count].dup;
        XFree(children);
    }
    return result;
}
