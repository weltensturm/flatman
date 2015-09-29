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

static ws.x.draw.Cur[CurLast] cursor;
static Display* dpy;
static Monitor monitor;
static Monitor[] monitors;
static Window root;
static Draw draw;

/* variables */
enum broken = "broken";
static string statusText;
static int screen;
static int sw, sh;           /* X display screen geometry width, height */
static int bh, blw = 0;      /* bar geometry */
extern(C) nothrow int function(Display *, XErrorEvent *) xerrorxlib;
extern(C) nothrow int function(Display*) xerrorfatalxlib;
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
	MappingNotify: &onMapping,
	MapRequest: &onMapRequest,
	MotionNotify: &onMotion,
	PropertyNotify: &onProperty,
	UnmapNotify: &onUnmap
];

enum handlerNames = [
	ButtonPress: "ButtonPress",
	ButtonRelease: "ButtonRelease",
	ClientMessage: "ClientMessage",
	ConfigureRequest: "ConfigureRequest",
	ConfigureNotify: "ConfigureNotify",
	DestroyNotify: "DestroyNotify",
	EnterNotify: "EnterNotify",
	Expose: "Expose",
	FocusIn: "FocusIn",
	KeyPress: "KeyPress",
	MappingNotify: "MappingNotify",
	MapRequest: "MapRequest",
	MotionNotify: "MotionNotify",
	PropertyNotify: "PropertyNotify",
	UnmapNotify: "UnmapNotify",
];

void delegate(XEvent*)[int][Window] customHandler;

static bool running = true;
bool restart = false;
Client previousFocus;
Window[] unmanaged;

void log(string s){
	"/tmp/flatman.log".append(s ~ '\n');
	s.writeln;
	stdout.flush;
	//spawnProcess(["notify-send", s]);
}


void main(string[] args){
	try{
		environment["_JAVA_AWT_WM_NONREPARENTING"] = "1";
		if(!setlocale(LC_CTYPE, "") || !XSupportsLocale())
			writeln("warning: no locale support");
		if(args.length >= 2)
			dpy = cast(Display*)(args[$-1].to!long);
		else
			dpy = XOpenDisplay(null);
		"using display %s".format(dpy).log;
		if(!dpy)
			throw new Exception("flatman: cannot open display");
		XSynchronize(dpy, true);
		"checkOtherWm".log;
		checkOtherWm();
		"setup".log;
		setup();
		"scan".log;
		scan();
		"run".log;
		run();
	}catch(Throwable t){
		t.toString.log;
		throw t;
	}
	"cleanup".log;
	try
		cleanup();
	catch(Throwable t)
		"cleanup error %s".format(t).log;
	
	if(restart){
		"restart".log;
		XSetCloseDownMode(dpy, CloseDownMode.RetainTemporary);
		XCloseDisplay(dpy);
		"created display %s".format(dpy).log;
		dpy = XOpenDisplay(null);
		args ~= (cast(long)dpy).to!string;
		spawnProcess(args);
	}else
		XCloseDisplay(dpy);
}


void checkOtherWm(){
	xerrorxlib = XSetErrorHandler(&xerrorstart);
	XSelectInput(dpy, DefaultRootWindow(dpy), SubstructureRedirectMask);
	XSync(dpy, false);
	XSetErrorHandler(&xerror);
	//XSetErrorHandler(xerrorxlib);
	XSync(dpy, false);
}


static Atom[string] atoms;

Atom atom(string n){
	if(n !in atoms)
		atoms[n] = XInternAtom(dpy, n.toStringz, false);
	return atoms[n];
}

void setup(){
	xerrorfatalxlib = XSetIOErrorHandler(&xerrorfatal);

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
	bh = cast(int)(draw.fonts[0].h*1.5).lround;
	/* init atoms */
	/* init cursors */
	cursor[CurNormal] = new ws.x.draw.Cur(dpy, XC_left_ptr);
	cursor[CurResize] = new ws.x.draw.Cur(dpy, XC_sizing);
	cursor[CurMove] = new ws.x.draw.Cur(dpy, XC_fleur);

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
			|PointerMotionMask|EnterWindowMask|StructureNotifyMask
			|PropertyChangeMask;
	XChangeWindowAttributes(dpy, root, CWEventMask|CWCursor, &wa);
	XSelectInput(dpy, root, wa.event_mask);

	registerFunctions;
	registerConfigKeys;

	grabkeys();
	//focus(null);
	updateWorkarea;

	try
		"~/.autostart.sh".expandTilde.spawnProcess;
	catch{}
}


void run(){
	XEvent ev;
	/* main event loop */
	XSync(dpy, false);
	while(running && !XNextEvent(dpy, &ev)){
		if(ev.xany.window in customHandler && ev.type in customHandler[ev.xany.window])
			customHandler[ev.xany.window][ev.type](&ev);
		if(ev.type in handler){
			try{
				//if(![MotionNotify, PropertyNotify].canFind(ev.type))
				//	"event %s".format(handlerNames[ev.type]).log;
				handler[ev.type](&ev);
			}catch(Throwable t){
				t.toString.log;
			}
		}
	}
}

struct EventMaskMapping {
	int mask;
	int type;
}

enum eventMaskMap = [
	EventMaskMapping(ExposureMask, Expose),
	EventMaskMapping(EnterWindowMask, EnterNotify),
	EventMaskMapping(LeaveWindowMask, LeaveNotify),
	EventMaskMapping(ButtonPressMask, ButtonPress),
	EventMaskMapping(ButtonReleaseMask, ButtonRelease),
	EventMaskMapping(PointerMotionMask, MotionNotify)
];


void register(Window window, void delegate(XEvent*)[int] handler){
	int mask;
	foreach(ev, dg; handler){
		foreach(mapping; eventMaskMap){
			if(mapping.type == ev)
				mask |= mapping.mask;
		}
		customHandler[window][ev] = dg;
	}
	XSelectInput(dpy, window, mask);
}


void onButton(XEvent* e){
	uint i, x, click;
	XButtonPressedEvent* ev = &e.xbutton;
	Client c = wintoclient(ev.window);

	click = ClkRootWin;
	/* focus monitor if necessary */
	Monitor m = wintomon(ev.window);
	if(m && m != monitor){
		unfocus(monitor.active, true);
		monitor = m;
		//focus(null);
	}
	if(c){
		c.focus;
		for(i = 0; i < buttons.length; i++)
			if(buttons[i].button == ev.button
			&& CLEANMASK(buttons[i].mask) == CLEANMASK(ev.state))
				buttons[i].func();
	}
}

void onClientMessage(XEvent *e){
	XClientMessageEvent *cme = &e.xclient;
	auto handler = [
		net.currentDesktop: {
			monitor.switchWorkspace(cast(int)cme.data.l[0]);
		},
		net.state: {
			Client c = wintoclient(cme.window);
			if(!c)
				return;
			if(cme.message_type == net.state){
				auto sh = [
					net.fullscreen: {
						bool s = (cme.data.l[0] == _NET_WM_STATE_ADD
			              || (cme.data.l[0] == _NET_WM_STATE_TOGGLE && !c.isfullscreen));
						c.setfullscreen(s);
					},
					net.attention: {
						if(cme.data.l[0] == _NET_WM_STATE_ADD){
							c.requestAttention;
						}
					}
				];
				if(cme.data.l[1] in sh)
					sh[cme.data.l[1]]();
				if(cme.data.l[2] in sh)
					sh[cme.data.l[2]]();
			}
		},
		net.windowActive: {
			Client c = wintoclient(cme.window);
			if(!c || c == monitor.active)
				return;
			if(cme.data.l[0] < 2){
				c.requestAttention;
			}else
				c.focus;
		},
		net.windowDesktop: {
			Client c = wintoclient(cme.window);
			if(!c)
				return;
			c.setWorkspace(cme.data.l[0]);
		},
		net.moveResize: {
			Client c = wintoclient(cme.window);
			if(!c || !c.isFloating)
				return;
			c.moveResize(cme.data.l[0..2].to!(int[2]), cme.data.l[2..4].to!(int[2]));
		},
		net.restack: {
			Client c = wintoclient(cme.window);
			if(!c || c == monitor.active)
				return;
			c.requestAttention;
		}
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
	else if(c){
		auto del = ev.state == PropertyDelete;
		auto ph = [
			XA_WM_TRANSIENT_FOR: {
				if(del)
					return;
				if(!c.isFloating && XGetTransientForHint(dpy, c.win, &trans)){
					c.isFloating = (wintoclient(trans) !is null);
				}
			},
			XA_WM_NORMAL_HINTS: {
				if(del)
					return;
				c.updateSizeHints;
			},
			XA_WM_HINTS: {
				if(del)
					return;
				c.updateWmHints;
				foreach(m; monitors)
					m.draw;
			},
			XA_WM_NAME: {
				if(del)
					return;
				updatetitle(c);
				if(c == c.monitor.active)
					c.monitor.draw;
			},
			net.name: {
				if(del)
					return;
				updatetitle(c);
				if(c == c.monitor.active)
					c.monitor.draw;
			},
			net.state: {
				c.updateType;
			},
			net.windowType: {
				c.updateType;
			},
			net.strutPartial: {
				c.updateStrut;
			},
		];
		if(ev.atom in ph)
			ph[ev.atom]();
	}
}

void onConfigure(XEvent *e){
	Monitor m;
	XConfigureEvent *ev = &e.xconfigure;
	if(ev.window == root){
		bool dirty = (sw != ev.width || sh != ev.height);
		sw = ev.width;
		sh = ev.height;
		if(updategeom() || dirty){
			"updating desktop size".log;
			draw.resize(sw, sh);
			monitor.resize([sw, sh]);
			updateWorkarea;
			restack;
		}
	}
}

void onConfigureRequest(XEvent* e){
	XConfigureRequestEvent* ev = &e.xconfigurerequest;
	Client c = wintoclient(ev.window);
	if(c){
		if(ev.value_mask & CWWidth)
			c.sizeFloating.w = c.size.w;
		if(ev.value_mask & CWHeight)
			c.sizeFloating.h = c.size.h;
		if(ev.value_mask & CWX)
			c.posFloating.x = c.pos.x;
		if(ev.value_mask & CWY)
			c.posFloating.y = c.pos.y;
		if((c.isFloating || c.global) && !c.isfullscreen){
			Monitor m = c.monitor;
			if(ev.value_mask & CWWidth)
				c.size.w = ev.width;
			if(ev.value_mask & CWHeight)
				c.size.h = ev.height;
			if(ev.value_mask & CWX){
				c.pos.x = m.pos.x + ev.x;
				if(!c.global)
					c.pos.x = c.pos.x.min(c.monitor.pos.x+c.monitor.size.w-c.size.w);
			}
			if(ev.value_mask & CWY){
				c.pos.y = m.pos.y + ev.y;
				if(!c.global)
					c.pos.y = c.pos.y.min(c.monitor.pos.y+c.monitor.size.h-c.size.h);
			}
			/+
			if((ev.value_mask & (CWX|CWY))){
				if(!(ev.value_mask & (CWWidth|CWHeight)))
					c.configure;
			}
			+/
			if(c.isVisible)
				XMoveResizeWindow(dpy, c.win, c.pos.x, c.pos.y, c.size.w, c.size.h);
		}else{
			c.configure;
		}
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
	Window curFocus;
	int curRevert;
	XGetInputFocus(dpy, &curFocus, &curRevert);
	if(m != monitor){
		unfocus(monitor.active, true);
		monitor = m;
	}else if(!c || c.win == curFocus)
		return;
	focus(c);
}

void onExpose(XEvent *e){
	XExposeEvent *ev = &e.xexpose;
	Monitor m = wintomon(ev.window);
	if(ev.count == 0 && m)
		m.draw;
}

void onFocus(XEvent* e){ /* there are some broken focus acquiring clients */
	XFocusChangeEvent *ev = &e.xfocus;
	//if(monitor.active && ev.window != monitor.active.win)
	//	setfocus(monitor.active);
	auto c = wintoclient(ev.window);
	if(c && c != active)
		c.requestAttention;
}

void onKey(XEvent* e){
	XKeyEvent *ev = &e.xkey;
	KeySym keysym = XKeycodeToKeysym(dpy, cast(KeyCode)ev.keycode, 0);
	foreach(key; flatman.keys){
		if(keysym == key.keysym && CLEANMASK(key.mod) == CLEANMASK(ev.state) && key.func)
			key.func();
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
	if(!XGetWindowAttributes(dpy, ev.window, &wa) || wa.override_redirect){
		"unmanaged window".log;
		if(!unmanaged.canFind(ev.window))
			unmanaged ~= ev.window;
		return;
	}
	if(!wintoclient(ev.window)){
		try{
			manage(ev.window, &wa);
		}catch(Throwable t){
			t.toString.log;
			XUnmapWindow(dpy, ev.window);
		}
	}
}

void onMotion(XEvent* e){
	static Monitor mon = null;
	Monitor m;
	XMotionEvent* ev = &e.xmotion;
	if(ev.window != root)
		return;
	if((m = recttomon(ev.x_root, ev.y_root, 1, 1)) != mon && mon){
		unfocus(monitor.active, true);
		monitor = m;
		//focus(null);
	}
	mon = m;
}


Client active(){
	return monitor.active;
}

Client[] clients(){
	return monitor.clients;
}

Client[] clientsVisible(){
	return monitor.clientsVisible;
}

void restack(){
	foreach(tabs; monitor.workspace.split.children.to!(Tabs[]))
		XLowerWindow(dpy, tabs.window);
	foreach_reverse(c; clientsVisible)
		c.lower;
	XLowerWindow(dpy, monitor.workspace.split.window);
	XSync(dpy, false);
	XEvent ev;
	while(XCheckMaskEvent(dpy, EnterWindowMask, &ev)){}
}

Monitor dirtomon(int dir){
	return monitors[0];
}

void focusmon(int arg){
	Monitor m = dirtomon(arg);
	if(!m)
		return;
	if(m == monitor)
		return;
	unfocus(monitor.active, false); /* s/true/false/ fixes input focus issues
					in gedit and anjuta */
	monitor = m;
	//focus(null);
}

void sizeInc(){
	monitor.workspace.split.sizeInc;
}

void sizeDec(){
	monitor.workspace.split.sizeDec;
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

void killclient(Client client=null){
	if(!client){
		if(!monitor.active)
			return;
		client = monitor.active;
	}
	if(!sendevent(client, wm.delete_)){
		XGrabServer(dpy);
		XSetErrorHandler(&xerrordummy);
		XSetCloseDownMode(dpy, CloseDownMode.DestroyAll);
		XKillClient(dpy, client.win);
		XSync(dpy, false);
		XSetErrorHandler(&xerror);
		//XSetErrorHandler(xerrorxlib);
		XUngrabServer(dpy);
	}
}

void manage(Window w, XWindowAttributes* wa){
	if(!w)
		throw new Exception("No window given");
	if(wintoclient(w))
		return;
	auto c = new Client(w, monitor);
	Window trans = None;
	XWindowChanges wc;
	updatetitle(c);
	Client t = wintoclient(trans);
	if(XGetTransientForHint(dpy, w, &trans) && t){
		c.monitor = t.monitor;
	}else{
		c.monitor = monitor;
		c.applyRules;
	}
	XSelectInput(dpy, w, EnterWindowMask|FocusChangeMask|PropertyChangeMask|StructureNotifyMask|KeyReleaseMask);
	c.grabbuttons(false);
	if(!c.isFloating)
		c.isFloating = c.oldstate = trans != None || c.isfixed;
	if(c.monitor == monitor)
		unfocus(monitor.active, false);
	c.monitor.add(c, c.originWorkspace);
	if(c.isFloating && c.pos.x == 0 && c.pos.y == 0)
		c.pos = c.monitor.size.a/2 - c.size.a/2;
	XChangeProperty(dpy, root, net.clientList, XA_WINDOW, 32, PropModeAppend,
	                cast(ubyte*)&c.win, 1);
	XMoveResizeWindow(dpy, c.win, c.pos.x, c.pos.y, c.size.w, c.size.h);
	c.setState(NormalState);
	if(c.isVisible && (!active || c.isFloating || c.isfullscreen))
		c.focus;
	else
		c.requestAttention;
}

void quit(){
	running = false;
}

Monitor recttomon(int x, int y, int w, int h){
	Monitor r = monitor;
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
			if(wa.map_state == IsViewable || getstate(wins[i]) == IconicState){
				manage(wins[i], &wa);
			}
		}
		for(i = 0; i < num; i++){
			if(!XGetWindowAttributes(dpy, wins[i], &wa))
				continue;
			if(XGetTransientForHint(dpy, wins[i], &d1)
			&& (wa.map_state == IsViewable || getstate(wins[i]) == IconicState)){
				try{
					manage(wins[i], &wa);
				}catch(Throwable t)
					t.toString.log;
			}
		}
		if(wins)
			XFree(wins);
	}
}

void togglefullscreen(){
	auto client = active;
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
			c.unmanage;
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
		monitor = monitors[0];
		monitor = wintomon(root);
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
	monitor.draw;
}

Client wintoclient(Window w){
	foreach(c; clients)
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
	return monitor;
}

void mousemove(){
	Client c = monitor.active;
	if(!c || !c.isFloating)
		return;
	XEvent ev;
	Time lasttime = 0;
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
				if(ev.xmotion.y < monitor.workspace.split.pos.y+bh && c.isFloating){
					//monitor.workspace.split.dragWindow = monitor.workspace.split.children.length;
					togglefloating;
					XEvent button;
					button.xbutton.button = Mouse.buttonLeft;
					button.xbutton.x = ev.xmotion.x;
					button.xbutton.y = monitor.workspace.split.pos.y+1;
					XSendEvent(dpy, monitor.workspace.split.window, false, PointerMotionMask, &button);
					ev.type = ButtonRelease;
				}
				break;
			default: break;
		}
	} while(ev.type != ButtonRelease);
	XUngrabPointer(dpy, CurrentTime);
}

void mouseresize(){
	int ocx, ocy, nw, nh;
	Client c = monitor.active;
	if(!c || !c.isFloating)
		return;
	Monitor* m;
	XEvent ev;
	Time lasttime = 0;
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
	foreach(ws; monitor.workspaces){
		foreach(c; ws.clients){
			if(!restart)
				killclient(c);
			c.unmanage(true);
		}
		ws.destroy;
	}
	monitor.destroy;
	draw.destroy;
	foreach(c; cursor)
		c.destroy(dpy);
	XSync(dpy, false);
	XSetInputFocus(dpy, PointerRoot, RevertToPointerRoot, CurrentTime);
	XDeleteProperty(dpy, root, net.windowActive);
}


@system @nogc extern(C) nothrow void sigchld(int unused){
	if(signal(SIGCHLD, &sigchld) == SIG_ERR){
		assert(0, "Can't install SIGCHLD handler");
	}
	while(0 < waitpid(-1, null, WNOHANG)){}
}

enum XRequestCode {
    X_CreateWindow                   = 1,
    X_ChangeWindowAttributes         = 2,
    X_GetWindowAttributes            = 3,
    X_DestroyWindow                  = 4,
    X_DestroySubwindows              = 5,
    X_ChangeSaveSet                  = 6,
    X_ReparentWindow                 = 7,
    X_MapWindow                      = 8,
    X_MapSubwindows                  = 9,
    X_UnmapWindow                   = 10,
    X_UnmapSubwindows               = 11,
    X_ConfigureWindow               = 12,
    X_CirculateWindow               = 13,
    X_GetGeometry                   = 14,
    X_QueryTree                     = 15,
    X_InternAtom                    = 16,
    X_GetAtomName                   = 17,
    X_ChangeProperty                = 18,
    X_DeleteProperty                = 19,
    X_GetProperty                   = 20,
    X_ListProperties                = 21,
    X_SetSelectionOwner             = 22,
    X_GetSelectionOwner             = 23,
    X_ConvertSelection              = 24,
    X_SendEvent                     = 25,
    X_GrabPointer                   = 26,
    X_UngrabPointer                 = 27,
    X_GrabButton                    = 28,
    X_UngrabButton                  = 29,
    X_ChangeActivePointerGrab       = 30,
    X_GrabKeyboard                  = 31,
    X_UngrabKeyboard                = 32,
    X_GrabKey                       = 33,
    X_UngrabKey                     = 34,
    X_AllowEvents                   = 35,
    X_GrabServer                    = 36,
    X_UngrabServer                  = 37,
    X_QueryPointer                  = 38,
    X_GetMotionEvents               = 39,
    X_TranslateCoords               = 40,
    X_WarpPointer                   = 41,
    X_SetInputFocus                 = 42,
    X_GetInputFocus                 = 43,
    X_QueryKeymap                   = 44,
    X_OpenFont                      = 45,
    X_CloseFont                     = 46,
    X_QueryFont                     = 47,
    X_QueryTextExtents              = 48,
    X_ListFonts                     = 49,
    X_ListFontsWithInfo             = 50,
    X_SetFontPath                   = 51,
    X_GetFontPath                   = 52,
    X_CreatePixmap                  = 53,
    X_FreePixmap                    = 54,
    X_CreateGC                      = 55,
    X_ChangeGC                      = 56,
    X_CopyGC                        = 57,
    X_SetDashes                     = 58,
    X_SetClipRectangles             = 59,
    X_FreeGC                        = 60,
    X_ClearArea                     = 61,
    X_CopyArea                      = 62,
    X_CopyPlane                     = 63,
    X_PolyPoint                     = 64,
    X_PolyLine                      = 65,
    X_PolySegment                   = 66,
    X_PolyRectangle                 = 67,
    X_PolyArc                       = 68,
    X_FillPoly                      = 69,
    X_PolyFillRectangle             = 70,
    X_PolyFillArc                   = 71,
    X_PutImage                      = 72,
    X_GetImage                      = 73,
    X_PolyText8                     = 74,
    X_PolyText16                    = 75,
    X_ImageText8                    = 76,
    X_ImageText16                   = 77,
    X_CreateColormap                = 78,
    X_FreeColormap                  = 79,
    X_CopyColormapAndFree           = 80,
    X_InstallColormap               = 81,
    X_UninstallColormap             = 82,
    X_ListInstalledColormaps        = 83,
    X_AllocColor                    = 84,
    X_AllocNamedColor               = 85,
    X_AllocColorCells               = 86,
    X_AllocColorPlanes              = 87,
    X_FreeColors                    = 88,
    X_StoreColors                   = 89,
    X_StoreNamedColor               = 90,
    X_QueryColors                   = 91,
    X_LookupColor                   = 92,
    X_CreateCursor                  = 93,
    X_CreateGlyphCursor             = 94,
    X_FreeCursor                    = 95,
    X_RecolorCursor                 = 96,
    X_QueryBestSize                 = 97,
    X_QueryExtension                = 98,
    X_ListExtensions                = 99,
    X_ChangeKeyboardMapping         = 100,
    X_GetKeyboardMapping            = 101,
    X_ChangeKeyboardControl         = 102,
    X_GetKeyboardControl            = 103,
    X_Bell                          = 104,
    X_ChangePointerControl          = 105,
    X_GetPointerControl             = 106,
    X_SetScreenSaver                = 107,
    X_GetScreenSaver                = 108,
    X_ChangeHosts                   = 109,
    X_ListHosts                     = 110,
    X_SetAccessControl              = 111,
    X_SetCloseDownMode              = 112,
    X_KillClient                    = 113,
    X_RotateProperties              = 114,
    X_ForceScreenSaver              = 115,
    X_SetPointerMapping             = 116,
    X_GetPointerMapping             = 117,
    X_SetModifierMapping            = 118,
    X_GetModifierMapping            = 119,
    X_NoOperation                   = 127
}

/* There's no way to check accesses to destroyed windows, thus those cases are
 * ignored (especially on UnmapNotify's).  Other types of errors call Xlibs
 * default error handler, which may call exit.  */
extern(C) nothrow int xerror(Display* dpy, XErrorEvent* ee){
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
		"flatman: X11 error: request code=%d %s, error code=%d %s".format(ee.request_code, cast(XRequestCode)ee.request_code, ee.error_code, cast(XErrorCode)ee.error_code).log;
	}catch {}
	return xerrorxlib(dpy, ee); /* may call exit */
}

extern(C) nothrow int xerrorfatal(Display* dpy){
	try{
		defaultTraceHandler.toString.log;
		"flatman: X11 fatal i/o error".log;
	}catch{}
	return xerrorfatalxlib(dpy);
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
