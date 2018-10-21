module common.queryTree;

import
	ws.wm,
	x11.Xlib;


x11.X.Window[] queryTree(){
	auto root = XDefaultRootWindow(wm.displayHandle);
    x11.X.Window[] result;
    x11.X.Window root_return, parent_return;
    x11.X.Window* children;
    uint count;
    XQueryTree(wm.displayHandle, root, &root_return, &parent_return, &children, &count);
    if(children && root == root_return){
        result = children[0..count].dup;
        XFree(children);
    }
    return result;
}
