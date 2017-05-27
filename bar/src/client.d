module bar.client;

import bar;


bool gettextprop(x11.X.Window w, Atom atom, ref string text){
	char** list;
	int n;
	XTextProperty name;
	XGetTextProperty(dpy, w, &name, atom);
	if(!name.nitems)
		return false;
	if(name.encoding == XA_STRING){
		text = to!string(*name.value);
	}else{
		if(XmbTextPropertyToTextList(dpy, &name, &list, &n) >= XErrorCode.Success && n > 0 && *list){
			text = (*list).to!string;
			XFreeStringList(list);
		}
	}
	XFree(name.value);
	return true;
}


class Client {

	x11.X.Window window;	

	int screen;

	Property!(XA_CARDINAL, false) workspace;
	Property!(XA_CARDINAL, false) flatmanTab;
	Property!(XA_CARDINAL, false) flatmanTabs;
	Property!(XA_CARDINAL, true) iconProperty;
	Property!(XA_STRING, false) titleProperty;

	string title;

	Icon xicon;
	long[2] iconSize;
	ubyte[] icon;
	bool hidden;

	this(x11.X.Window window){
		this.window = window;
		title = getTitle;
		workspace = new Property!(XA_CARDINAL, false)(window, "_NET_WM_DESKTOP", properties);
		flatmanTab = new Property!(XA_CARDINAL, false)(window, "_FLATMAN_TAB", properties);
		flatmanTabs = new Property!(XA_CARDINAL, false)(window, "_FLATMAN_TABS", properties);
		iconProperty = new Property!(XA_CARDINAL, true)(window, "_NET_WM_ICON", properties);
		titleProperty = new Property!(XA_STRING, false)(window, "_NET_WM_NAME", properties);
		titleProperty ~= (string t){
			title = t;
		};
		iconProperty ~= &updateIcon;
		iconProperty.update;

		//updateIcon;

		XSelectInput(wm.displayHandle, window, StructureNotifyMask | PropertyChangeMask);
	}

	void requestClose(){
		XEvent ev;
		ev.type = ClientMessage;
		ev.xclient.window = window;
		ev.xclient.message_type = Atoms.WM_PROTOCOLS;
		ev.xclient.format = 32;
		ev.xclient.data.l[0] = Atoms.WM_DELETE_WINDOW;
		ev.xclient.data.l[1] = CurrentTime;
		XSendEvent(wm.displayHandle, window, false, NoEventMask, &ev);
	}
    
	string getTitle(){
		Atom actType;
		size_t nItems, bytes;
		int actFormat;
		ubyte* data;
		XGetWindowProperty(
				dpy, window, Atoms._NET_WM_NAME, 0, 0x77777777, False, Atoms.UTF8_STRING,
				&actType, &actFormat, &nItems, &bytes, &data
		);
		auto text = to!string(cast(char*)data);
		XFree(data);
		if(!text.length){
			if(!gettextprop(window, Atoms.NET_NAME, text))
				gettextprop(window, XA_WM_NAME, text);
		}
		return text;
	}
	
	void updateIcon(long[] data){
		if(xicon)
			xicon.destroy(dpy);
		xicon = null;
		if(!data.length)
			return;
		long start = 0;
		long width = data[0];
		long height = data[1];
		for(int i=0; i<data.length;){
			if(data[i]*data[i+1] > width*height){
				start = i;
				width = data[i];
				height = data[i+1];
			}
			i += data[i]*data[i+1]+2;
		}
		icon = [];
		foreach(argb; data[start+2..start+width*height+2]){
			auto alpha = (argb >> 24 & 0xff)/255.0;
			icon ~= [
				cast(ubyte)((argb & 0xff)*alpha),
				cast(ubyte)((argb >> 8 & 0xff)*alpha),
				cast(ubyte)((argb >> 16 & 0xff)*alpha),
				cast(ubyte)((argb >> 24 & 0xff))
			];
		}
		iconSize = [width,height];

	}

}
