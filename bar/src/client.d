module bar.client;

import bar;


import common.xevents, common.log;


class Client {

	x11.X.Window window;	

	int screen;

	Property!(XA_CARDINAL, false) workspace;
	Property!(XA_CARDINAL, false) flatmanTab;
	Property!(XA_CARDINAL, false) flatmanTabs;
	Property!(XA_ATOM, true) state;

	string title;

	Icon xicon;
	long[2] iconSize;
	ubyte[] icon;
	bool hidden;

	PropertyList properties;

	this(x11.X.Window window){
		this.window = window;
		properties = new PropertyList;
		workspace = new Property!(XA_CARDINAL, false)(window, "_NET_WM_DESKTOP", properties);
		flatmanTab = new Property!(XA_CARDINAL, false)(window, "_FLATMAN_TAB", properties);
		flatmanTabs = new Property!(XA_CARDINAL, false)(window, "_FLATMAN_TABS", properties);
		state = new Property!(XA_ATOM, true)(window, "_NET_WM_STATE", properties);

		properties.update;

		updateIcon(window.props._NET_WM_ICON.get!(long[]));
		title = window.getTitle;

		Events[window] ~= this;

		XSelectInput(wm.displayHandle, window, StructureNotifyMask | PropertyChangeMask);
	}

	~this(){
		Log("DestroyWindow " ~ window.to!string);
		Events.forget(this);
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
    
	void updateIcon(long[] data){
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
		icon.length = (start+width*height+2 - (start+2))*4;
		foreach(i, argb; data[start+2..start+width*height+2]){
			auto alpha = (argb >> 24 & 0xff)/255.0;
			icon[i*4+0] = cast(ubyte)((argb & 0xff)*alpha);
			icon[i*4+1] = cast(ubyte)((argb >> 8 & 0xff)*alpha);
			icon[i*4+2] = cast(ubyte)((argb >> 16 & 0xff)*alpha);
			icon[i*4+3] = cast(ubyte)((argb >> 24 & 0xff));
		}
		iconSize = [width,height];

	}

	override string toString(){
		return "%s:%s".format(window, title);
	}

	@WindowMap
	void onMap(){
		hidden = false;
	}

	@WindowUnmap
	void onUnmap(){
		hidden = true;
	}

	@WindowProperty
	void onProperty(XPropertyEvent* e){
		if(e.atom == Atoms._NET_WM_ICON){
			updateIcon(window.props._NET_WM_ICON.get!(long[]));
		}else if([Atoms._NET_WM_NAME, Atoms.WM_NAME].canFind(e.atom)){
			title = window.getTitle;
		}
		properties.update(e);
	}

}
