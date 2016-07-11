module flatman.client;

import flatman;

__gshared:


enum BUTTONMASK = ButtonPressMask|ButtonReleaseMask;
enum MOUSEMASK = BUTTONMASK|PointerMotionMask;


class Client: Base {

	string name;
	float[2] aspectRange;
	int[2] posFloating;
	int[2] sizeFloating;
	int basew, baseh, incw, inch;
	int[2] sizeMin;
	int[2] sizeMax;
	int bw, oldbw;
	bool isUrgent;
	bool isFloating;
	bool global;
	bool isfixed, neverfocus, isfullscreen;
	flatman.Monitor monitor;
	Window win;
	Window orig;
	Frame frame;

	Pixmap mPixmap;
	ubyte[] icon;
	Icon xicon;
	long[2] iconSize;

	long ignoreUnmap;

	this(Window client, flatman.Monitor monitor){
		this.monitor = monitor;
		XSync(dpy, false);
		
		XWindowAttributes attr;
		XGetWindowAttributes(dpy, client, &attr);
		pos = [attr.x, attr.y];
		size = [attr.width, attr.height];
		posFloating = pos;
		sizeFloating = size;

		orig = client;
		win = client;
		
		Window trans = None;
		if(XGetTransientForHint(dpy, orig, &trans) && wintoclient(trans)){
			Client t = wintoclient(trans);
			monitor = t.monitor;
		}else{
			monitor = monitor;
			applyRules;
		}

		updateSizeHints;

		if(!isFloating)
			isFloating = trans != None || isfixed;

		updateType;
		updateWmHints;
		updateIcon;
		updateTitle;

		if(false){
			XSetWindowAttributes wa;
			wa.override_redirect = true;
			wa.background_pixmap = ParentRelative;
			wa.event_mask = 
				SubstructureRedirectMask|SubstructureNotifyMask|ButtonPressMask
				|PointerMotionMask|EnterWindowMask|StructureNotifyMask
				|PropertyChangeMask;
			win = XCreateWindow(
					dpy, .root, pos.x, pos.y, size.w, size.h,
					0, DefaultDepth(dpy, screen), CopyFromParent,
					DefaultVisual(dpy, screen),
					CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa
			);
			XReparentWindow(dpy, orig, win, 0, 0);
			XMapRaised(dpy, win);	
		}
	}

	override string toString(){
		return "(%s)".format(win);
	}

	void applyRules(){
		string _class, instance;
		uint i;
		const(Rule)* r;
		XClassHint ch = { null, null };
		/* rule matching */
		XGetClassHint(dpy, orig, &ch);
		_class    = to!string(ch.res_class ? ch.res_class : broken);
		instance = to!string(ch.res_name  ? ch.res_name  : broken);
		for(i = 0; i < rules.length; i++){
			r = &rules[i];
			if(
				(!r.title.length || name.canFind(r.title))
				&& (!r._class.length || _class.canFind(r._class))
				&& (!r.instance.length || instance.canFind(r.instance)))
			{
				isFloating = r.isFloating;
				Monitor m;
				//for(m = monitors; m && m.num != r.monitor; m = m.next){}
				//if(m)
				//	monitor = m;
			}
		}
		if(ch.res_class)
			XFree(ch.res_class);
		if(ch.res_name)
			XFree(ch.res_name);
	}
	
	void clearUrgent(){
		XWMHints* wmh = XGetWMHints(dpy, orig);
		isUrgent = false;
		if(!wmh)
			return;
		wmh.flags &= ~XUrgencyHint;
		XSetWMHints(dpy, orig, wmh);
		XFree(wmh);
	}
	
	void focus(){
		if(!monitor || !monitor.workspace)
			return;
		"%s focus".format(this).log;
		if(monitor.active && monitor.active != this)
			monitor.active.unfocus(false);
		if(isUrgent)
			clearUrgent;
		grabButtons(true);
		setFocus;
		monitor.setActive(this);
		redraw = true;
		previousFocus = this;
		restack;
	}
	
	void configure(){
		"%s configure %s %s".format(this, pos, size).log;
		XMoveResizeWindow(dpy, win, pos.x, pos.y, size.w, size.h);
		if(win != orig)
			XMoveResizeWindow(dpy, orig, 0, 0, size.w, size.h);
		configureNotify;
	}

	void configureNotify(){
		XConfigureEvent ce;
		ce.type = ConfigureNotify;
		ce.display = dpy;
		ce.event = orig;
		ce.window = orig;
		ce.x = pos.x;
		ce.y = pos.y;
		ce.width = size.w;
		ce.height = size.h;
		ce.above = None;
		ce.override_redirect = false;
		XSendEvent(dpy, orig, false, StructureNotifyMask, cast(XEvent*)&ce);
	}

	Atom[] getPropList(Atom prop){
		int di;
		ulong dl;
		ubyte* p;
		Atom da;
		Atom[] atom;
		ulong count;
		if(XGetWindowProperty(dpy, orig, prop, 0L, -1, false, XA_ATOM,
		                      &da, &di, &count, &dl, &p) == Success && p){
			atom = (cast(Atom*)p)[0..count].dup;
			XFree(p);
		}
		return atom;
	}
	
	Atom getatomprop(Atom prop){
		int di;
		ulong dl;
		ubyte* p;
		Atom da, atom = None;
		if(XGetWindowProperty(dpy, orig, prop, 0L, atom.sizeof, false, XA_ATOM,
		                      &da, &di, &dl, &dl, &p) == Success && p){
			atom = *cast(Atom*)p;
			XFree(p);
		}
		return atom;
	}

	long[4] getStrut(){
		int actualFormat;
		ulong bytes, items, count;
		ubyte* data;
		Atom actualType, atom;
		if(XGetWindowProperty(dpy, orig, net.strutPartial, 0, 12, false, XA_CARDINAL, &actualType, &actualFormat, &count, &bytes, &data) == Success && data){
			assert(actualType == XA_CARDINAL);
			assert(actualFormat == 32);
			assert(count == 12);
			auto array = (cast(CARDINAL*)data)[0..12];
			XFree(data);
			"found strut %s %s".format(name, array);
			if(array.any!"a < 0")
				return [0,0,0,0];
			return array[0..4];
		}
		return [0,0,0,0];

	}
	
	string getTitle(){
		Atom netWmName, utf8, actType;
		size_t nItems, bytes;
		int actFormat;
		ubyte* data;
		netWmName = XInternAtom(dpy, "_NET_WM_NAME".toStringz, False);
		utf8 = XInternAtom(dpy, "UTF8_STRING".toStringz, False);
		XGetWindowProperty(
				dpy, orig, netWmName, 0, 0x77777777, False, utf8,
				&actType, &actFormat, &nItems, &bytes, &data
		);
		auto text = to!string(cast(char*)data);
		XFree(data);
		if(!text.length){
			if(!gettextprop(orig, net.name, text))
				gettextprop(orig, XA_WM_NAME, text);
		}
		return text;
	}
	
	void grabButtons(bool focused){
		updatenumlockmask();
		uint i, j;
		uint[] modifiers = [ 0, LockMask, numlockmask, numlockmask|LockMask ];
		XUngrabButton(dpy, AnyButton, AnyModifier, orig);
		if(focused){
			for(i = 0; i < buttons.length; i++)
				for(j = 0; j < modifiers.length; j++)
					XGrabButton(dpy, .buttons[i].button,
					            .buttons[i].mask | modifiers[j],
					            orig, false, BUTTONMASK,
					            GrabModeAsync, GrabModeSync, None, None);
		}
		else
			XGrabButton(dpy, AnyButton, AnyModifier, orig, false,
			            BUTTONMASK, GrabModeAsync, GrabModeSync, None, None);
	}
	
	override void hide(){
		"%s hide".format(this).log;
		setState(WithdrawnState);
		hidden = true;
		ignoreUnmap += 1;
		XUnmapWindow(dpy, win);
		XSync(dpy, false);
	}

	auto isVisible(){
		return (monitor.workspace.clients.canFind(this) || monitor.globals.canFind(this));
	}

	void lower(){
		XLowerWindow(dpy, win);
	}

	void moveResize(int[2] pos, int[2] size, bool force = false){
		size.w = size.w.max(1).max(sizeMin.w).min(sizeMax.w);
		size.h = size.h.max(1).max(sizeMin.h).min(sizeMax.h);
		/+if(isFloating){
			pos.x = pos.x.max(0).min(monitor.size.w-size.w);
			pos.y = pos.y.max(0).min(monitor.size.h-size.h);
		}+/
		if(isFloating && !isfullscreen){
			posFloating = pos;
			sizeFloating = size;
		}
		if(this.pos == pos && this.size == size && !force)
			return;
		this.pos = pos;
		this.size = size;
		configure;
		if(frame){
			frame.moveResize(pos.a-[0,cfg.tabsTitleHeight], [size.w,cfg.tabsTitleHeight]);
		}
	}

	int originWorkspace(){
		string env;
		/+
		try {
			XSync(dpy, false);
			env = "/proc/%d/environ".format(orig.getprop!CARDINAL(net.pid)).readText;
			auto match = matchFirst(env, r"FLATMAN_WORKSPACE=([0-9]+)");
			"%s origin=%s".format(this, match).log;
			return match[1].to!int;
		}catch(Exception e)
			try
				"%s pid error: %s".format(this, orig.getprop!CARDINAL(net.pid)).log;
			catch
				"%s pid error".format(this).log;
		+/
		try
			return cast(int)orig.getprop!CARDINAL(net.windowDesktop);
		catch{}
		return monitor.workspaceActive;
	}

	void requestAttention(){
		if(this == monitor.active){
			isUrgent = false;
			return;
		}
		if(!isVisible && this != previousFocus){
			"%s requests attention".format(this).log;
			["notify-send", "%s requests attention".format(name)].spawnProcess;

		}
		isUrgent = true;
		redraw = true;
	}

	void raise(){
		XRaiseWindow(dpy, win);
	}

	void sendmon(flatman.Monitor m){
		if(monitor == m)
			return;
		unfocus(true);
		monitor.remove(this);
		monitor = m;
		monitor.add(this);
		focus();
	}
	
	bool sendEvent(Atom proto){
		int n;
		Atom *protocols;
		bool exists = false;
		XEvent ev;
		if(XGetWMProtocols(dpy, orig, &protocols, &n)){
			while(!exists && n--)
				exists = protocols[n] == proto;
			XFree(protocols);
		}
		if(exists){
			ev.type = ClientMessage;
			ev.xclient.window = orig;
			ev.xclient.message_type = wm.protocols;
			ev.xclient.format = 32;
			ev.xclient.data.l[0] = proto;
			ev.xclient.data.l[1] = CurrentTime;
			XSendEvent(dpy, orig, false, NoEventMask, &ev);
		}
		return exists;
	}
	
	void setFocus(){
		if(!neverfocus){
			XSetInputFocus(dpy, orig, RevertToPointerRoot, CurrentTime);
			XChangeProperty(dpy, .root, net.windowActive,
	 		                XA_WINDOW, 32, PropModeReplace,
	 		                cast(ubyte*) &(orig), 1);
		}
		sendEvent(wm.takeFocus);
	}
	
	void setFullscreen(bool fullscreen){
		"%s fullscreen=%s".format(this, fullscreen).log;
		isfullscreen = fullscreen;
		auto proplist = getPropList(net.state);
		if(fullscreen){
			if(!proplist.canFind(net.fullscreen))
				append(win, net.state, [net.fullscreen]);
		}else{
			if(proplist.canFind(net.fullscreen))
				replace(win, net.state, proplist.without(net.fullscreen));
		}
		if(isFloating){
			monitor.remove(this);
			monitor.add(this, monitor.workspaceActive);
		}
		focus;
	}
	
	void setState(long state){
		long[] data = [ state, None ];
		XChangeProperty(dpy, orig, wm.state, wm.state, 32, PropModeReplace, cast(ubyte*)data, 2);
	}

	void setWorkspace(long i){
		if(i >= 0 && i < monitor.workspaces.length && monitor.workspaces[i].clients.canFind(this))
			return;
		"%s set workspace %s".format(this, i).log;
		monitor.remove(this);
		monitor.add(this, i < 0 ? monitor.workspaces.length-1 : i);
		updateWindowDesktop(this, i);
		"set workspace done".log;
	}

	override void show(){
		"%s show".format(this).log;
		setState(NormalState);
		XMapWindow(dpy, win);
		if(win != orig)
			XMapWindow(dpy, orig);
		XSync(dpy, false);
	}

	void togglefloating(){
		if(isfullscreen)
			setFullscreen(false);
		else {
			isFloating = !isFloating;
			"%s floating=%s".format(this, isFloating).log;
			monitor.remove(this);
			monitor.add(this, monitor.workspaceActive);
			focus;
		}
	}
	
	void unfocus(bool setfocus){
		"%s unfocus".format(this).log;
		grabButtons(false);
		if(setfocus){
			XSetInputFocus(dpy, .root, RevertToPointerRoot, CurrentTime);
			XDeleteProperty(dpy, .root, net.windowActive);
		}
		if(isfullscreen && !isFloating){
			hide;
		}
	}
	
	void unmanage(bool force=false){
		if(force){
			monitor.remove(this);
			if(win != orig)
				XDestroyWindow(dpy, win);
		}
		else{
			XWindowChanges wc;
			wc.border_width = oldbw;
			XGrabServer(dpy);
			XSetErrorHandler(&xerrordummy);
			XUngrabButton(dpy, AnyButton, AnyModifier, orig);
			setState(WithdrawnState);
			XSync(dpy, false);
			XSetErrorHandler(&xerror);
			XUngrabServer(dpy);
		}
		if(previousFocus && previousFocus != this)
			previousFocus.focus;
		updateClientList();
	}
	
	void updateStrut(){
		try
			monitor.strut(this, getPropList(net.strutPartial).length>0);
		catch(Exception e)
			e.toString.log;
	}


	void updateType(){
		Atom[] state = this.getPropList(net.state);
		if(state.canFind(net.fullscreen) || size == monitor.size)
			isfullscreen = true;
		if(state.canFind(net.modal))
			isFloating = true;
		Atom[] type = getPropList(net.windowType);
		if(type.canFind(net.windowTypeDialog) || type.canFind(net.windowTypeSplash))
			isFloating = true;
		if(type.canFind(net.windowTypeDock))
			global = true;
	}

	void updateSizeHints(){
		long msize;
		XSizeHints size;
		if(!XGetWMNormalHints(dpy, orig, &size, &msize))
			/* size is uninitialized, ensure that size.flags aren't used */
			size.flags = PSize;
		if(size.flags & PBaseSize){
			basew = size.base_width;
			baseh = size.base_height;
		}else if(size.flags & PMinSize){
			basew = size.min_width;
			baseh = size.min_height;
		}else
			basew = baseh = 0;
			
		if(size.flags & PResizeInc){
			incw = size.width_inc;
			inch = size.height_inc;
		}else
			incw = inch = 0;
		if(size.flags & PMaxSize){
			sizeMax.w = size.max_width;
			sizeMax.h = size.max_height;
		}else
			sizeMax.w = sizeMax.h = int.max;
			
		if(size.flags & PMinSize){
			sizeMin.w = size.min_width;
			sizeMin.h = size.min_height;
		}else if(size.flags & PBaseSize){
			sizeMin.w = size.base_width;
			sizeMin.h = size.base_height;
		}else
			sizeMin.w = sizeMin.h = 0;
			
		if(size.flags & PAspect){
			aspectRange = [
				cast(float)size.min_aspect.y / size.min_aspect.x,
				cast(float)size.max_aspect.x / size.max_aspect.y
			];
		}else
			aspectRange = [0,0];
			
		if(sizeMin.w > int.max || sizeMin.w < 0)
			sizeMin.w = 0;
		if(sizeMin.h > int.max || sizeMin.h < 0)
			sizeMin.h = 0;
			
		if(sizeMax.w > int.max || sizeMax.w < 0)
			sizeMax.w = int.max;
		if(sizeMax.h > int.max || sizeMax.h < 0)
			sizeMax.h = int.max;

		isfixed = (sizeMax.w && sizeMin.w && sizeMax.h && sizeMin.h && sizeMax.w == sizeMin.w && sizeMax.h == sizeMin.h);
		"%s sizeMin=%s sizeMax=%s".format(this, sizeMin, sizeMax).log;
	}

	void updateWmHints(){
		XWMHints* wmh = XGetWMHints(dpy, orig);
		if(wmh){
			if(this == flatman.monitor.active && wmh.flags & XUrgencyHint){
				wmh.flags &= ~XUrgencyHint;
				XSetWMHints(dpy, orig, wmh);
			}else{
				if(wmh.flags & XUrgencyHint){
					requestAttention;
				}
			}
			if(wmh.flags & InputHint)
				neverfocus = !wmh.input;
			else
				neverfocus = false;
			XFree(wmh);
		}
	}

	void updateIcon(){
		int format;
		ubyte* p = null;
		ulong count, extra;
		Atom type;
		if(XGetWindowProperty(dpy, orig, net.icon, 0, long.max, false, AnyPropertyType,
		                      &type, &format, &count, &extra, cast(ubyte**)&p) != 0)
			return;
		if(xicon)
			xicon.destroy(dpy);
		xicon = null;
		if(p){
			long* data = cast(long*)p;
			long start = 0;
			long width = data[0];
			long height = data[1];
			for(int i=0; i<count;){
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
		XFree(p);
	}

	void updateWorkspace(){
		int ws = originWorkspace;
		setWorkspace(ws);
	}

	void updateTitle(){
		name = getTitle;
		"%s title='%s'".format(this, name).log;
	}
	
};


template AtomType(int Format){

	static if(Format == XA_CARDINAL || Format == XA_PIXMAP)
		alias AtomType = long;
	static if(Format == XA_ATOM)
		alias AtomType = Atom;
	static if(Format == XA_WINDOW)
		alias AtomType = x11.X.Window;
	static if(Format == XA_STRING)
		alias AtomType = string;

}


auto getprop(int T)(Window window, Atom atom){
	auto raw = _rawget(window, atom, T);
	auto data = *(cast(AtomType!T*)raw);
	XFree(raw);
	return data;
}

CARDINAL getprop(T: CARDINAL)(Window window, Atom atom){
	auto p = _rawget(window, atom, XA_CARDINAL);
	auto d = *(cast(CARDINAL*)p);
	XFree(p);
	return d;
}


ubyte* _rawget(Window window, Atom atom, int type, ulong count=1){
	int di;
	ulong dl;
	ubyte* p;
	Atom da;
	if(XGetWindowProperty(dpy, window, atom, 0L, count, false, type,
	                      &da, &di, &count, &dl, &p) == Success && p){
		return p;
	}
	throw new Exception("no data");
}

