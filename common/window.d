module common.window;


import common.atoms;


import
	std.conv,
	std.string,
	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.Xproto,
	x11.Xatom,
	ws.wm;


bool gettextprop(x11.X.Window w, Atom atom, ref string text){
	char** list;
	int n;
	XTextProperty name;
	XGetTextProperty(wm.displayHandle, w, &name, atom);
	if(!name.nitems)
		return false;
	if(name.encoding == XA_STRING){
		text = to!string(*name.value);
	}else{
		if(XmbTextPropertyToTextList(wm.displayHandle, &name, &list, &n) >= XErrorCode.Success && n > 0 && *list){
			text = (*list).to!string;
			XFreeStringList(list);
		}
	}
	XFree(name.value);
	return true;
}


string getTitle(x11.X.Window window){
	Atom utf8, actType;
	size_t nItems, bytes;
	int actFormat;
	ubyte* data;
	utf8 = XInternAtom(wm.displayHandle, "UTF8_STRING".toStringz, False);
	XGetWindowProperty(
			wm.displayHandle, window, Atoms._NET_WM_NAME, 0, 0x77777777, False, utf8,
			&actType, &actFormat, &nItems, &bytes, &data
	);
	auto text = to!string(cast(char*)data);
	XFree(data);
	if(!text.length){
		if(!gettextprop(window, Atoms._NET_WM_NAME, text))
			gettextprop(window, XA_WM_NAME, text);
	}
	return text;
}
