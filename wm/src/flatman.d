module flatman.flatman;


import flatman;


__gshared:


// TODO: fuck x11-master
enum Success = 0;
enum XC_fleur = 52;
enum XC_left_ptr = 68;
enum XC_sizing = 120;
enum CompositeRedirectManual = 1;
// endtodo


enum WM_NAME = "flatman";


enum {
	CurNormal,
	CurResize,
	CurMove,
	CurLast
};


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

struct TimedEvent {
	double time;
	void delegate() event;
}

TimedEvent[] schedule;

void delegate(XEvent*)[int][Window] customHandler;

bool running = true;
bool restart = false;
Client previousFocus;
Window[] unmanaged;

int screen;
int sw, sh;           /* X display screen geometry width, height */
extern(C) nothrow int function(Display *, XErrorEvent *) xerrorxlib;
extern(C) nothrow int function(Display*) xerrorfatalxlib;
uint numlockmask = 0;

ws.x.draw.Cur[CurLast] cursor;
Display* dpy;
Monitor monitor;
Monitor[] monitors;
Window root;

bool redraw;
bool queueRestack;
bool updateStrut;

int[2] rootSize = [1,1];


void main(string[] args){
	(Log.BOLD ~ Log.GREEN ~ "===== FLATMAN =====").log;
	"args %s".format(args).log;
	try{
		auto configs = ["/etc/flatman/config.ws", "~/.config/flatman/config.ws"];
		environment["_JAVA_AWT_WM_NONREPARENTING"] = "1";
		if(!setlocale(LC_CTYPE, "") || !XSupportsLocale())
			"warning: no locale support".log;

		["mkdir", "-p", "~/.config/flatman".expandTilde].execute;
		["touch", "~/.config/flatman/config.ws".expandTilde].execute;

		auto cfgReload = {
			["notify-send", "Loading config"].execute;
			try{
				config.fillConfigNested(configs);
				registerConfigKeys;
			}catch(Exception e){
				Log.fallback(Log.RED ~ e.to!string);
				["notify-send", e.toString].execute;
			}
		};
		cfgReload();
		foreach(file; configs){
			file = file.expandTilde;
			if(!file.exists)
				continue;
			Inotify.watch(file, (d,f,m){
				cfgReload();
			});
		}

		dpy = XOpenDisplay(null);
		if(!dpy)
			throw new Exception("cannot open display");
		getDisplay = () => dpy;
		checkOtherWm;
		setup(args[$-1] != "restarting");
		scan;
		run;
	}catch(Throwable t){
		"FATAL ERROR".log;
		Log.error(t.toString);
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
	eventsInit;

	xerrorfatalxlib = XSetIOErrorHandler(&xerrorfatal);

	screen = DefaultScreen(dpy);
	root = XDefaultRootWindow(dpy);

	sw = DisplayWidth(dpy, screen);
	sh = DisplayHeight(dpy, screen);
	rootSize = [sw, sh];
	root = RootWindow(dpy, screen);

	cursor[CurNormal] = new ws.x.draw.Cur(dpy, XC_left_ptr);
	cursor[CurResize] = new ws.x.draw.Cur(dpy, XC_sizing);
	cursor[CurMove] = new ws.x.draw.Cur(dpy, XC_fleur);

	wm.fillAtoms;
	motif.fillAtoms;

	updateMonitors();
	
	XDeleteProperty(dpy, root, Atoms._NET_SUPPORTED);
	foreach(n; netSupported)
		XChangeProperty(dpy, root, Atoms._NET_SUPPORTED, XA_ATOM, 32, PropModeAppend, cast(ubyte*)&n, 1);
	XDeleteProperty(dpy, root, Atoms._NET_CLIENT_LIST);

	updateDesktopCount;
	updateCurrentDesktop;
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
	updateWorkarea;
	setSupportingWm;
	dragInit;

	if(autostart){
		config.autostart.each!((command){
			if(!command.strip.length)
				return;
			"autostart '%s'".format(command).log;
			task({
				auto pipes = pipeShell(command);
				auto reader = task({
					foreach(line; pipes.stdout.byLineCopy){
						if(line.length)
							Log.fallback(Log.YELLOW ~ " \"%s\": %s".format(command, line));
					}
				});
				reader.executeInNewThread;
				foreach(line; pipes.stderr.byLineCopy){
					if(line.length)
						Log.fallback((Log.RED ~ " \"%s\": %s".format(command, line)));
				}
				reader.yieldForce;
				Log.fallback("QUIT: %s".format(command));
				pipes.pid.wait;
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
						workspace = w.getprop!XA_CARDINAL(Atoms._NET_WM_DESKTOP);
					}catch(Exception e){
						Log.fallback(Log.RED ~ e.to!string);
					}
					workspaces[workspace] ~= w;
				}
			}
			XFree(wins);

			writeln(object.keys(workspaces));

			foreach(ws; object.keys(workspaces))
				newWorkspace(ws);

			foreach(ws; workspaces)
				foreach(win; ws){
					XWindowAttributes wa;
					XGetWindowAttributes(dpy, win, &wa);
					manage(win, &wa);
				}

		}
	}
}


void loop(){
	XEvent ev;
	XSync(dpy, false);
	while(XPending(dpy)){
		XNextEvent(dpy, &ev);
		with(Log(Log.BOLD ~ "%s ev %s".format(ev.xany.window, handlerNames.get(ev.type, ev.type.to!string)))){
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
	}
	Inotify.update;

	if(updateStrut){
		foreach(m; monitors)
			m.resize(m.size);
		updateStrut = false;
	}

	tick();

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
		with(Log("restack")){
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
	}
}

void run(){
	while(running){
		auto start = now;
		loop;
		auto end = now;
		if(end - start < 1/120.0)
			sleep(1/120.0 - (end-start));
	}
}

Client active(){
	return monitor.active;
}

Client[] globals(){
	return monitors.fold!((a, b) => a ~ b.globals)(cast(Client[])[]).array;
}

Client[] clients(){
	return monitors.map!(a => a.clients).fold!((a, b) => a ~ b);
}

Client[] clientsVisible(){
	return monitors.map!(a => a.clientsVisible).fold!((a, b) => a ~ b);
}


void focus(Monitor monitor){
	if(monitor != .monitor)
		.monitor = monitor;
}


void restack(){
	"queueRestack = true".log;
	queueRestack = true;
}

bool getrootptr(int *x, int *y){
	int di;
	uint dui;
	Window dummy;
	return 1 == XQueryPointer(dpy, root, &dummy, &dummy, x, y, &di, &di, &dui);
}

void quit(){
	running = false;
}

bool updateMonitors(){
	with(Log("updateMonitors")){
		bool dirty = false;
		auto screens = screens(dpy);
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
			monitor.id = i.to!int;
			auto screen = screens[i.to!int];
			if(monitor.size != [screen.w, screen.h] || monitor.pos != [screen.x, screen.y]){
				with(Log("updating desktop size")){
					dirty = true;
					monitor.pos = [screen.x, screen.y];
					monitor.resize([screen.w, screen.h]);
				}
			}
		}
		if(dirty){
			monitor = monitors[0];
			monitor = findMonitor(root);
		}
		return dirty;
	}
}

Client wintoclient(Window w){
	foreach(c; clients)
		if(c.win == w || c.orig == w)
			return c;
	return null;
}

Monitor findMonitor(int[2] pos, int[2] size=[1,1]){
	Monitor result = monitor;
	int a, area = 0;
	foreach(monitor; monitors)
		if((a = intersectArea(pos.x, pos.y, size.w, size.h, monitor)) > area){
			area = a;
			result = monitor;
		}
	return result;
}

Monitor findMonitor(Window w){
	int x, y;
	if(w == root && getrootptr(&x, &y))
		return findMonitor([x, y]);
	return findMonitor(wintoclient(w));
}

Monitor findMonitor(Client w){
	foreach(m; monitors){
		if(m.clients.canFind(w))
			return m;
	}
	return null;
}

void manage(Window w, XWindowAttributes* wa){
	if(!w)
		throw new Exception("No window given");
	if(wintoclient(w))
		return;
	//auto monitor = findMonitor([wa.x, wa.y], [wa.width, wa.height]);
	auto c = new Client(w);
	XSelectInput(dpy, w, EnterWindowMask|FocusChangeMask|PropertyChangeMask|StructureNotifyMask|KeyReleaseMask|KeyPressMask);
	monitor.add(c, c.originWorkspace);
	if(c.isFloating && c.pos.x == 0 && c.pos.y == 0)
		c.pos = monitor.size.a/2 - c.size.a/2;
	XChangeProperty(dpy, root, Atoms._NET_CLIENT_LIST, XA_WINDOW, 32, PropModeAppend, cast(ubyte*)&c.win, 1);
	c.updateStrut;
	if(c.isVisible){
		c.show;
		c.focus;
	}else
		c.requestAttention;
}

void cleanup(){
	with(Log(Log.BOLD ~ Log.GREEN ~ "CLEANUP")){
		XUngrabKey(dpy, AnyKey, AnyModifier, root);
		foreach(ws; monitor.workspaces){
			foreach(c; ws.clients){
				if(restart){
					XMapWindow(dpy, c.win);
					XMoveWindow(dpy, c.win, c.pos.x, c.pos.y);
					"%s resetting".format(c).log;
				}else
					killClient(c);
			}
		}
		monitor.destroy;
		foreach(c; cursor)
			c.destroy(dpy);
		XSync(dpy, false);
		XSetInputFocus(dpy, PointerRoot, RevertToPointerRoot, CurrentTime);
		XDeleteProperty(dpy, root, Atoms._NET_ACTIVE_WINDOW);
		taskPool.stop;
	}
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
	}catch(Throwable) {}
	return xerrorxlib(dpy, ee); /* may call exit */
}

extern(C) nothrow int xerrorfatal(Display* dpy){
	try{
		defaultTraceHandler.toString.log;
		"flatman: X11 fatal i/o error".log;
	}catch(Throwable) {}
	return xerrorfatalxlib(dpy);
}

extern(C) nothrow int xerrordummy(Display* dpy, XErrorEvent* ee){
	return 0;
}

nothrow extern(C) int xerrorstart(Display *dpy, XErrorEvent* ee){
	try
		"flatman: another window manager is already running".log;
	catch(Throwable) {}
	_exit(-1);
	return -1;
}
