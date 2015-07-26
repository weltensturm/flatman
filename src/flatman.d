module flatman.flatman;

import flatman;

__gshared:


// TODO: fuck x11-master
enum Success = 0;
enum XC_fleur = 52;
enum XC_left_ptr = 68;
enum XC_sizing = 120;
enum XK_Num_Lock = 0xff7f;
enum CompositeRedirectManual = 1;
// endtodo

enum WM_NAME = "flatman";

T CLEANMASK(T)(T mask){
	return mask & ~(numlockmask|LockMask) & (ShiftMask|ControlMask|Mod1Mask|Mod2Mask|Mod3Mask|Mod4Mask|Mod5Mask);
}

auto intersect(T, M)(T x, T y, T w, T h, M m){
	return (max(0, min(x+w,m.pos.x+m.size.w) - max(x,m.pos.x))
    	* max(0, min(y+h,m.pos.y+m.size.h) - max(y,m.pos.y)));
}

auto width(T)(T x){
	return x.size.w + 2 * x.bw;
}

auto height(T)(T x){
	return x.size.h + 2 * x.bw;
}

enum TAGMASK = (1 << tags.length) - 1;

/* enums */
enum { CurNormal, CurResize, CurMove, CurLast }; /* cursor */
enum { SchemeNorm, SchemeSel, SchemeLast }; /* color schemes */
enum { ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle,
       ClkClientWin, ClkRootWin, ClkLast }; /* clicks */


struct WmAtoms {
	@("WM_PROTOCOLS") Atom protocols;
	@("WM_DELETE_WINDOW") Atom delete_;
	@("WM_STATE") Atom state;
	@("WM_TAKE_FOCUS") Atom takeFocus;
}

WmAtoms wm;


void fillAtoms(T)(ref T data){
	foreach(n; FieldNameTuple!T){
		mixin("data." ~ n ~ " = atom(__traits(getAttributes, data."~n~")[0]);");
	}
}


struct Button {
	uint mask;
	uint button;
	void function() func;
}

struct Key {
	uint mod;
	KeySym keysym;
	void delegate() func;
}

struct Layout {
	string symbol;
	void function(Monitor) arrange;
}

struct Rule {
	string _class;
	string instance;
	string title;
	uint tags;
	bool isFloating;
	int monitor;
}

/* variables */
enum broken = "broken";
static string statusText;
static int screen;
static int sw, sh;           /* X display screen geometry width, height */
static int bh, blw = 0;      /* bar geometry */
extern(C) nothrow int function(Display *, XErrorEvent *) xerrorxlib;
static uint numlockmask = 0;
enum handler = [
	ButtonPress: &onButton,
	ButtonRelease: &onButtonRelease,
	ClientMessage: &onClientMessage,
	ConfigureRequest: &onConfigureRequest,
	ConfigureNotify: &onConfigure,
	DestroyNotify: &onDestroy,
	EnterNotify: &onEnter,
	LeaveNotify: &onLeave,
	Expose: &onExpose,
	FocusIn: &onFocus,
	KeyPress: &onKey,
	KeyRelease: &onKeyRelease,
	MappingNotify: &onMapping,
	MapRequest: &onMapRequest,
	MotionNotify: &onMotion,
	PropertyNotify: &onProperty,
	UnmapNotify: &onUnmap
];
static bool running = true;
bool restart = false;
static Cur[CurLast] cursor;
static Display* dpy;
static Monitor monitorActive;
static Monitor[] monitors;
static Window root;
static Draw draw;


void log(string s){
	"/tmp/flatman.log".append(s ~ '\n');
	spawnProcess(["notify-send", s]);
}


void main(string[] args){
	try{
		XInitThreads();
		if(args.length == 2 && args[1] == "-v")
			throw new Exception(WM_NAME~", © Robert Luger");
		else if(args.length != 1)
			throw new Exception("usage: flatman [-v]");
		if(!setlocale(LC_CTYPE, "") || !XSupportsLocale())
			writeln("warning: no locale support");
		dpy = XOpenDisplay(null);
		XSynchronize(dpy, true);
		if(!dpy)
			throw new Exception("flatman: cannot open display");
		"checkOtherWm".log;
		checkOtherWm();
		"setup".log;
		setup();
		"scan".log;
		scan();
		"run".log;
		run();
	}catch(Throwable t){
		"/tmp/flatman.log".append(t.toString);
		throw t;
	}
	"cleanup".log;
	cleanup();
	XCloseDisplay(dpy);
	if(restart){
		"restart".log;
		spawnProcess(args);
	}
}


void checkOtherWm(){
	xerrorxlib = XSetErrorHandler(&xerrorstart);
	XSelectInput(dpy, DefaultRootWindow(dpy), SubstructureRedirectMask);
	XSync(dpy, false);
	XSetErrorHandler(&xerror);
	XSync(dpy, false);
}


static Atom[string] atoms;

Atom atom(string n){
	if(n !in atoms)
		atoms[n] = XInternAtom(dpy, n.toStringz, false);
	return atoms[n];
}

void setup(){
	/* clean up any zombies immediately */
	sigchld(0);

	/* init screen */
	screen = DefaultScreen(dpy);
	root = XDefaultRootWindow(dpy);

	//wm = new CompositeManager;

	sw = DisplayWidth(dpy, screen);
	sh = DisplayHeight(dpy, screen);
	root = RootWindow(dpy, screen);

	draw = new Draw(dpy, screen, root, sw, sh);
	draw.load_fonts(fonts);
	if (!draw.fonts.length)
		throw new Exception("No fonts could be loaded.");
	bh = cast(int)(draw.fonts[0].h*1.4).lround;
	/* init atoms */
	/* init cursors */
	cursor[CurNormal] = new Cur(XC_left_ptr);
	cursor[CurResize] = new Cur(XC_sizing);
	cursor[CurMove] = new Cur(XC_fleur);

	fillAtoms(wm);
	fillAtoms(net);

	//updatebars();
	updategeom();
	updatestatus();
	/* EWMH support per view */
	XDeleteProperty(dpy,root, net.supported);
	foreach(n; FieldNameTuple!NetAtoms)
		mixin("XChangeProperty(dpy, root, net.supported, XA_ATOM, 32, PropModeAppend, cast(ubyte*)&net." ~ n ~", 1);");
	XDeleteProperty(dpy, root, net.clientList);
	updateDesktopCount;
	updateCurrentDesktop;
	/* select for events */
	XSetWindowAttributes wa;
	wa.cursor = cursor[CurNormal].cursor;
	wa.event_mask = 
			SubstructureRedirectMask|SubstructureNotifyMask|ButtonPressMask
			|PointerMotionMask|EnterWindowMask|LeaveWindowMask|StructureNotifyMask
			|PropertyChangeMask|KeyReleaseMask;
	XChangeWindowAttributes(dpy, root, CWEventMask|CWCursor, &wa);
	XSelectInput(dpy, root, wa.event_mask);
	grabkeys();
	focus(null);

	try
		"~/.autostart.sh".expandTilde.spawnProcess;
	catch{}
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
	Monitor m = wintomon(ev.window);
	if(m && m != monitorActive){
		unfocus(monitorActive.active, true);
		monitorActive = m;
		focus(null);
	}
	//if(ev.window == monitorActive.bar.window){
	//	monitorActive.bar.onButton(e);
	if(ev.window == monitorActive.dock.window){
		monitorActive.dock.onButton(e);
	}else if(ev.window == monitorActive.workspace.split.window){
		monitorActive.workspace.split.onButton(ev);
	}else if(c){
		c.focus;
		for(i = 0; i < buttons.length; i++)
			if(buttons[i].button == ev.button
			&& CLEANMASK(buttons[i].mask) == CLEANMASK(ev.state))
				buttons[i].func();
	}
}

void onButtonRelease(XEvent* e){
	XButtonReleasedEvent* ev = &e.xbutton;
	if(ev.window == monitorActive.workspace.split.window)
		monitorActive.workspace.split.onButtonRelease(ev);
}

void onClientMessage(XEvent *e){
	XClientMessageEvent *cme = &e.xclient;
	auto handler = [
		net.currentDesktop: {
			monitorActive.switchWorkspace(cast(int)cme.data.l[0]);
		},
		net.wmState: {
			Client c = wintoclient(cme.window);
			if(!c)
				return;
			if(cme.message_type == net.wmState){
				if(cme.data.l[1] == net.wmFullscreen || cme.data.l[2] == net.wmFullscreen)
					setfullscreen(c, (cme.data.l[0] == 1 /* _NET_WM_STATE_ADD    */
			              || (cme.data.l[0] == 2 /* _NET_WM_STATE_TOGGLE */ && !c.isfullscreen)));
			}
		},
		net.activeWindow: {
			Client c = wintoclient(cme.window);
			if(!c)
				return;
			c.focus;
			//XDeleteProperty(dpy, c.win, net.activeWindow);
			//XChangeProperty(dpy, c.win, net.attention);
		},
		net.appDesktop: {
			Client c = wintoclient(cme.window);
			if(!c)
				return;
			c.setWorkspace(cme.data.l[0]);
		},
		net.moveResize: {
			Client c = wintoclient(cme.window);
			if(!c)
				return;
			c.moveResize(cme.data.l[0..2].to!(int[2]), cme.data.l[2..4].to!(int[2]));
		},
	];
	if(cme.message_type in handler)
		handler[cme.message_type]();
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
			if(!c.isFloating && XGetTransientForHint(dpy, c.win, &trans)){
				c.isFloating = (wintoclient(trans) !is null);
			}
			break;
		case XA_WM_NORMAL_HINTS:
			c.updateSizeHints;
			break;
		case XA_WM_HINTS:
			c.updateWmHints;
			foreach(m; monitors)
				m.draw;
			break;
		}
		if(ev.atom == XA_WM_NAME || ev.atom == net.wmName){
			updatetitle(c);
			if(c == c.monitor.active)
				c.monitor.draw;
		}
		if(ev.atom == net.wmWindowType)
			c.updateType;
		if(ev.atom == net.wmStrutPartial){
			c.updateStrut;
		}
	}
}

void onConfigure(XEvent *e){
	Monitor m;
	XConfigureEvent *ev = &e.xconfigure;
	bool dirty;
	if(ev.window == root){
		dirty = (sw != ev.width || sh != ev.height);
		sw = ev.width;
		sh = ev.height;
		if(updategeom() || dirty){
			draw.resize(sw, sh);
			monitorActive.resize([sw, sh]);
			focus(null);
		}
	}
}

void onConfigureRequest(XEvent* e){
	XConfigureRequestEvent* ev = &e.xconfigurerequest;
	Client c = wintoclient(ev.window);
	if(c){
		if(c.isFloating){
			Monitor m = c.monitor;
			if(ev.value_mask & CWX){
				c.posOld.x = c.pos.x;
				c.pos.x = m.pos.x + ev.x;
			}
			if(ev.value_mask & CWY){
				c.posOld.y = c.pos.y;
				c.pos.y = m.pos.y + ev.y;
			}
			if(ev.value_mask & CWWidth){
				c.sizeOld.w = c.size.w;
				c.size.w = ev.width;
			}
			if(ev.value_mask & CWHeight){
				c.sizeOld.h = c.size.h;
				c.size.h = ev.height;
			}
			if((ev.value_mask & (CWX|CWY))){
				if(!(ev.value_mask & (CWWidth|CWHeight)))
					c.configure;
			}else{
				//c.pos.x = monitorActive.size.x/2 - c.size.w/2;
				//c.pos.y = monitorActive.size.y - c.size.h;
			}
			if(c.isVisible)
				XMoveResizeWindow(dpy, c.win, c.pos.x, c.pos.y, c.size.w, c.size.h);
		}else
			c.configure;
	}else{
		XWindowChanges wc;
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
	XCrossingEvent* ev = &e.xcrossing;
	if((ev.mode != NotifyNormal || ev.detail == NotifyInferior) && ev.window != root)
		return;
	Client c = wintoclient(ev.window);
	Monitor m = c ? c.monitor : wintomon(ev.window);
	if(m != monitorActive){
		unfocus(monitorActive.active, true);
		monitorActive = m;
	}else if(!c || c == monitorActive.active)
		return;
	c.focus;
}

void onLeave(XEvent* e){
	if(e.xany.window == monitorActive.dock.window){
		monitorActive.dock.hide;
	}
}

void onExpose(XEvent *e){
	XExposeEvent *ev = &e.xexpose;
	Monitor m = wintomon(ev.window);
	if(ev.count == 0 && m)
		m.draw;
}

void onFocus(XEvent* e){ /* there are some broken focus acquiring clients */
	XFocusChangeEvent *ev = &e.xfocus;
	if(monitorActive.active && ev.window != monitorActive.active.win)
		setfocus(monitorActive.active);
}

void onKey(XEvent* e){
	XKeyEvent *ev = &e.xkey;
	KeySym keysym = XKeycodeToKeysym(dpy, cast(KeyCode)ev.keycode, 0);
	foreach(key; flatman.keys){
		if(keysym == key.keysym && CLEANMASK(key.mod) == CLEANMASK(ev.state) && key.func)
			key.func();
	}
}

void onKeyRelease(XEvent* e){
	KeySym keysym = XLookupKeysym(&e.xkey,0);
	if(keysym == XK_Alt_L){
		monitorActive.dock.hide;
	}
}

void onMapping(XEvent *e){
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
	if(!wintoclient(ev.window)){
		XMapWindow(dpy, ev.window);
		manage(ev.window, &wa);
	}
}

void onMotion(XEvent* e){
	static Monitor mon = null;
	Monitor m;
	XMotionEvent* ev = &e.xmotion;
	if(ev.x_root >= monitorActive.size.w-2){
		monitorActive.dock.show;
	}
	if(ev.window == monitorActive.workspace.split.window)
		monitorActive.workspace.split.onMotion(ev);
	if(ev.window != root)
		return;
	if((m = recttomon(ev.x_root, ev.y_root, 1, 1)) != mon && mon){
		unfocus(monitorActive.active, true);
		monitorActive = m;
		focus(null);
	}
	mon = m;
}

Monitor dirtomon(int dir){
	return monitors[0];
}

void focusmon(int arg){
	Monitor m = dirtomon(arg);
	if(!m)
		return;
	if(m == monitorActive)
		return;
	unfocus(monitorActive.active, false); /* s/true/false/ fixes input focus issues
					in gedit and anjuta */
	monitorActive = m;
	focus(null);
}

void focusstack(int arg){
	monitorActive.workspace.split.focusDir(arg);
	monitorActive.draw;
}

void sizeInc(){
	monitorActive.workspace.split.sizeInc;
}

void sizeDec(){
	monitorActive.workspace.split.sizeDec;
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
	if(XGetWindowProperty(dpy, w, wm.state, 0L, 2L, false, wm.state,
	                      &_real, &format, &n, &extra, cast(ubyte**)&p) != 0)
		return -1;
	if(n != 0)
		result = *p;
	XFree(p);
	return result;
}

bool gettextprop(Window w, Atom atom, ref string text){
	char** list;
	int n;
	XTextProperty name;
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
	uint i, j;
	uint[] modifiers = [ 0, LockMask, numlockmask, numlockmask|LockMask ];
	KeyCode code;
	XUngrabKey(dpy, AnyKey, AnyModifier, root);
	foreach(key; flatman.keys){
		code = XKeysymToKeycode(dpy, key.keysym);
		if(code)
			for(j = 0; j < modifiers.length; j++)
				XGrabKey(dpy, code, key.mod | modifiers[j], root,
					 true, GrabModeAsync, GrabModeAsync);
	}
}

void killclient(){
	if(!monitorActive.active)
		return;
	if(!sendevent(monitorActive.active, wm.delete_)){
		XGrabServer(dpy);
		XSetErrorHandler(&xerrordummy);
		XSetCloseDownMode(dpy, CloseDownMode.DestroyAll);
		XKillClient(dpy, monitorActive.active.win);
		XSync(dpy, false);
		XSetErrorHandler(&xerror);
		XUngrabServer(dpy);
	}
}

void manage(Window w, XWindowAttributes* wa){
	if(!w)
		throw new Exception("No window given");
	auto c = new Client(w);
	Window trans = None;
	XWindowChanges wc;
	updatetitle(c);
	Client t = wintoclient(trans);
	if(XGetTransientForHint(dpy, w, &trans) && t){
		c.monitor = t.monitor;
	}else{
		c.monitor = monitorActive;
		c.applyRules;
	}
	XSelectInput(dpy, w, EnterWindowMask|FocusChangeMask|PropertyChangeMask|StructureNotifyMask|PointerMotionMask|KeyReleaseMask);
	c.grabbuttons(false);
	if(!c.isFloating)
		c.isFloating = c.oldstate = trans != None || c.isfixed;
	if(c.monitor == monitorActive)
		unfocus(monitorActive.active, false);
	c.monitor.add(c);
	XChangeProperty(dpy, root, net.clientList, XA_WINDOW, 32, PropModeAppend,
	                cast(ubyte*)&c.win, 1);
	XMoveResizeWindow(dpy, c.win, c.pos.x, c.pos.y, c.size.w, c.size.h);
	c.setState(NormalState);
	c.focus;
}

void quit(){
	running = false;
}

Monitor recttomon(int x, int y, int w, int h){
	Monitor r = monitorActive;
	int a, area = 0;
	foreach(m; monitors)
		if((a = intersect(x, y, w, h, m)) > area){
			area = a;
			r = m;
		}
	return r;
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
		for(i = 0; i < num; i++){
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

void togglefloating(){
	auto client = monitorActive.active;
	if(!client)
		return;
	//if(client.isfullscreen) /* no support for fullscreen windows */
	//	return;
	client.isFloating = !client.isFloating;
	if(client.isFloating){
		client.moveResize(client.posOld, client.sizeOld);
	}
	monitorActive.remove(client);
	monitorActive.add(client);
	client.focus;
}

void togglefullscreen(){
	auto client = monitorActive.active;
	if(!client)
		return;
	client.setfullscreen(!client.isfullscreen);
}

void onUnmap(XEvent *e){
	XUnmapEvent *ev = &e.xunmap;
	Client c = wintoclient(ev.window);
	if(c){
		if(ev.send_event)
			c.setState(WithdrawnState);
		else
			unmanage(c, true);
	}
}

bool updategeom(){
	bool dirty = false;
	if(!monitors.length){
		monitors = [new Monitor([0,0], [sw,sh])];
		dirty = true;
	}
	if(monitors[0].size.w != sw || monitors[0].size.h != sh){
		dirty = true;
		monitors[0].size.w = monitors[0].size.w = sw;
		monitors[0].size.h = monitors[0].size.h = sh;
	}
	if(dirty){
		monitorActive = monitors[0];
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
	if(!gettextprop(root, XA_WM_NAME, statusText))
		statusText = WM_NAME;
	monitorActive.draw;
}

Client wintoclient(Window w){
	foreach(m; monitors)
		foreach(c; m.allClients)
			if(c.win == w)
				return c;
	return null;
}

Monitor wintomon(Window w){
	int x, y;
	Client c = wintoclient(w);
	if(w == root && getrootptr(&x, &y))
		return recttomon(x, y, 1, 1);
	//foreach(m; monitors)
	//	if(w == m.bar.window || w == m.workspace.split.window)
	//		return m;
	if(c)
		return c.monitor;
	return monitorActive;
}

void mousemove(){
	Client c = monitorActive.active;
	if(!c)
		return;
	XEvent ev;
	Time lasttime = 0;
	if(c.isfullscreen) /* no support moving fullscreen windows by mouse */
		return;
	int ocx = c.pos.x;
	int ocy = c.pos.y;
	if(XGrabPointer(dpy, root, false, MOUSEMASK, GrabModeAsync, GrabModeAsync,
	None, cursor[CurMove].cursor, CurrentTime) != GrabSuccess)
		return;
	int x, y;
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
				int nx = ocx + (ev.xmotion.x - x);
				int ny = ocy + (ev.xmotion.y - y);
				c.moveResize([nx, ny], c.size);
				break;
			default: break;
		}
	} while(ev.type != ButtonRelease);
	XUngrabPointer(dpy, CurrentTime);
}

void mouseresize(){
	int ocx, ocy, nw, nh;
	Client c = monitorActive.active;
	if(!c)
		return;
	Monitor* m;
	XEvent ev;
	Time lasttime = 0;
	if(c.isfullscreen) /* no support resizing fullscreen windows by mouse */
		return;
	ocx = c.pos.x;
	ocy = c.pos.y;
	if(XGrabPointer(dpy, root, false, MOUSEMASK, GrabModeAsync, GrabModeAsync,
	                None, cursor[CurResize].cursor, CurrentTime) != GrabSuccess)
		return;
	XWarpPointer(dpy, None, c.win, 0, 0, 0, 0, c.size.w - 1, c.size.h - 1);
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
				c.moveResize(c.pos, [nw, nh]);
				break;
			default:break;
		}
	} while(ev.type != ButtonRelease);
	XWarpPointer(dpy, None, c.win, 0, 0, 0, 0, c.size.w - 1, c.size.h - 1);
	XUngrabPointer(dpy, CurrentTime);
	while(XCheckMaskEvent(dpy, EnterWindowMask, &ev)){}
}

void cleanup(){
	XUngrabKey(dpy, AnyKey, AnyModifier, root);
	foreach(ws; monitorActive.workspaces){
		foreach(c; ws.clients){
			unmanage(c, false);
		}
		ws.destroy;
	}
	monitorActive.destroy;
	draw.free;
	XSync(dpy, false);
	XSetInputFocus(dpy, PointerRoot, RevertToPointerRoot, CurrentTime);
	XDeleteProperty(dpy, root, net.activeWindow);
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
	try{
		defaultTraceHandler.toString.log;
		"flatman: fatal error: request code=%d, error code=%d".format(ee.request_code, ee.error_code).log;
	}catch {}
	return xerrorxlib(dpy, ee); /* may call exit */
}

extern(C) nothrow int xerrordummy(Display* dpy, XErrorEvent* ee){
	return 0;
}

nothrow extern(C) int xerrorstart(Display *dpy, XErrorEvent* ee){
	try
		writeln("flatman: another window manager is already running");
	catch {}
	_exit(-1);
	return -1;
}
