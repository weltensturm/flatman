module dwm.client;

import
	dwm;


enum BUTTONMASK = ButtonPressMask|ButtonReleaseMask;
enum MOUSEMASK = BUTTONMASK|PointerMotionMask;


class Client {

	string name;
	float mina, maxa;
	int x, y, w, h;
	int oldx, oldy, oldw, oldh;
	int basew, baseh, incw, inch, maxw, maxh, minw, minh;
	int bw, oldbw;
	uint tags;
	bool isfixed, isfloating, isurgent, neverfocus, oldstate, isfullscreen;
	Client next;
	Client snext;
	dwm.Monitor* monitor;
	Window win;

	void resize(int x, int y, int w, int h, bool interact){
		if(applysizehints(&x, &y, &w, &h, interact))
			resizeclient(x, y, w, h);
	}

	void resizeclient(int x, int y, int w, int h){
		XWindowChanges wc;
		oldx = x; this.x = wc.x = x;
		oldy = y; this.y = wc.y = y;
		oldw = w; this.w = wc.width = w;
		oldh = h; this.h = wc.height = h;
		wc.border_width = bw;
		XConfigureWindow(dpy, win, CWX|CWY|CWWidth|CWHeight|CWBorderWidth, &wc);
		configure(this);
		XSync(dpy, false);
	}

	bool applysizehints(int* x, int* y, int* w, int* h, bool interact){
		bool baseismin;
		dwm.Monitor* m = monitor;
		/* set minimum possible */
		*w = max(1, *w);
		*h = max(1, *h);
		if(interact){
			if(*x > sw)
				*x = sw - width(this);
			if(*y > sh)
				*y = sh - height(this);
			if(*x + *w + 2 * bw < 0)
				*x = 0;
			if(*y + *h + 2 * bw < 0)
				*y = 0;
		}else{
			if(*x >= m.wx + m.ww)
				*x = m.wx + m.ww - width(this);
			if(*y >= m.wy + m.wh)
				*y = m.wy + m.wh - height(this);
			if(*x + *w + 2 * bw <= m.wx)
				*x = m.wx;
			if(*y + *h + 2 * bw <= m.wy)
				*y = m.wy;
		}
		if(*h < bh)
			*h = bh;
		if(*w < bh)
			*w = bh;
		if(resizehints || isfloating || !monitor.lt[monitor.sellt].arrange){
			/* see last two sentences in ICCCM 4.1.2.3 */
			baseismin = basew == minw && baseh == minh;
			if(!baseismin){ /* temporarily remove base dimensions */
				*w -= basew;
				*h -= baseh;
			}
			/* adjust for aspect limits */
			if(mina > 0 && maxa > 0){
				if(maxa < cast(float)*w / *h)
					*w = cast(int)(*h * maxa + 0.5);
				else if(mina < cast(float)*h / *w)
					*h = cast(int)(*w * mina + 0.5);
			}
			if(baseismin){ /* increment calculation requires this */
				*w -= basew;
				*h -= baseh;
			}
			/* adjust for increment value */
			if(incw)
				*w -= *w % incw;
			if(inch)
				*h -= *h % inch;
			/* restore base dimensions */
			*w = max(*w + basew, minw);
			*h = max(*h + baseh, minh);
			if(maxw)
				*w = min(*w, maxw);
			if(maxh)
				*h = min(*h, maxh);
		}
		return *x != this.x || *y != this.y || *w != this.w || *h != this.h;
	}

};

void sendmon(Client c, Monitor *m){
	if(c.monitor == m)
		return;
	unfocus(c, true);
	detach(c);
	detachstack(c);
	c.monitor = m;
	c.tags = m.tagset[m.seltags]; /* assign tags of target monitor */
	attach(c);
	attachstack(c);
	focus(null);
	arrange(null);
}

void setclientstate(Client c, long state){
	long[] data = [ state, None ];

	XChangeProperty(dpy, c.win, wmatom[WMState], wmatom[WMState], 32,
			PropModeReplace, cast(ubyte*)data, 2);
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
		ev.xclient.message_type = wmatom[WMProtocols];
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
		XChangeProperty(dpy, root, netatom[NetActiveWindow],
 		                XA_WINDOW, 32, PropModeReplace,
 		                cast(ubyte*) &(c.win), 1);
	}
	sendevent(c, wmatom[WMTakeFocus]);
}

void setfullscreen(Client c, bool fullscreen){
	if(fullscreen){
		XChangeProperty(dpy, c.win, netatom[NetWMState], XA_ATOM, 32,
		                PropModeReplace, cast(ubyte*)&netatom[NetWMFullscreen], 1);
		c.isfullscreen = true;
		c.oldstate = c.isfloating;
		c.oldbw = c.bw;
		c.bw = 0;
		c.isfloating = true;
		c.resizeclient(c.monitor.mx, c.monitor.my, c.monitor.mw, c.monitor.mh);
		XRaiseWindow(dpy, c.win);
	}
	else {
		XChangeProperty(dpy, c.win, netatom[NetWMState], XA_ATOM, 32,
		                PropModeReplace, null, 0);
		c.isfullscreen = false;
		c.isfloating = c.oldstate;
		c.bw = c.oldbw;
		c.x = c.oldx;
		c.y = c.oldy;
		c.w = c.oldw;
		c.h = c.oldh;
		c.resizeclient(c.x, c.y, c.w, c.h);
		arrange(c.monitor);
	}
}

void showhide(Client c){
	if(!c)
		return;
	if(isVisible(c)){ /* show clients top down */
		XMoveWindow(dpy, c.win, c.x, c.y);
		if((!c.monitor.lt[c.monitor.sellt].arrange || c.isfloating) && !c.isfullscreen)
			c.resize(c.x, c.y, c.w, c.h, false);
		showhide(c.snext);
	}
	else { /* hide clients bottom up */
		showhide(c.snext);
		XMoveWindow(dpy, c.win, width(c) * -2, c.y);
	}
}

Client nexttiled(Client c){
	for(; c && (c.isfloating || !isVisible(c)); c = c.next){}
	return c;
}

void pop(Client c){
	detach(c);
	attach(c);
	focus(c);
	arrange(c.monitor);
}

void unfocus(Client c, bool setfocus){
	if(!c)
		return;
	grabbuttons(c, false);
	XSetWindowBorder(dpy, c.win, scheme[SchemeNorm].border.pix);
	if(setfocus){
		XSetInputFocus(dpy, root, RevertToPointerRoot, CurrentTime);
		XDeleteProperty(dpy, root, netatom[NetActiveWindow]);
	}
}

void unmanage(Client c, bool destroyed){
	Monitor *m = c.monitor;
	XWindowChanges wc;

	/* The server grab construct avoids race conditions. */
	detach(c);
	detachstack(c);
	if(!destroyed){
		wc.border_width = c.oldbw;
		XGrabServer(dpy);
		XSetErrorHandler(&xerrordummy);
		XConfigureWindow(dpy, c.win, CWBorderWidth, &wc); /* restore border */
		XUngrabButton(dpy, AnyButton, AnyModifier, c.win);
		setclientstate(c, WithdrawnState);
		XSync(dpy, false);
		XSetErrorHandler(&xerror);
		XUngrabServer(dpy);
	}
	focus(null);
	updateclientlist();
	arrange(m);
}

void updatesizehints(Client c){
	long msize;
	XSizeHints size;

	if(!XGetWMNormalHints(dpy, c.win, &size, &msize))
		/* size is uninitialized, ensure that size.flags aren't used */
		size.flags = PSize;
	if(size.flags & PBaseSize){
		c.basew = size.base_width;
		c.baseh = size.base_height;
	}
	else if(size.flags & PMinSize){
		c.basew = size.min_width;
		c.baseh = size.min_height;
	}
	else
		c.basew = c.baseh = 0;
	if(size.flags & PResizeInc){
		c.incw = size.width_inc;
		c.inch = size.height_inc;
	}
	else
		c.incw = c.inch = 0;
	if(size.flags & PMaxSize){
		c.maxw = size.max_width;
		c.maxh = size.max_height;
	}
	else
		c.maxw = c.maxh = 0;
	if(size.flags & PMinSize){
		c.minw = size.min_width;
		c.minh = size.min_height;
	}
	else if(size.flags & PBaseSize){
		c.minw = size.base_width;
		c.minh = size.base_height;
	}
	else
		c.minw = c.minh = 0;
	if(size.flags & PAspect){
		c.mina = cast(float)size.min_aspect.y / size.min_aspect.x;
		c.maxa = cast(float)size.max_aspect.x / size.max_aspect.y;
	}
	else
		c.maxa = c.mina = 0.0;
	c.isfixed = (c.maxw && c.minw && c.maxh && c.minh
	             && c.maxw == c.minw && c.maxh == c.minh);
}

void updatetitle(Client c){
	if(!gettextprop(c.win, netatom[NetWMName], c.name, c.name.sizeof))
		gettextprop(c.win, XA_WM_NAME, c.name, c.name.sizeof);
	if(c.name.length)
		c.name = broken;
}

void updatewindowtype(Client c){
	Atom state = getatomprop(c, netatom[NetWMState]);
	Atom wtype = getatomprop(c, netatom[NetWMWindowType]);

	if(state == netatom[NetWMFullscreen])
		setfullscreen(c, true);
	if(wtype == netatom[NetWMWindowTypeDialog])
		c.isfloating = true;
}

void updatewmhints(Client c){
	XWMHints* wmh = XGetWMHints(dpy, c.win);
	if(wmh){
		if(c == monitorActive.clientActive && wmh.flags & XUrgencyHint){
			wmh.flags &= ~XUrgencyHint;
			XSetWMHints(dpy, c.win, wmh);
		}
		else
			c.isurgent = (wmh.flags & XUrgencyHint) ? true : false;
		if(wmh.flags & InputHint)
			c.neverfocus = !wmh.input;
		else
			c.neverfocus = false;
		XFree(wmh);
	}
}

void applyRules(Client c){
	string _class, instance;
	uint i;
	const(Rule)* r;
	Monitor *m;
	XClassHint ch = { null, null };

	/* rule matching */
	c.isfloating = c.tags = 0;
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
			c.isfloating = r.isfloating;
			c.tags |= r.tags;
			for(m = monitors; m && m.num != r.monitor; m = m.next){}
			if(m)
				c.monitor = m;
		}
	}
	if(ch.res_class)
		XFree(ch.res_class);
	if(ch.res_name)
		XFree(ch.res_name);
	c.tags = c.tags & TAGMASK ? c.tags & TAGMASK : c.monitor.tagset[c.monitor.seltags];
}

void attach(Client c){
	c.next = c.monitor.clients;
	c.monitor.clients = c;
}

void attachstack(Client c){
	c.snext = c.monitor.stack;
	c.monitor.stack = c;
}

void clearurgent(Client c){
	XWMHints* wmh = XGetWMHints(dpy, c.win);
	c.isurgent = false;
	if(!wmh)
		return;
	wmh.flags &= ~XUrgencyHint;
	XSetWMHints(dpy, c.win, wmh);
	XFree(wmh);
}

void configure(Client c){
	XConfigureEvent ce;

	ce.type = ConfigureNotify;
	ce.display = dpy;
	ce.event = c.win;
	ce.window = c.win;
	ce.x = c.x;
	ce.y = c.y;
	ce.width = c.w;
	ce.height = c.h;
	ce.border_width = c.bw;
	ce.above = None;
	ce.override_redirect = false;
	XSendEvent(dpy, c.win, false, StructureNotifyMask, cast(XEvent*)&ce);
}

void detach(Client c){
	Client* tc;
	for(tc = &c.monitor.clients; *tc && *tc != c; tc = &(*tc).next){}
	*tc = c.next;
}

void detachstack(Client c){
	Client* tc;
	Client t;

	for(tc = &c.monitor.stack; *tc && *tc != c; tc = &(*tc).snext){}
	*tc = c.snext;

	if(c == c.monitor.clientActive){
		for(t = c.monitor.stack; t && !isVisible(t); t = t.snext){}
		c.monitor.clientActive = t;
	}
}

void focus(Client c){
	if(!c || !isVisible(c))
		for(c = monitorActive.stack; c && !isVisible(c); c = c.snext){}
	/* was if(monitorActive.clientActive) */
	if(monitorActive.clientActive && monitorActive.clientActive != c)
		unfocus(monitorActive.clientActive, false);
	if(c){
		if(c.monitor != monitorActive)
			monitorActive = c.monitor;
		if(c.isurgent)
			clearurgent(c);
		detachstack(c);
		attachstack(c);
		grabbuttons(c, true);
		XSetWindowBorder(dpy, c.win, scheme[SchemeSel].border.pix);
		setfocus(c);
	}
	else {
		XSetInputFocus(dpy, root, RevertToPointerRoot, CurrentTime);
		XDeleteProperty(dpy, root, netatom[NetActiveWindow]);
	}
	monitorActive.clientActive = c;
	drawbars();
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
			if(buttons[i].click == ClkClientWin)
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

auto isVisible(Client client){
	return client.tags & client.monitor.tagset[client.monitor.seltags];
}
