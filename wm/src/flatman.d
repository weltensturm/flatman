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


T cleanMask(T)(T mask){
	return mask & ~(numlockmask|LockMask) & (ShiftMask|ControlMask|Mod1Mask|Mod2Mask|Mod3Mask|Mod4Mask|Mod5Mask);
}

auto width(T)(T x){
	return x.size.w + 2 * x.bw;
}

auto height(T)(T x){
	return x.size.h + 2 * x.bw;
}

enum {
	CurNormal,
	CurResize,
	CurMove,
	CurLast
};


struct WmAtoms {
	@("WM_PROTOCOLS") Atom protocols;
	@("WM_DELETE_WINDOW") Atom delete_;
	@("WM_STATE") Atom state;
	@("WM_HINTS") Atom hints;
	@("WM_TAKE_FOCUS") Atom takeFocus;
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

class Dragging {
	Client client;
	int[2] offset;
	int width;
	void delegate(int[2]) drag;
	void delegate() drop;
}


enum handler = [
	ButtonPress: &onButton,
	ButtonRelease: &onButtonRelease,
	MotionNotify: &onMotion,
	ClientMessage: &onClientMessage,
	ConfigureRequest: &onConfigureRequest,
	ConfigureNotify: (e) => onConfigure(e.xconfigure.window, e.xconfigure.width, e.xconfigure.height),
	CreateNotify: &onCreate,
	DestroyNotify: &onDestroy,
	EnterNotify: &onEnter,
	Expose: &onExpose,
	FocusIn: &onFocus,
	KeyPress: &onKey,
	MappingNotify: &onMapping,
	MapRequest: &onMapRequest,
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

struct TimedEvent {
	double time;
	void delegate() event;
}

TimedEvent[] schedule;

WmAtoms wm;

void delegate(XEvent*)[int][Window] customHandler;

static bool running = true;
bool restart = false;
Client previousFocus;
Window[] unmanaged;

static string[Atom] names;

enum broken = "broken";
static string statusText;
static int screen;
static int sw, sh;           /* X display screen geometry width, height */
extern(C) nothrow int function(Display *, XErrorEvent *) xerrorxlib;
extern(C) nothrow int function(Display*) xerrorfatalxlib;
static uint numlockmask = 0;

static ws.x.draw.Cur[CurLast] cursor;
static Display* dpy;
static Monitor monitor;
static Monitor[] monitors;
static Window root;

static Atom[string] atoms;

Dragging dragging;

bool redraw;
bool queueRestack;


Atom atom(string n){
	if(n !in atoms)
		atoms[n] = XInternAtom(dpy, n.toStringz, false);
	return atoms[n];
}

string name(Atom atom){
	if(atom in names)
		return names[atom];
	auto data = XGetAtomName(dpy, atom);
	auto text = data.to!string;
	names[atom] = text;
	XFree(data);
	return text;
}

void fillAtoms(T)(ref T data){
	foreach(n; FieldNameTuple!T){
		mixin("data." ~ n ~ " = atom(__traits(getAttributes, data."~n~")[0]);");
	}
}

void main(string[] args){
	"===== FLATMAN =====".log;
	"args %s".format(args).log;
	try{

		environment["_JAVA_AWT_WM_NONREPARENTING"] = "1";
		if(!setlocale(LC_CTYPE, "") || !XSupportsLocale())
			"warning: no locale support".log;

		auto cfgReload = {
			["notify-send", "Loading config"].execute;
			try{
				cfg.load;
			}catch(Exception e){
				["notify-send", e.toString].execute;
				writeln(e);
			}
		};
		cfgReload();
		Inotify.watch("/etc/flatman/config.ws", (d,f,m){
			cfgReload();
		});
		Inotify.watch("~/.config/flatman/config.ws".expandTilde, (d,f,m){
			cfgReload();
		});

		dpy = XOpenDisplay(null);
		if(!dpy)
			throw new Exception("cannot open display");
		checkOtherWm;
		setup(args[$-1] != "restarting");
		scan;
		run;
	}catch(Throwable t){
		t.toString.log;
		throw t;
	}
	try
		cleanup();
	catch(Throwable t)
		"cleanup error %s".format(t).log;
	
	if(restart){
		"restart".log;
		XSetCloseDownMode(dpy, CloseDownMode.RetainTemporary);
		if(args[$-1] != "restarting")
			args ~= "restarting";
		execvp(args[0], args);
		"execv failed".log;
	}else
		XCloseDisplay(dpy);
	exit(0);
}


void checkOtherWm(){
	xerrorxlib = XSetErrorHandler(&xerrorstart);
	XSelectInput(dpy, DefaultRootWindow(dpy), SubstructureRedirectMask);
	XSync(dpy, false);
	XSetErrorHandler(&xerror);
	//XSetErrorHandler(xerrorxlib);
	XSync(dpy, false);
}

void setup(bool autostart){
	xerrorfatalxlib = XSetIOErrorHandler(&xerrorfatal);

	/* init screen */
	screen = DefaultScreen(dpy);
	root = XDefaultRootWindow(dpy);

	//wm = new CompositeManager;

	sw = DisplayWidth(dpy, screen);
	sh = DisplayHeight(dpy, screen);
	root = RootWindow(dpy, screen);

	/* init atoms */
	/* init cursors */
	cursor[CurNormal] = new ws.x.draw.Cur(dpy, XC_left_ptr);
	cursor[CurResize] = new ws.x.draw.Cur(dpy, XC_sizing);
	cursor[CurMove] = new ws.x.draw.Cur(dpy, XC_fleur);

	fillAtoms(wm);
	fillAtoms(net);

	//updatebars();
	updateMonitors();
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
	setSupportingWm;

	if(autostart){
		cfg.autostart.each!((command){
			if(!command.strip.length)
				return;
			"autostart '%s'".format(command).log;
			task({
				auto pipes = pipeShell(command);
				auto reader = task({
					foreach(line; pipes.stdout.byLine){
						if(line.length)
							"STDOUT \"%s\": %s".format(command, line).log;
					}
				});
				reader.executeInNewThread;
				foreach(line; pipes.stderr.byLine){
					if(line.length)
						"STDERR \"%s\": %s".format(command, line).log;
				}
				reader.yieldForce;
				"QUIT: %s".format(command).log;
			}).executeInNewThread;
		});	
	}
}

void scan(){
	uint num;
	Window d1, d2;
	Window* wins;
	XWindowAttributes wa;
	if(XQueryTree(dpy, root, &d1, &d2, &wins, &num)){
		if(wins){

			Window[][AtomType!XA_CARDINAL] workspaces;

			foreach(w; wins[0..num]){
				"scan found %s %s".format(w, wa).log;
				if(
					!wintoclient(w)
					&& XGetWindowAttributes(dpy, w, &wa)
					&& !wa.override_redirect
					&& (wa.map_state == IsViewable
						|| getstate(w) == IconicState)
				){
					"scan manages %s".format(w).log;
					long workspace;
					try {
						workspace = w.getprop!XA_CARDINAL(net.windowDesktop);
					}catch(Exception e){
						e.writeln;
					}
					workspaces[workspace] ~= w;
				}
			}
			XFree(wins);

			writeln(object.keys(workspaces));

			foreach(ws; object.keys(workspaces))
				foreach(monitor; monitors)
					monitor.newWorkspace(ws);

			foreach(ws; workspaces)
				foreach(win; ws){
					XWindowAttributes wa;
					XGetWindowAttributes(dpy, win, &wa);
					manage(win, &wa);
				}

		}
	}
}

void run(){
	XEvent ev;
	
	while(running){
		XSync(dpy, false);
		while(XPending(dpy)){
			XNextEvent(dpy, &ev);
			if(ev.xany.window in customHandler && ev.type in customHandler[ev.xany.window])
				customHandler[ev.xany.window][ev.type](&ev);
			if(ev.type in handler){
				try{
					handler[ev.type](&ev);
				}catch(Throwable t){
					t.toString.log;
					["notify-send", t.toString].execute;
				}
			}
		}
		Inotify.update;

		if(redraw){
			monitor.onDraw;
			redraw = false;
		}

		TimedEvent[] newSchedule;
		foreach(e; schedule){
			if(e.time < now)
				e.event();
			else
				newSchedule ~= e;
		}
		schedule = newSchedule;

		if(queueRestack){
			"restack".log;
			XGrabServer(dpy);
			foreach(monitor; monitors){
				monitor.restack;
				if(monitor.active && monitor.active.isfullscreen)
					monitor.active.raise;
			}
			foreach(w; unmanaged)
				XRaiseWindow(dpy, w);
			XSync(dpy, false);
			while(XCheckMaskEvent(dpy, EnterWindowMask|LeaveWindowMask, &ev)){}
			XUngrabServer(dpy);
			queueRestack = false;
		}
		sleep(1/120.0);
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

void unregister(Window window){
	customHandler.remove(window);
}

void onButton(XEvent* e){
	uint i, x;
	XButtonPressedEvent* ev = &e.xbutton;
	Client c = wintoclient(ev.window);

	/* focus monitor if necessary */
	Monitor m = wintomon(ev.window);
	if(m && m != monitor){
		if(monitor && monitor.active)
			monitor.active.unfocus(true);
		monitor = m;
		//focus(null);
	}
	if(c){
		"%s ev %s".format(c, "onButton").log;
		if(c.isFloating)
			c.parent.to!Floating.raise(c);
		c.focus;
		foreach(bind; buttons)
			if(bind.button == ev.button && cleanMask(bind.mask) == cleanMask(ev.state))
				bind.func();
	}
}

void onButtonRelease(XEvent* e){
	XButtonReleasedEvent* ev = &e.xbutton;
	if(dragging){
		if(ev.button == Mouse.buttonLeft){
			dragging = null;
			XUngrabPointer(dpy, CurrentTime);
		}
	}
}

void onClientMessage(XEvent *e){
	XClientMessageEvent *cme = &e.xclient;
	auto c = wintoclient(cme.window);
	if(c)
		"%s ev %s %s".format(c, "ClientMessage", cme.message_type.name).log;
	auto handler = [
		net.currentDesktop: {
			foreach(monitor; monitors){
				if(cme.data.l[2] > 0)
					monitor.newWorkspace(cme.data.l[0]);
				monitor.switchWorkspace(cast(int)cme.data.l[0]);
			}
		},
		net.state: {
			if(!c)
				return;
			auto sh = [
				net.fullscreen: {
					bool s = (cme.data.l[0] == _NET_WM_STATE_ADD
		              || (cme.data.l[0] == _NET_WM_STATE_TOGGLE && !c.isfullscreen));
					c.setFullscreen(s);
				},
				net.attention: {
					c.requestAttention;
				}
			];
			if(cme.data.l[1] in sh)
				sh[cme.data.l[1]]();
			if(cme.data.l[2] in sh)
				sh[cme.data.l[2]]();
		},
		net.windowActive: {
			if(!c || c == monitor.active)
				return;
			if(cme.data.l[0] < 2){
				c.requestAttention;
			}else
				c.focus;
		},
		net.windowDesktop: {
			if(!c)
				return;
			if(cme.data.l[2] == 1)
				foreach(monitor; monitors){
					monitor.newWorkspace(cme.data.l[0]);
				}
			c.setWorkspace(cme.data.l[0]);
		},
		net.moveResize: {
			if(!c || !c.isFloating)
				return;
			c.moveResize(cme.data.l[0..2].to!(int[2]), cme.data.l[2..4].to!(int[2]));
		},
		net.restack: {
			if(!c || c == monitor.active)
				return;
			c.requestAttention;
		},
		wm.state: {
			if(cme.data.l[0] == IconicState){
				"iconify %s".format(c).log;
				/+
				c.hide;
				c.unmanage(true);
				+/
			}
		}
	];
	if(cme.message_type in handler)
		handler[cme.message_type]();
	else
		"unknown message type %s".format(cme.message_type).log;
}

void onProperty(XEvent *e){
	XPropertyEvent* ev = &e.xproperty;
	if(![XA_WM_TRANSIENT_FOR, XA_WM_NORMAL_HINTS, XA_WM_HINTS, XA_WM_NAME, net.name, net.state, net.windowType, net.strutPartial, net.icon].canFind(ev.atom))
		return;
	Client c = wintoclient(ev.window);
	Window trans;
	if((ev.window == root) && (ev.atom == XA_WM_NAME))
		updatestatus();
	else if(c){
		//"%s ev %s %s".format(c, "onProperty", ev.atom.name).log;
		auto del = ev.state == PropertyDelete;
		auto ph = [
			XA_WM_TRANSIENT_FOR: {
				if(del)
					return;
				if(!c.isFloating && XGetTransientForHint(dpy, c.orig, &trans)){
					c.isFloating = (wintoclient(trans) !is null);
				}
			},
			XA_WM_NORMAL_HINTS: {
				if(del)
					return;
				c.updateSizeHints;
			},
			XA_WM_HINTS: {
				c.updateWmHints;
				redraw = true;
			},
			XA_WM_NAME: {
				if(del)
					return;
				c.updateTitle;
				if(c == c.monitor.active)
					redraw = true;
			},
			net.name: {
				if(del)
					return;
				c.updateTitle;
				if(c == c.monitor.active)
					redraw = true;
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
			net.icon: {
				c.updateIcon;
			},
		];
		if(ev.atom in ph)
			ph[ev.atom]();
	}
}

void onConfigure(Window window, int width, int height){
	if(window == root){
		bool dirty = (sw != width || sh != height);
		sw = width;
		sh = height;
		if(updateMonitors() || dirty){
			updateWorkarea;
			restack;
		}
	}
}

void onConfigureRequest(XEvent* e){
	XConfigureRequestEvent* ev = &e.xconfigurerequest;
	Client c = wintoclient(ev.window);
	if(c){
		"%s ev %s".format(c, "ConfigureRequest").log;
		c.sizeFloating.w = ev.width;
		c.sizeFloating.h = ev.height;
		c.posFloating.x = ev.x;
		c.posFloating.y = ev.y;
		if(c.isFloating || c.global){
			c.moveResize(c.posFloating, c.sizeFloating);
		}
	}else{
		"(u%s) ev %s".format(ev.window, "ConfigureRequest").log;
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
}

void onCreate(XEvent* e){
	auto ev = &e.xcreatewindow;
	if(ev.override_redirect){
		x11.X.Window[] wmWindows;
		foreach(ws; monitor.workspaces){
			foreach(separator; ws.split.separators)
				wmWindows ~= separator.window;
		}
		"unmanaged window".log;
		if(!(unmanaged ~ wmWindows).canFind(ev.window))
			unmanaged ~= ev.window;
	}
}

void onDestroy(XEvent* e){
	XDestroyWindowEvent* ev = &e.xdestroywindow;
	if(unmanaged.canFind(ev.window))
		unmanaged = unmanaged.without(ev.window);
	Client c = wintoclient(ev.window);
	if(c)
		c.unmanage(true);
}

void onEnter(XEvent* e){
	if(dragging)
		return;
	XCrossingEvent* ev = &e.xcrossing;
	if((ev.mode != NotifyNormal || ev.detail == NotifyInferior) && ev.window != root)
		return;
	Client c = wintoclient(ev.window);
	Monitor m = c ? c.monitor : wintomon(ev.window);
	Window curFocus;
	int curRevert;
	XGetInputFocus(dpy, &curFocus, &curRevert);
	if(m != monitor){
		if(monitor && monitor.active)
			monitor.active.unfocus(true);
		monitor = m;
	}
	if(!c || c.win == curFocus)
		return;
	c.focus;
}

void onExpose(XEvent *e){
	XExposeEvent *ev = &e.xexpose;
	Monitor m = wintomon(ev.window);
	if(ev.count == 0 && m)
		redraw = true;
}

void onFocus(XEvent* e){ /* there are some broken focus acquiring clients */
	//XFocusChangeEvent *ev = &e.xfocus;
	//if(monitor.active && ev.window != monitor.active.win)
	//	setfocus(monitor.active);
	//auto c = wintoclient(ev.window);
	//if(c && c != active)
	//	c.requestAttention;
}

void onKey(XEvent* e){
	XKeyEvent *ev = &e.xkey;
	KeySym keysym = XKeycodeToKeysym(dpy, cast(KeyCode)ev.keycode, 0);
	"key %s".format(keysym).log;
	foreach(key; flatman.keys){
		if(keysym == key.keysym && cleanMask(key.mod) == cleanMask(ev.state) && key.func)
			key.func();
	}
}

void onKeyRelease(XEvent* e){
	XKeyEvent *ev = &e.xkey;
	KeySym keysym = XKeycodeToKeysym(dpy, cast(KeyCode)ev.keycode, 0);
	"key release %s".format(keysym).log;
	foreach(key; flatman.keys){
		if(keysym == key.keysym && cleanMask(key.mod) == cleanMask(ev.state) && key.func)
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
		return;
	}
	if(!wintoclient(ev.window) && ev.parent == root){
		try{
			manage(ev.window, &wa);
			XMapWindow(dpy, ev.window);
		}catch(Throwable t){
			t.toString.log;
			XUnmapWindow(dpy, ev.window);
		}
	}
}

void onMotion(XEvent* e){
	auto ev = &e.xmotion;
	/+
	if(ev.window != root && (!active || ev.window != active.win && ev.subwindow != active.win)){
		auto c = wintoclient(ev.window);
		if(c)
			c.focus;
	}
	+/
	static Monitor mon = null;
	Monitor m;
	if((m = findMonitor([ev.x_root, ev.y_root])) != mon && mon){
		if(monitor && monitor.active)
			monitor.active.unfocus(true);
		monitor = m;
		//focus(null);
	}
	mon = m;
	if(dragging){
		if(!clients.canFind(dragging.client))
			return;
		if(
			(ev.y_root <= dragging.client.monitor.pos.y+cfg.tabsTitleHeight)
					== dragging.client.isFloating
				&& ev.x_root > monitor.pos.x+1
				&& ev.x_root < monitor.pos.x+monitor.size.w-1)
			dragging.client.togglefloating;

		if(dragging.client.isFloating){
			auto monitor = findMonitor(dragging.client.pos);
			if(monitor != dragging.client.monitor){
				dragging.client.monitor.remove(dragging.client);
				monitor.add(dragging.client);
			}
			if(ev.x_root <= monitor.pos.x+1){
				monitor.remove(dragging.client);
				dragging.client.isFloating = false;
				monitor.workspace.split.add(dragging.client, -1);
				return;
			}else if(ev.x_root >= monitor.pos.x+monitor.size.w-1){
				monitor.remove(dragging.client);
				dragging.client.isFloating = false;
				monitor.workspace.split.add(dragging.client, monitor.workspace.split.clients.length);
				return;
			}
			auto x = dragging.offset.x * dragging.client.size.w / dragging.width;
			dragging.client.moveResize([ev.x_root, ev.y_root].a + [x, dragging.offset.y], dragging.client.sizeFloating);
		}
		else
			{}
	}
}

void drag(Client client, int[2] offset){
	dragging = new Dragging;
	dragging.client = client;
	dragging.offset = offset;
	dragging.width = client.size.w;
	XGrabPointer(
				dpy,
				root,
				true,
				ButtonPressMask |
						ButtonReleaseMask |
						PointerMotionMask |
						FocusChangeMask |
						EnterWindowMask |
						LeaveWindowMask,
				GrabModeAsync,
				GrabModeAsync,
				None,
				None,
				CurrentTime);
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
	queueRestack = true;
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

void grabKey(Key key){
	auto modifiers = [ 0, LockMask, numlockmask, numlockmask|LockMask ];
	auto code = XKeysymToKeycode(dpy, key.keysym);
	foreach(mod; modifiers)
		XGrabKey(dpy, code, key.mod | mod, root, true, GrabModeAsync, GrabModeAsync);
}

void grabkeys(){
	updatenumlockmask();
	uint i, j;
	KeyCode code;
	XUngrabKey(dpy, AnyKey, AnyModifier, root);
	foreach(key; flatman.keys){
		grabKey(key);
	}
	//grabKey(Key(XK_Alt_L));
    //XGrabKeyboard(dpy, root, true, GrabModeAsync, GrabModeAsync, CurrentTime);
}

void killclient(Client client=null){
	if(!client){
		if(!monitor.active)
			return;
		client = monitor.active;
	}
	if(!client.sendEvent(wm.delete_)){
		XGrabServer(dpy);
		XSetErrorHandler(&xerrordummy);
		XSetCloseDownMode(dpy, CloseDownMode.DestroyAll);
		XKillClient(dpy, client.win);
		XSync(dpy, false);
		XSetErrorHandler(&xerror);
		//XSetErrorHandler(xerrorxlib);
		XUngrabServer(dpy);
	}
	client.unmanage;
}

void manage(Window w, XWindowAttributes* wa){
	if(!w)
		throw new Exception("No window given");
	if(wintoclient(w))
		return;
	auto c = new Client(w, monitor);
	XSelectInput(dpy, w, EnterWindowMask|FocusChangeMask|PropertyChangeMask|StructureNotifyMask|KeyReleaseMask|KeyPressMask|PointerMotionMask);
	c.monitor.add(c, c.originWorkspace);
	if(c.isFloating && c.pos.x == 0 && c.pos.y == 0)
		c.pos = c.monitor.size.a/2 - c.size.a/2;
	XChangeProperty(dpy, root, net.clientList, XA_WINDOW, 32, PropModeAppend,
	                cast(ubyte*)&c.win, 1);
	//c.moveResize(c.pos, c.size);
	//c.configure;
	c.updateStrut;
	if(c.isVisible)
		c.focus;
	else
		c.requestAttention;
}

void quit(){
	running = false;
}

void togglefullscreen(){
	auto client = active;
	if(!client)
		return;
	client.setFullscreen(!client.isfullscreen);
}

void onUnmap(XEvent *e){
	XUnmapEvent *ev = &e.xunmap;
	Client c = wintoclient(ev.window);
	if(c){
		c.unmanage(!c.hidden);
	}
}

bool updateMonitors(){
	bool dirty = false;
	auto screens = screens;
	while(monitors.length != screens.length){
		if(monitors.length < screens.length)
			monitors ~= [new Monitor([0,0], [1,1])];
		else {
			foreach(c; monitors[$-1].clients){
				monitors[$-1].remove(c);
				monitors[$-2].add(c);
			}
			monitors = monitors[0..$-1];
		}
	}
	foreach(i, monitor; monitors){
		auto screen = screens[i.to!int];
		if(monitor.size != [screen.w, screen.h] || monitor.pos != [screen.x, screen.y]){
			"updating desktop size".log;
			dirty = true;
			writeln(screen);
			monitor.pos = [screen.x, screen.y];
			monitor.resize([screen.w, screen.h]);
		}
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
	redraw = true;
}

Client wintoclient(Window w){
	foreach(c; clients)
		if(c.win == w || c.orig == w)
			return c;
	return null;
}

Monitor wintomon(Window w){
	int x, y;
	Client c = wintoclient(w);
	if(w == root && getrootptr(&x, &y))
		return findMonitor([x, y]);
	//foreach(m; monitors)
	//	if(w == m.bar.window || w == m.workspace.split.window)
	//		return m;
	if(c)
		return c.monitor;
	return monitor;
}

void mousemove(){
	Client c = monitor.active;
	if(!c || !c.isFloating || c.isfullscreen)
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
				break;
			default: break;
		}
	} while(ev.type != ButtonRelease);
	XUngrabPointer(dpy, CurrentTime);
}

void mouseresize(){
	int ocx, ocy, nw, nh;
	Client c = monitor.active;
	if(!c || !c.isFloating || c.isfullscreen)
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
	"CLEANUP".log;
	XUngrabKey(dpy, AnyKey, AnyModifier, root);
	foreach(ws; monitor.workspaces){
		foreach(c; ws.clients){
			if(restart){
				XMapWindow(dpy, c.win);
				XMoveWindow(dpy, c.win, c.pos.x, c.pos.y);
				"%s resetting".format(c).log;
			}else
				killclient(c);
		}
	}
	monitor.destroy;
	foreach(c; cursor)
		c.destroy(dpy);
	XSync(dpy, false);
	XSetInputFocus(dpy, PointerRoot, RevertToPointerRoot, CurrentTime);
	XDeleteProperty(dpy, root, net.windowActive);
	taskPool.stop;
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
		"flatman: another window manager is already running".log;
	catch {}
	_exit(-1);
	return -1;
}
