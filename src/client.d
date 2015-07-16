module flatman.client;

import
	flatman;


ref T x(T,int N)(ref T[N] array){
	return array[0];
}
alias w = x;

ref T y(T,int N)(ref T[N] array){
	return array[1];
}
alias h = y;


enum BUTTONMASK = ButtonPressMask|ButtonReleaseMask;
enum MOUSEMASK = BUTTONMASK|PointerMotionMask;


class Client {

	string name;
	float mina, maxa;
	int[2] pos;
	int[2] size;
	int[2] posOld;
	int[2] sizeOld;
	int basew, baseh, incw, inch, maxw, maxh, minw, minh;
	int bw, oldbw;
	bool isUrgent;
	bool isFloating;
	bool isfixed, neverfocus, oldstate, isfullscreen;
	flatman.Monitor monitor;
	Window win;

	Pixmap mPixmap;
	Picture mPicture;
	XRenderPictFormat* format;

	this(Window win){
		this.win = win;
		XWindowAttributes attr;
		XGetWindowAttributes(dpy, win, &attr);
		format = XRenderFindVisualFormat(dpy, attr.visual);
		pos = [attr.x, attr.y];
		size = [attr.width, attr.height];
		updateType;
		updateSizeHints;
		updateWmHints;
		//XShapeSelectInput(dpy, win, ShapeNotifyMask);
	}

	void resize(int[2] pos, int[2] size, bool interact){
		resizeclient(pos, size);
	}

	void resizeclient(int[2] pos, int[2] size){
		pos.x = pos.x.max(0);
		pos.y = pos.y.max(0);
		size.w = size.w.max(1);
		size.h = size.h.max(1);
		XWindowChanges wc;
		posOld = this.pos;
		sizeOld = this.size;
		this.pos = pos;
		this.size = size;
		wc.x = pos.x;
		wc.y = pos.y;
		wc.width = size.w;
		wc.height = size.h;
		wc.border_width = bw;
		XConfigureWindow(dpy, win, CWX|CWY|CWWidth|CWHeight|CWBorderWidth, &wc);
		configure;
		XSync(dpy, false);
	}

	void setState(long state){
		long[] data = [ state, None ];
		XChangeProperty(dpy, win, wm.state, wm.state, 32, PropModeReplace, cast(ubyte*)data, 2);
	}

	auto isVisible(){
		return monitorActive.workspace.clients.canFind(this);
	}

	void configure(){
		XConfigureEvent ce;
		ce.type = ConfigureNotify;
		ce.display = dpy;
		ce.event = win;
		ce.window = win;
		ce.x = pos.x;
		ce.y = pos.y;
		ce.width = size.w;
		ce.height = size.h;
		//ce.border_width = c.bw;
		ce.above = None;
		ce.override_redirect = false;
		XSendEvent(dpy, win, false, StructureNotifyMask, cast(XEvent*)&ce);
	}

	void updateType(){
		Atom state = getatomprop(this, net.wmState);
		Atom wtype = getatomprop(this, net.wmWindowType);
		if(state == net.wmFullscreen)
			setfullscreen(this, true);
		if(wtype == net.wmWindowTypeDialog)
			isFloating = true;
	}

	void updateSizeHints(){
		long msize;
		XSizeHints size;
		if(!XGetWMNormalHints(dpy, win, &size, &msize))
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
			maxw = size.max_width;
			maxh = size.max_height;
		}else
			maxw = maxh = 0;
		if(size.flags & PMinSize){
			minw = size.min_width;
			minh = size.min_height;
		}else if(size.flags & PBaseSize){
			minw = size.base_width;
			minh = size.base_height;
		}else
			minw = minh = 0;
		if(size.flags & PAspect){
			mina = cast(float)size.min_aspect.y / size.min_aspect.x;
			maxa = cast(float)size.max_aspect.x / size.max_aspect.y;
		}else
			maxa = mina = 0.0;
		isfixed = (maxw && minw && maxh && minh && maxw == minw && maxh == minh);
	}

	void updateWmHints(){
		XWMHints* wmh = XGetWMHints(dpy, win);
		if(wmh){
			if(this == monitorActive.active && wmh.flags & XUrgencyHint){
				wmh.flags &= ~XUrgencyHint;
				XSetWMHints(dpy, win, wmh);
			}else
				isUrgent = (wmh.flags & XUrgencyHint) ? true : false;
			if(wmh.flags & InputHint)
				neverfocus = !wmh.input;
			else
				neverfocus = false;
			XFree(wmh);
		}
	}

	Picture picture(){
		if(!mPicture){
			// Increase the ref count for the backing pixmap
			if(!mPixmap)
				mPixmap = XCompositeNameWindowPixmap(dpy, win);
			// Create the window picture
			mPicture = XRenderCreatePicture(dpy, mPixmap, format, 0, null);
		}
		// ### There's room for optimization here. The window picture only needs a clip region when it's translucent. For opaque windows it doesn't matter since we're drawing them top -> bottom.
		/+
		if(!mSourceClipValid){
			XserverRegion clip = XFixesCreateRegionFromWindow( dpy, winId(), WindowRegionBounding );
			XFixesSetPictureClipRegion( dpy, mPicture, 0, 0, clip );
			XFixesDestroyRegion( dpy, clip );
			mSourceClipValid = true;
		}
		+/
		return mPicture;
	}

};

void sendmon(Client c, Monitor m){
	if(c.monitor == m)
		return;
	unfocus(c, true);
	c.monitor.remove(c);
	c.monitor = m;
	c.monitor.add(c);
	focus(null);
}

bool sendevent(Client c, Atom proto){
	int n;
	Atom *protocols;
	bool exists = false;
	XEvent ev;
	if(XGetWMProtocols(dpy, c.win, &protocols, &n)){
		while(!exists && n--)
			exists = protocols[n] == proto;
		XFree(protocols);
	}
	if(exists){
		ev.type = ClientMessage;
		ev.xclient.window = c.win;
		ev.xclient.message_type = wm.protocols;
		ev.xclient.format = 32;
		ev.xclient.data.l[0] = proto;
		ev.xclient.data.l[1] = CurrentTime;
		XSendEvent(dpy, c.win, false, NoEventMask, &ev);
	}
	return exists;
}

void setfocus(Client c){
	if(!c.neverfocus){
		XSetInputFocus(dpy, c.win, RevertToPointerRoot, CurrentTime);
		XChangeProperty(dpy, root, net.activeWindow,
 		                XA_WINDOW, 32, PropModeReplace,
 		                cast(ubyte*) &(c.win), 1);
	}
	sendevent(c, wm.takeFocus);
}

void setfullscreen(Client c, bool fullscreen){
	if(fullscreen){
		XChangeProperty(dpy, c.win, net.wmState, XA_ATOM, 32,
		                PropModeReplace, cast(ubyte*)&net.wmFullscreen, 1);
		c.isfullscreen = true;
		c.oldbw = c.bw;
		c.bw = 0;
		c.resizeclient(c.monitor.pos, c.monitor.size);
		XRaiseWindow(dpy, c.win);
	}
	else {
		XChangeProperty(dpy, c.win, net.wmState, XA_ATOM, 32, PropModeReplace, null, 0);
		c.isfullscreen = false;
		c.bw = c.oldbw;
		c.pos = c.posOld;
		c.size = c.sizeOld;
		c.resizeclient(c.pos, c.size);
	}
}

void unfocus(Client c, bool setfocus){
	if(!c)
		return;
	grabbuttons(c, false);
	if(setfocus){
		XSetInputFocus(dpy, root, RevertToPointerRoot, CurrentTime);
		XDeleteProperty(dpy, root, net.activeWindow);
	}
}

void unmanage(Client c, bool destroyed){
	Monitor m = c.monitor;
	"unmanage %s %s".format(c.name, destroyed).log;
	if(destroyed)
		m.remove(c);
	XWindowChanges wc;
	/* The server grab construct avoids race conditions. */
	if(!destroyed){
		wc.border_width = c.oldbw;
		XGrabServer(dpy);
		XSetErrorHandler(&xerrordummy);
		XConfigureWindow(dpy, c.win, CWBorderWidth, &wc); /* restore border */
		XUngrabButton(dpy, AnyButton, AnyModifier, c.win);
		c.setState(WithdrawnState);
		XSync(dpy, false);
		XSetErrorHandler(&xerror);
		XUngrabServer(dpy);
	}
	focus(null);
	updateclientlist();
}

void updatetitle(Client c){
	if(!gettextprop(c.win, net.wmName, c.name))
		gettextprop(c.win, XA_WM_NAME, c.name);
	if(!c.name.length)
		c.name = broken;
}

void applyRules(Client c){
	string _class, instance;
	uint i;
	const(Rule)* r;
	XClassHint ch = { null, null };
	/* rule matching */
	c.isFloating = 0;
	XGetClassHint(dpy, c.win, &ch);
	_class    = to!string(ch.res_class ? ch.res_class : broken);
	instance = to!string(ch.res_name  ? ch.res_name  : broken);
	for(i = 0; i < rules.length; i++){
		r = &rules[i];
		if(
			(!r.title.length || c.name.canFind(r.title))
			&& (!r._class.length || _class.canFind(r._class))
			&& (!r.instance.length || instance.canFind(r.instance)))
		{
			c.isFloating = r.isFloating;
			Monitor m;
			//for(m = monitors; m && m.num != r.monitor; m = m.next){}
			//if(m)
			//	c.monitor = m;
		}
	}
	if(ch.res_class)
		XFree(ch.res_class);
	if(ch.res_name)
		XFree(ch.res_name);
}

void clearurgent(Client c){
	XWMHints* wmh = XGetWMHints(dpy, c.win);
	c.isUrgent = false;
	if(!wmh)
		return;
	wmh.flags &= ~XUrgencyHint;
	XSetWMHints(dpy, c.win, wmh);
	XFree(wmh);
}

void focus(Client c){
	if(!c || !c.isVisible)
		return;
	if(monitorActive.active && monitorActive.active != c)
		unfocus(monitorActive.active, false);
	if(c){
		if(c.monitor != monitorActive)
			monitorActive = c.monitor;
		if(c.isUrgent)
			clearurgent(c);
		grabbuttons(c, true);
		setfocus(c);
	}else{
		XSetInputFocus(dpy, root, RevertToPointerRoot, CurrentTime);
		XDeleteProperty(dpy, root, net.activeWindow);
	}
	foreach(si, ws; monitorActive.workspaces){
		foreach(wi, w; ws.clients){
			if(w == c){
				monitorActive.workspaceActive = cast(int)si;
				ws.setFocus(w);
			}
		}
	}
	foreach(m; monitors)
		m.draw;
}

Atom getatomprop(Client c, Atom prop){
	int di;
	ulong dl;
	ubyte* p;
	Atom da, atom = None;
	if(XGetWindowProperty(dpy, c.win, prop, 0L, atom.sizeof, false, XA_ATOM,
	                      &da, &di, &dl, &dl, &p) == Success && p){
		atom = *cast(Atom*)p;
		XFree(p);
	}
	return atom;
}

void grabbuttons(Client c, bool focused){
	updatenumlockmask();
	uint i, j;
	uint[] modifiers = [ 0, LockMask, numlockmask, numlockmask|LockMask ];
	XUngrabButton(dpy, AnyButton, AnyModifier, c.win);
	if(focused){
		for(i = 0; i < buttons.length; i++)
			for(j = 0; j < modifiers.length; j++)
				XGrabButton(dpy, buttons[i].button,
				            buttons[i].mask | modifiers[j],
				            c.win, false, BUTTONMASK,
				            GrabModeAsync, GrabModeSync, None, None);
	}
	else
		XGrabButton(dpy, AnyButton, AnyModifier, c.win, false,
		            BUTTONMASK, GrabModeAsync, GrabModeSync, None, None);
}
