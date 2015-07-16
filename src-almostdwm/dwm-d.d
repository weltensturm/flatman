module dwm.dwm;

import dwm;


// TODO: fuck x11-master
enum XA_ATOM = 4;
enum XA_STRING = 31;
enum XA_WINDOW = 33;
enum XA_WM_HINTS = 35;
enum XA_WM_NAME = 39;
enum XA_WM_NORMAL_HINTS = 40;
enum XA_WM_TRANSIENT_FOR = 68;
enum Success = 0;
enum XC_fleur = 52;
enum XC_left_ptr = 68;
enum XC_sizing = 120;
enum XK_Num_Lock = 0xff7f;
// endtodo

enum WM_NAME = "flatwm";

T CLEANMASK(T)(T mask){
	return mask & ~(numlockmask|LockMask) & (ShiftMask|ControlMask|Mod1Mask|Mod2Mask|Mod3Mask|Mod4Mask|Mod5Mask);
}

auto intersect(T, M)(T x, T y, T w, T h, M m){
	return (max(0, min(x+w,m.wx+m.ww) - max(x,m.wx))
    	* max(0, min(y+h,m.wy+m.wh) - max(y,m.wy)));
}

auto width(T)(T x){
	return x.w + 2 * x.bw;
}

auto height(T)(T x){
	return x.h + 2 * x.bw;
}

enum TAGMASK = (1 << tags.length) - 1;

auto TEXTW(T)(T X){
	return drw_text(draw, 0, 0, 0, 0, X.toStringz, 0) + draw.fonts[0].h;
}

/* enums */
enum { CurNormal, CurResize, CurMove, CurLast }; /* cursor */
enum { SchemeNorm, SchemeSel, SchemeLast }; /* color schemes */
enum { NetSupported, NetWMName, NetWMState,
       NetWMFullscreen, NetActiveWindow, NetWMWindowType,
       NetWMWindowTypeDialog, NetClientList, NetLast }; /* EWMH atoms */
enum { WMProtocols, WMDelete, WMState, WMTakeFocus, WMLast }; /* default atoms */
enum { ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle,
       ClkClientWin, ClkRootWin, ClkLast }; /* clicks */

struct Button {
	uint click;
	uint mask;
	uint button;
	void delegate(int) func;
}

struct Key {
	uint mod;
	KeySym keysym;
	void delegate() func;
}

struct Layout {
	string symbol;
	void function(Monitor*) arrange;
}

struct Rule {
	string _class;
	string instance;
	string title;
	uint tags;
	bool isfloating;
	int monitor;
}

/* variables */
enum broken = "broken";
static char[256] statusText;
static int screen;
static int sw, sh;           /* X display screen geometry width, height */
static int bh, blw = 0;      /* bar geometry */
extern(C) nothrow int function(Display *, XErrorEvent *) xerrorxlib;
static uint numlockmask = 0;
enum handler = [
	ButtonPress: &onButton,
	ClientMessage: &onClientMessage,
	ConfigureRequest: &onConfigureRequest,
	ConfigureNotify: &onConfigure,
	DestroyNotify: &onDestroy,
	EnterNotify: &onEnter,
	Expose: &onExpose,
	FocusIn: &onFocus,
	KeyPress: &onKey,
	MappingNotify: &onMap,
	MapRequest: &onMapRequest,
	MotionNotify: &onMotion,
	PropertyNotify: &onProperty,
	UnmapNotify: &onUnmap
];
static Atom[WMLast] wmatom;
static Atom[NetLast] netatom;
static bool running = true;
static Cur*[CurLast] cursor;
static ClrScheme[SchemeLast] scheme;
static Display* dpy;
static Drw* draw;
static Monitor* monitors, monitorActive;
static Window root;

static assert(tags.length < 32);


void main(string[] args){
	try{
		if(args.length == 2 && args[1] == "-v")
			throw new Exception(WM_NAME~", © 2006-2014 dwm engineers, see LICENSE for details");
		else if(args.length != 1)
			throw new Exception("usage: dwm [-v]");
		if(!setlocale(LC_CTYPE, "") || !XSupportsLocale())
			writeln("warning: no locale support");
		dpy = XOpenDisplay(null);
		if(!dpy)
			throw new Exception("dwm: cannot open display");
		checkOtherWm();
		setup();
		scan();
		run();
		cleanup();
		XCloseDisplay(dpy);
	}catch(Throwable t){
		"/tmp/dwm.log".write(t);
		throw t;
	}
}


void checkOtherWm(){
	xerrorxlib = XSetErrorHandler(&xerrorstart);
	/* this causes an error if some other window manager is running */
	XSelectInput(dpy, DefaultRootWindow(dpy), SubstructureRedirectMask);
	XSync(dpy, false);
	XSetErrorHandler(&xerror);
	XSync(dpy, false);
}

void setup(){
	XSetWindowAttributes wa;

	/* clean up any zombies immediately */
	sigchld(0);

	/* init screen */
	screen = DefaultScreen(dpy);
	sw = DisplayWidth(dpy, screen);
	sh = DisplayHeight(dpy, screen);
	root = RootWindow(dpy, screen);
	draw = drw_create(dpy, screen, root, sw, sh);
	drw_load_fonts(draw, fonts, fonts.length);
	if (!draw.fontcount)
		throw new Exception("No fonts could be loaded.");
	bh = draw.fonts[0].h + 2;
	updategeom();
	/* init atoms */
	wmatom[WMProtocols] = XInternAtom(dpy, "WM_PROTOCOLS", false);
	wmatom[WMDelete] = XInternAtom(dpy, "WM_DELETE_WINDOW", false);
	wmatom[WMState] = XInternAtom(dpy, "WM_STATE", false);
	wmatom[WMTakeFocus] = XInternAtom(dpy, "WM_TAKE_FOCUS", false);
	netatom[NetActiveWindow] = XInternAtom(dpy, "_NET_ACTIVE_WINDOW", false);
	netatom[NetSupported] = XInternAtom(dpy, "_NET_SUPPORTED", false);
	netatom[NetWMName] = XInternAtom(dpy, "_NET_WM_NAME", false);
	netatom[NetWMState] = XInternAtom(dpy, "_NET_WM_STATE", false);
	netatom[NetWMFullscreen] = XInternAtom(dpy, "_NET_WM_STATE_FULLSCREEN", false);
	netatom[NetWMWindowType] = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", false);
	netatom[NetWMWindowTypeDialog] = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DIALOG", false);
	netatom[NetClientList] = XInternAtom(dpy, "_NET_CLIENT_LIST", false);
	/* init cursors */
	cursor[CurNormal] = drw_cur_create(draw, XC_left_ptr);
	cursor[CurResize] = drw_cur_create(draw, XC_sizing);
	cursor[CurMove] = drw_cur_create(draw, XC_fleur);
	/* init appearance */
	scheme[SchemeNorm].border = drw_clr_create(draw, normbordercolor);
	scheme[SchemeNorm].bg = drw_clr_create(draw, normbgcolor);
	scheme[SchemeNorm].fg = drw_clr_create(draw, normfgcolor);
	scheme[SchemeSel].border = drw_clr_create(draw, selbordercolor);
	scheme[SchemeSel].bg = drw_clr_create(draw, selbgcolor);
	scheme[SchemeSel].fg = drw_clr_create(draw, selfgcolor);
	/* init bars */
	updatebars();
	updatestatus();
	/* EWMH support per view */
	XChangeProperty(dpy, root, netatom[NetSupported], XA_ATOM, 32,
			PropModeReplace, cast(ubyte*) netatom, NetLast);
	XDeleteProperty(dpy, root, netatom[NetClientList]);
	/* select for events */
	wa.cursor = cursor[CurNormal].cursor;
	wa.event_mask = SubstructureRedirectMask|SubstructureNotifyMask|ButtonPressMask|PointerMotionMask
	                |EnterWindowMask|LeaveWindowMask|StructureNotifyMask|PropertyChangeMask;
	XChangeWindowAttributes(dpy, root, CWEventMask|CWCursor, &wa);
	XSelectInput(dpy, root, wa.event_mask);
	grabkeys();
	focus(null);
}

void run(){
	XEvent ev;
	/* main event loop */
	XSync(dpy, false);
	while(running && !XNextEvent(dpy, &ev)){
		if(ev.type in handler && handler[ev.type])
			handler[ev.type](&ev); /* call handler */
	}
}


void onButton(XEvent* e){
	uint i, x, click;
	XButtonPressedEvent* ev = &e.xbutton;
	Client c = wintoclient(ev.window);

	click = ClkRootWin;
	/* focus monitor if necessary */
	Monitor* m = wintomon(ev.window);
	if(m && m != monitorActive){
		unfocus(monitorActive.clientActive, true);
		monitorActive = m;
		focus(null);
	}
	uint arg;
	if(ev.window == monitorActive.barwin){
		i = x = 0;
		do
			x += TEXTW(tags[i]);
		while(ev.x >= x && ++i < tags.length);
		if(i < tags.length){
			click = ClkTagBar;
			arg = 1 << i;
		}
		else if(ev.x < x + blw)
			click = ClkLtSymbol;
		else if(ev.x > monitorActive.ww - TEXTW(statusText))
			click = ClkStatusText;
		else
			click = ClkWinTitle;
	}
	else if(c){
		focus(c);
		click = ClkClientWin;
	}
	for(i = 0; i < buttons.length; i++)
		if(click == buttons[i].click && buttons[i].func && buttons[i].button == ev.button
		&& CLEANMASK(buttons[i].mask) == CLEANMASK(ev.state))
			buttons[i].func(arg);
}

void onClientMessage(XEvent *e){
	XClientMessageEvent *cme = &e.xclient;
	Client c = wintoclient(cme.window);
	if(!c)
		return;
	if(cme.message_type == netatom[NetWMState]){
		if(cme.data.l[1] == netatom[NetWMFullscreen] || cme.data.l[2] == netatom[NetWMFullscreen])
			setfullscreen(c, (cme.data.l[0] == 1 /* _NET_WM_STATE_ADD    */
			              || (cme.data.l[0] == 2 /* _NET_WM_STATE_TOGGLE */ && !c.isfullscreen)));
	}else if(cme.message_type == netatom[NetActiveWindow]){
		if(!isVisible(c)){
			c.monitor.seltags ^= 1;
			c.monitor.tagset[c.monitor.seltags] = c.tags;
		}
		pop(c);
	}
}

void onConfigure(XEvent *e){
	Monitor* m;
	XConfigureEvent *ev = &e.xconfigure;
	bool dirty;
	// TODO: updategeom handling sucks, needs to be simplified
	if(ev.window == root){
		dirty = (sw != ev.width || sh != ev.height);
		sw = ev.width;
		sh = ev.height;
		if(updategeom() || dirty){
			drw_resize(draw, sw, bh);
			updatebars();
			for(m = monitors; m; m = m.next)
				XMoveResizeWindow(dpy, m.barwin, m.wx, m.by, m.ww, bh);
			focus(null);
			arrange(null);
		}
	}
}

void onConfigureRequest(XEvent* e){
	Monitor* m;
	XConfigureRequestEvent* ev = &e.xconfigurerequest;
	Client c = wintoclient(ev.window);
	XWindowChanges wc;

	if(c){
		if(ev.value_mask & CWBorderWidth)
			c.bw = ev.border_width;
		else if(c.isfloating || !monitorActive.lt[monitorActive.sellt].arrange){
			m = c.monitor;
			if(ev.value_mask & CWX){
				c.oldx = c.x;
				c.x = m.mx + ev.x;
			}
			if(ev.value_mask & CWY){
				c.oldy = c.y;
				c.y = m.my + ev.y;
			}
			if(ev.value_mask & CWWidth){
				c.oldw = c.w;
				c.w = ev.width;
			}
			if(ev.value_mask & CWHeight){
				c.oldh = c.h;
				c.h = ev.height;
			}
			if((c.x + c.w) > m.mx + m.mw && c.isfloating)
				c.x = m.mx + (m.mw / 2 - width(c) / 2); /* center in x direction */
			if((c.y + c.h) > m.my + m.mh && c.isfloating)
				c.y = m.my + (m.mh / 2 - height(c) / 2); /* center in y direction */
			if((ev.value_mask & (CWX|CWY)) && !(ev.value_mask & (CWWidth|CWHeight)))
				configure(c);
			if(isVisible(c))
				XMoveResizeWindow(dpy, c.win, c.x, c.y, c.w, c.h);
		}
		else
			configure(c);
	}
	else {
		wc.x = ev.x;
		wc.y = ev.y;
		wc.width = ev.width;
		wc.height = ev.height;
		wc.border_width = ev.border_width;
		wc.sibling = ev.above;
		wc.stack_mode = ev.detail;
		XConfigureWindow(dpy, ev.window, ev.value_mask, &wc);
	}
	XSync(dpy, false);
}

void onDestroy(XEvent* e){
	XDestroyWindowEvent* ev = &e.xdestroywindow;
	Client c = wintoclient(ev.window);
	if(c)
		unmanage(c, true);
}

void onEnter(XEvent* e){
	Client c;
	Monitor* m;
	XCrossingEvent* ev = &e.xcrossing;
	if((ev.mode != NotifyNormal || ev.detail == NotifyInferior) && ev.window != root)
		return;
	c = wintoclient(ev.window);
	m = c ? c.monitor : wintomon(ev.window);
	if(m != monitorActive){
		unfocus(monitorActive.clientActive, true);
		monitorActive = m;
	}
	else if(!c || c == monitorActive.clientActive)
		return;
	focus(c);
}

void onExpose(XEvent *e){
	XExposeEvent *ev = &e.xexpose;
	Monitor* m = wintomon(ev.window);
	if(ev.count == 0 && m)
		m.drawbar;
}

void onFocus(XEvent* e){ /* there are some broken focus acquiring clients */
	XFocusChangeEvent *ev = &e.xfocus;
	if(monitorActive.clientActive && ev.window != monitorActive.clientActive.win)
		setfocus(monitorActive.clientActive);
}

void onKey(XEvent* e){
	uint i;
	KeySym keysym;
	XKeyEvent *ev;
	ev = &e.xkey;
	keysym = XKeycodeToKeysym(dpy, cast(KeyCode)ev.keycode, 0);
	foreach(key; dwm.keys){
		if(keysym == key.keysym && CLEANMASK(key.mod) == CLEANMASK(ev.state) && key.func)
			key.func();
	}
}

void onMap(XEvent *e){
	XMappingEvent *ev = &e.xmapping;

	XRefreshKeyboardMapping(ev);
	if(ev.request == MappingKeyboard)
		grabkeys();
}

void onMapRequest(XEvent *e){
	static XWindowAttributes wa;
	XMapRequestEvent *ev = &e.xmaprequest;

	if(!XGetWindowAttributes(dpy, ev.window, &wa))
		return;
	if(wa.override_redirect)
		return;
	if(!wintoclient(ev.window))
		manage(ev.window, &wa);
}

void onMotion(XEvent* e){
	static Monitor* mon = null;
	Monitor* m;
	XMotionEvent *ev = &e.xmotion;

	if(ev.window != root)
		return;
	if((m = recttomon(ev.x_root, ev.y_root, 1, 1)) != mon && mon){
		unfocus(monitorActive.clientActive, true);
		monitorActive = m;
		focus(null);
	}
	mon = m;
}

void onProperty(XEvent *e){
	XPropertyEvent* ev = &e.xproperty;
	Client c = wintoclient(ev.window);
	Window trans;
	if((ev.window == root) && (ev.atom == XA_WM_NAME))
		updatestatus();
	else if(ev.state == PropertyDelete)
		return; /* ignore */
	else if(c){
		switch(ev.atom){
		default: break;
		case XA_WM_TRANSIENT_FOR:
			if(!c.isfloating && XGetTransientForHint(dpy, c.win, &trans)){
				c.isfloating = (wintoclient(trans) !is null);
				if(c.isfloating)
					arrange(c.monitor);
			}
			break;
		case XA_WM_NORMAL_HINTS:
			updatesizehints(c);
			break;
		case XA_WM_HINTS:
			updatewmhints(c);
			drawbars();
			break;
		}
		if(ev.atom == XA_WM_NAME || ev.atom == netatom[NetWMName]){
			updatetitle(c);
			if(c == c.monitor.clientActive)
				drawbar(c.monitor);
		}
		if(ev.atom == netatom[NetWMWindowType])
			updatewindowtype(c);
	}
}

Monitor* dirtomon(int dir){
	Monitor* m = monitorActive.next;
	if(dir > 0 && !m){
		m = monitors;
	}
	else if(monitorActive == monitors)
		for(m = monitors; m.next; m = m.next){}
	else
		for(m = monitors; m.next != monitorActive; m = m.next){}
	return m;
}

void drawbars(){
	Monitor* m;
	for(m = monitors; m; m = m.next)
		m.drawbar;
}

void focusmon(int arg){
	Monitor* m = dirtomon(arg);
	if(!monitors.next)
		return;
	if(m == monitorActive)
		return;
	unfocus(monitorActive.clientActive, false); /* s/true/false/ fixes input focus issues
					in gedit and anjuta */
	monitorActive = m;
	focus(null);
}

void focusstack(int arg){
	Client c, i;
	if(!monitorActive.clientActive)
		return;
	if(arg > 0){
		for(c = monitorActive.clientActive.next; c && !isVisible(c); c = c.next){}
		if(!c)
			for(c = monitorActive.clients; c && !isVisible(c); c = c.next){}
	}
	else {
		for(i = monitorActive.clients; i != monitorActive.clientActive; i = i.next)
			if(isVisible(i))
				c = i;
		if(!c)
			for(; i; i = i.next)
				if(isVisible(i))
					c = i;
	}
	if(c){
		focus(c);
		restack(monitorActive);
	}
}

bool getrootptr(int *x, int *y){
	int di;
	uint dui;
	Window dummy;

	return 1 == XQueryPointer(dpy, root, &dummy, &dummy, x, y, &di, &di, &dui);
}

long getstate(Window w){
	int format;
	long result = -1;
	ubyte* p = null;
	ulong n, extra;
	Atom _real;
	if(XGetWindowProperty(dpy, w, wmatom[WMState], 0L, 2L, false, wmatom[WMState],
	                      &_real, &format, &n, &extra, cast(ubyte**)&p) != 0)
		return -1;
	if(n != 0)
		result = *p;
	XFree(p);
	return result;
}

bool gettextprop(Window w, Atom atom, string text, uint size){
	char** list;
	int n;
	XTextProperty name;

	if(!text || size == 0)
		return false;
	XGetTextProperty(dpy, w, &name, atom);
	if(!name.nitems)
		return false;
	if(name.encoding == XA_STRING)
		text = to!string(name.value);
	else {
		if(XmbTextPropertyToTextList(dpy, &name, &list, &n) >= Success && n > 0 && *list){
			text = to!string(*list);
			XFreeStringList(list);
		}
	}
	XFree(name.value);
	return true;
}

void grabkeys(){
	updatenumlockmask();
	{
		uint i, j;
		uint[] modifiers = [ 0, LockMask, numlockmask, numlockmask|LockMask ];
		KeyCode code;
		XUngrabKey(dpy, AnyKey, AnyModifier, root);
		foreach(key; dwm.keys){
			code = XKeysymToKeycode(dpy, key.keysym);
			if(code)
				for(j = 0; j < modifiers.length; j++)
					XGrabKey(dpy, code, key.mod | modifiers[j], root,
						 true, GrabModeAsync, GrabModeAsync);
		}
	}
}

void incnmaster(int arg){
	monitorActive.nmaster = max(monitorActive.nmaster + arg, 0);
	arrange(monitorActive);
}

/+
#ifdef XINERAMA
static bool
isuniquegeom(XineramaScreenInfo *unique, size_t n, XineramaScreenInfo *info){
	while(n--)
		if(unique[n].x_org == info.x_org && unique[n].y_org == info.y_org
		&& unique[n].width == info.width && unique[n].height == info.height)
			return false;
	return true;
}
#endif /* XINERAMA */
+/

void killclient(){
	if(!monitorActive.clientActive)
		return;
	if(!sendevent(monitorActive.clientActive, wmatom[WMDelete])){
		XGrabServer(dpy);
		XSetErrorHandler(&xerrordummy);
		XSetCloseDownMode(dpy, CloseDownMode.DestroyAll);
		XKillClient(dpy, monitorActive.clientActive.win);
		XSync(dpy, false);
		XSetErrorHandler(&xerror);
		XUngrabServer(dpy);
	}
}

void manage(Window w, XWindowAttributes* wa){
	auto c = new Client;
	Window trans = None;
	XWindowChanges wc;
	c.win = w;
	updatetitle(c);
	Client t = wintoclient(trans);
	if(XGetTransientForHint(dpy, w, &trans) && t){
		c.monitor = t.monitor;
		c.tags = t.tags;
	}
	else {
		c.monitor = monitorActive;
		c.applyRules;
	}
	/* geometry */
	c.x = c.oldx = wa.x;
	c.y = c.oldy = wa.y;
	c.w = c.oldw = wa.width;
	c.h = c.oldh = wa.height;
	c.oldbw = wa.border_width;

	if(c.x + width(c) > c.monitor.mx + c.monitor.mw)
		c.x = c.monitor.mx + c.monitor.mw - width(c);
	if(c.y + height(c) > c.monitor.my + c.monitor.mh)
		c.y = c.monitor.my + c.monitor.mh - height(c);
	c.x = max(c.x, c.monitor.mx);
	/* only fix client y-offset, if the client center might cover the bar */
	c.y = max(c.y, ((c.monitor.by == c.monitor.my) && (c.x + (c.w / 2) >= c.monitor.wx)
	           && (c.x + (c.w / 2) < c.monitor.wx + c.monitor.ww)) ? bh : c.monitor.my);
	c.bw = borderpx;

	wc.border_width = c.bw;
	XConfigureWindow(dpy, w, CWBorderWidth, &wc);
	XSetWindowBorder(dpy, w, scheme[SchemeNorm].border.pix);
	configure(c); /* propagates border_width, if size doesn't change */
	updatewindowtype(c);
	updatesizehints(c);
	updatewmhints(c);
	XSelectInput(dpy, w, EnterWindowMask|FocusChangeMask|PropertyChangeMask|StructureNotifyMask);
	grabbuttons(c, false);
	if(!c.isfloating)
		c.isfloating = c.oldstate = trans != None || c.isfixed;
	if(c.isfloating)
		XRaiseWindow(dpy, c.win);
	attach(c);
	attachstack(c);
	XChangeProperty(dpy, root, netatom[NetClientList], XA_WINDOW, 32, PropModeAppend,
	                cast(ubyte*)&c.win, 1);
	XMoveResizeWindow(dpy, c.win, c.x + 2 * sw, c.y, c.w, c.h); /* some windows require this */
	setclientstate(c, NormalState);
	if (c.monitor == monitorActive)
		unfocus(monitorActive.clientActive, false);
	c.monitor.clientActive = c;
	arrange(c.monitor);
	XMapWindow(dpy, c.win);
	focus(null);
}

void movemouse(){
	int x, y, ocx, ocy, nx, ny;
	Client c = monitorActive.clientActive;
	Monitor* m;
	XEvent ev;
	Time lasttime = 0;

	if(!c)
		return;
	if(c.isfullscreen) /* no support moving fullscreen windows by mouse */
		return;
	restack(monitorActive);
	ocx = c.x;
	ocy = c.y;
	if(XGrabPointer(dpy, root, false, MOUSEMASK, GrabModeAsync, GrabModeAsync,
	None, cursor[CurMove].cursor, CurrentTime) != GrabSuccess)
		return;
	if(!getrootptr(&x, &y))
		return;
	do {
		XMaskEvent(dpy, MOUSEMASK|ExposureMask|SubstructureRedirectMask, &ev);
		switch(ev.type){
			case ConfigureRequest:
			case Expose:
			case MapRequest:
				handler[ev.type](&ev);
				break;
			case MotionNotify:
				if ((ev.xmotion.time - lasttime) <= (1000 / 60))
					continue;
				lasttime = ev.xmotion.time;
	
				nx = ocx + (ev.xmotion.x - x);
				ny = ocy + (ev.xmotion.y - y);
				if(nx >= monitorActive.wx && nx <= monitorActive.wx + monitorActive.ww
				&& ny >= monitorActive.wy && ny <= monitorActive.wy + monitorActive.wh){
					if(abs(monitorActive.wx - nx) < snap)
						nx = monitorActive.wx;
					else if(abs((monitorActive.wx + monitorActive.ww) - (nx + width(c))) < snap)
						nx = monitorActive.wx + monitorActive.ww - width(c);
					if(abs(monitorActive.wy - ny) < snap)
						ny = monitorActive.wy;
					else if(abs((monitorActive.wy + monitorActive.wh) - (ny + height(c))) < snap)
						ny = monitorActive.wy + monitorActive.wh - height(c);
					if(!c.isfloating && monitorActive.lt[monitorActive.sellt].arrange
					&& (abs(nx - c.x) > snap || abs(ny - c.y) > snap))
						togglefloating();
				}
				if(!monitorActive.lt[monitorActive.sellt].arrange || c.isfloating)
					c.resize(nx, ny, c.w, c.h, true);
				break;
			default: break;
		}
	} while(ev.type != ButtonRelease);
	XUngrabPointer(dpy, CurrentTime);
	if((m = recttomon(c.x, c.y, c.w, c.h)) != monitorActive){
		sendmon(c, m);
		monitorActive = m;
		focus(null);
	}
}

void quit(){
	running = false;
}

Monitor* recttomon(int x, int y, int w, int h){
	Monitor* m, r = monitorActive;
	int a, area = 0;
	for(m = monitors; m; m = m.next)
		if((a = intersect(x, y, w, h, m)) > area){
			area = a;
			r = m;
		}
	return r;
}

void resizemouse(){
	int ocx, ocy, nw, nh;
	Client c = monitorActive.clientActive;
	Monitor* m;
	XEvent ev;
	Time lasttime = 0;

	if(!c)
		return;
	if(c.isfullscreen) /* no support resizing fullscreen windows by mouse */
		return;
	restack(monitorActive);
	ocx = c.x;
	ocy = c.y;
	if(XGrabPointer(dpy, root, false, MOUSEMASK, GrabModeAsync, GrabModeAsync,
	                None, cursor[CurResize].cursor, CurrentTime) != GrabSuccess)
		return;
	XWarpPointer(dpy, None, c.win, 0, 0, 0, 0, c.w + c.bw - 1, c.h + c.bw - 1);
	do {
		XMaskEvent(dpy, MOUSEMASK|ExposureMask|SubstructureRedirectMask, &ev);
		switch(ev.type){
			case ConfigureRequest:
			case Expose:
			case MapRequest:
				handler[ev.type](&ev);
				break;
			case MotionNotify:
				if ((ev.xmotion.time - lasttime) <= (1000 / 60))
					continue;
				lasttime = ev.xmotion.time;
	
				nw = max(ev.xmotion.x - ocx - 2 * c.bw + 1, 1);
				nh = max(ev.xmotion.y - ocy - 2 * c.bw + 1, 1);
				if(c.monitor.wx + nw >= monitorActive.wx && c.monitor.wx + nw <= monitorActive.wx + monitorActive.ww
				&& c.monitor.wy + nh >= monitorActive.wy && c.monitor.wy + nh <= monitorActive.wy + monitorActive.wh)
				{
					if(!c.isfloating && monitorActive.lt[monitorActive.sellt].arrange
					&& (abs(nw - c.w) > snap || abs(nh - c.h) > snap))
						togglefloating();
				}
				if(!monitorActive.lt[monitorActive.sellt].arrange || c.isfloating)
					c.resize(c.x, c.y, nw, nh, true);
				break;
			default:break;
		}
	} while(ev.type != ButtonRelease);
	XWarpPointer(dpy, None, c.win, 0, 0, 0, 0, c.w + c.bw - 1, c.h + c.bw - 1);
	XUngrabPointer(dpy, CurrentTime);
	while(XCheckMaskEvent(dpy, EnterWindowMask, &ev)){}
	if((m = recttomon(c.x, c.y, c.w, c.h)) != monitorActive){
		sendmon(c, m);
		monitorActive = m;
		focus(null);
	}
}

void scan(){
	uint i, num;
	Window d1, d2;
	Window* wins;
	XWindowAttributes wa;

	if(XQueryTree(dpy, root, &d1, &d2, &wins, &num)){
		for(i = 0; i < num; i++){
			if(!XGetWindowAttributes(dpy, wins[i], &wa)
			|| wa.override_redirect || XGetTransientForHint(dpy, wins[i], &d1))
				continue;
			if(wa.map_state == IsViewable || getstate(wins[i]) == IconicState)
				manage(wins[i], &wa);
		}
		for(i = 0; i < num; i++){ /* now the transients */
			if(!XGetWindowAttributes(dpy, wins[i], &wa))
				continue;
			if(XGetTransientForHint(dpy, wins[i], &d1)
			&& (wa.map_state == IsViewable || getstate(wins[i]) == IconicState))
				manage(wins[i], &wa);
		}
		if(wins)
			XFree(wins);
	}
}

void setlayout(const(Layout)* layout){
	if(!layout || layout != monitorActive.lt[monitorActive.sellt])
		monitorActive.sellt ^= 1;
	if(layout)
		monitorActive.lt[monitorActive.sellt] = layout;
	monitorActive.ltsymbol = monitorActive.lt[monitorActive.sellt].symbol;
	if(monitorActive.clientActive)
		arrange(monitorActive);
	else
		drawbar(monitorActive);
}

/* arg > 1.0 will set mfact absolutly */
void setmfact(float arg){
	float f;
	if(!arg || !monitorActive.lt[monitorActive.sellt].arrange)
		return;
	f = arg < 1.0 ? arg + monitorActive.mfact : arg - 1.0;
	if(f < 0.1 || f > 0.9)
		return;
	monitorActive.mfact = f;
	arrange(monitorActive);
}

void tag(uint arg){
	if(monitorActive.clientActive && arg & TAGMASK){
		monitorActive.clientActive.tags = arg & TAGMASK;
		focus(null);
		arrange(monitorActive);
	}
}

void tagmon(int arg){
	if(!monitorActive.clientActive || !monitors.next)
		return;
	sendmon(monitorActive.clientActive, dirtomon(arg));
}

void togglebar(){
	monitorActive.showbar = !monitorActive.showbar;
	updatebarpos(monitorActive);
	XMoveResizeWindow(dpy, monitorActive.barwin, monitorActive.wx, monitorActive.by, monitorActive.ww, bh);
	arrange(monitorActive);
}

void togglefloating(){
	if(!monitorActive.clientActive)
		return;
	if(monitorActive.clientActive.isfullscreen) /* no support for fullscreen windows */
		return;
	monitorActive.clientActive.isfloating = !monitorActive.clientActive.isfloating || monitorActive.clientActive.isfixed;
	if(monitorActive.clientActive.isfloating)
		monitorActive.clientActive.resize(monitorActive.clientActive.x, monitorActive.clientActive.y,
		       monitorActive.clientActive.w, monitorActive.clientActive.h, false);
	arrange(monitorActive);
}

void toggletag(uint arg){
	uint newtags;

	if(!monitorActive.clientActive)
		return;
	newtags = monitorActive.clientActive.tags ^ (arg & TAGMASK);
	if(newtags){
		monitorActive.clientActive.tags = newtags;
		focus(null);
		arrange(monitorActive);
	}
}

void toggleview(uint arg){
	uint newtagset = monitorActive.tagset[monitorActive.seltags] ^ (arg & TAGMASK);

	if(newtagset){
		monitorActive.tagset[monitorActive.seltags] = newtagset;
		focus(null);
		arrange(monitorActive);
	}
}

void onUnmap(XEvent *e){
	XUnmapEvent *ev = &e.xunmap;
	Client c = wintoclient(ev.window);
	if(c){
		if(ev.send_event)
			setclientstate(c, WithdrawnState);
		else
			unmanage(c, false);
	}
}

void updatebars(){
	Monitor* m;
	XSetWindowAttributes wa;
	wa.override_redirect = true;
	wa.background_pixmap = ParentRelative;
	wa.event_mask = ButtonPressMask|ExposureMask;
	for(m = monitors; m; m = m.next){
		if (m.barwin)
			continue;
		m.barwin = XCreateWindow(dpy, root, m.wx, m.by, m.ww, bh, 0, DefaultDepth(dpy, screen),
		                          CopyFromParent, DefaultVisual(dpy, screen),
		                          CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa);
		XDefineCursor(dpy, m.barwin, cursor[CurNormal].cursor);
		XMapRaised(dpy, m.barwin);
	}
}

void updateclientlist(){
	Client c;
	Monitor* m;
	XDeleteProperty(dpy, root, netatom[NetClientList]);
	for(m = monitors; m; m = m.next)
		for(c = m.clients; c; c = c.next)
			XChangeProperty(dpy, root, netatom[NetClientList],
			                XA_WINDOW, 32, PropModeAppend,
			                cast(ubyte*) &(c.win), 1);
}

bool updategeom(){
	bool dirty = false;
	{
		if(!monitors)
			monitors = createmon();
		if(monitors.mw != sw || monitors.mh != sh){
			dirty = true;
			monitors.mw = monitors.ww = sw;
			monitors.mh = monitors.wh = sh;
			updatebarpos(monitors);
		}
	}
	if(dirty){
		monitorActive = monitors;
		monitorActive = wintomon(root);
	}
	return dirty;
}

void updatenumlockmask(){
	uint i, j;
	XModifierKeymap *modmap;

	numlockmask = 0;
	modmap = XGetModifierMapping(dpy);
	for(i = 0; i < 8; i++)
		for(j = 0; j < modmap.max_keypermod; j++)
			if(modmap.modifiermap[i * modmap.max_keypermod + j]
			   == XKeysymToKeycode(dpy, XK_Num_Lock))
				numlockmask = (1 << i);
	XFreeModifiermap(modmap);
}

void updatestatus(){
	if(!gettextprop(root, XA_WM_NAME, to!string(statusText), cast(uint)statusText.sizeof))
		statusText = WM_NAME;
	drawbar(monitorActive);
}

void view(uint arg = 0){
	"/tmp/dwm.log".append(to!string(arg) ~ '\n');
	if((arg & TAGMASK) == monitorActive.tagset[monitorActive.seltags])
		return;
	monitorActive.seltags ^= 1; /* toggle clientActive tagset */
	if(arg & TAGMASK)
		monitorActive.tagset[monitorActive.seltags] = arg & TAGMASK;
	focus(null);
	arrange(monitorActive);
}

Client wintoclient(Window w){
	Client c;
	Monitor* m;

	for(m = monitors; m; m = m.next)
		for(c = m.clients; c; c = c.next)
			if(c.win == w)
				return c;
	return null;
}

Monitor* wintomon(Window w){
	int x, y;
	Client c = wintoclient(w);
	Monitor* m;

	if(w == root && getrootptr(&x, &y))
		return recttomon(x, y, 1, 1);
	for(m = monitors; m; m = m.next)
		if(w == m.barwin)
			return m;
	if(c)
		return c.monitor;
	return monitorActive;
}

void zoom(){
	Client c = monitorActive.clientActive;

	if(!monitorActive.lt[monitorActive.sellt].arrange
	|| (monitorActive.clientActive && monitorActive.clientActive.isfloating))
		return;
	if(c == nexttiled(monitorActive.clients))
		if(!c){
			c = nexttiled(c.next);
			if(!c)
				return;
		}
	pop(c);
}

void cleanup(){
	Layout foo = { "", null };
	Monitor* m;

	view(~0);
	monitorActive.lt[monitorActive.sellt] = &foo;
	for(m = monitors; m; m = m.next)
		while(m.stack)
			unmanage(m.stack, false);
	XUngrabKey(dpy, AnyKey, AnyModifier, root);
	while(monitors)
		dwm.cleanup(monitors);
	drw_cur_free(draw, cursor[CurNormal]);
	drw_cur_free(draw, cursor[CurResize]);
	drw_cur_free(draw, cursor[CurMove]);
	drw_clr_free(scheme[SchemeNorm].border);
	drw_clr_free(scheme[SchemeNorm].bg);
	drw_clr_free(scheme[SchemeNorm].fg);
	drw_clr_free(scheme[SchemeSel].border);
	drw_clr_free(scheme[SchemeSel].bg);
	drw_clr_free(scheme[SchemeSel].fg);
	drw_free(draw);
	XSync(dpy, false);
	XSetInputFocus(dpy, PointerRoot, RevertToPointerRoot, CurrentTime);
	XDeleteProperty(dpy, root, netatom[NetActiveWindow]);
}


@system @nogc extern(C) nothrow void sigchld(int unused){
	if(signal(SIGCHLD, &sigchld) == SIG_ERR){
		assert(0, "Can't install SIGCHLD handler");
	}
	while(0 < waitpid(-1, null, WNOHANG)){}
}

/* There's no way to check accesses to destroyed windows, thus those cases are
 * ignored (especially on UnmapNotify's).  Other types of errors call Xlibs
 * default error handler, which may call exit.  */
extern(C) nothrow int xerror(Display *dpy, XErrorEvent *ee){
	if(ee.error_code == XErrorCode.BadWindow
	|| (ee.request_code == X_SetInputFocus && ee.error_code == XErrorCode.BadMatch)
	|| (ee.request_code == X_PolyText8 && ee.error_code == XErrorCode.BadDrawable)
	|| (ee.request_code == X_PolyFillRectangle && ee.error_code == XErrorCode.BadDrawable)
	|| (ee.request_code == X_PolySegment && ee.error_code == XErrorCode.BadDrawable)
	|| (ee.request_code == X_ConfigureWindow && ee.error_code == XErrorCode.BadMatch)
	|| (ee.request_code == X_GrabButton && ee.error_code == XErrorCode.BadAccess)
	|| (ee.request_code == X_GrabKey && ee.error_code == XErrorCode.BadAccess)
	|| (ee.request_code == X_CopyArea && ee.error_code == XErrorCode.BadDrawable))
		return 0;
	try
		writeln("dwm: fatal error: request code=%d, error code=%d".format(ee.request_code, ee.error_code));
	catch {}
	return xerrorxlib(dpy, ee); /* may call exit */
}

extern(C) nothrow int xerrordummy(Display* dpy, XErrorEvent* ee){
	return 0;
}

/* Startup Error handler to check if another window manager
 * is already running. */
nothrow extern(C) int xerrorstart(Display *dpy, XErrorEvent* ee){
	try
		writeln("dwm: another window manager is already running");
	catch {}
	_exit(-1);
	return -1;
}
