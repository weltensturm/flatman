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

class Dragging {
	Client client;
	int[2] offset;
	int width;
	void delegate(int[2]) drag;
	void delegate() drop;
}


struct TimedEvent {
	double time;
	void delegate() event;
}

TimedEvent[] schedule;

void delegate(XEvent*)[int][Window] customHandler;

static bool running = true;
bool restart = false;
Client previousFocus;
Window[] unmanaged;

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

Dragging dragging;

bool redraw;
bool queueRestack;
bool updateStrut;
int[] dragUpdate;

int[2] rootSize = [1,1];


void main(string[] args){
	(Log.BOLD ~ Log.GREEN ~ "===== FLATMAN =====").log;
	"args %s".format(args).log;
	try{
		auto configs = ["/etc/flatman/config.ws", "~/.config/flatman/config.ws"];
		environment["_JAVA_AWT_WM_NONREPARENTING"] = "1";
		if(!setlocale(LC_CTYPE, "") || !XSupportsLocale())
			"warning: no locale support".log;

		auto cfgReload = {
			["notify-send", "Loading config"].execute;
			try{
				cfg.fillConfig(configs);
			}catch(Exception e){
				["notify-send", e.toString].execute;
				log(e.to!string);
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
		checkOtherWm;
		setup(args[$-1] != "restarting");
		scan;
		run;
	}catch(Throwable t){
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
	xerrorfatalxlib = XSetIOErrorHandler(&xerrorfatal);

	/* init screen */
	screen = DefaultScreen(dpy);
	root = XDefaultRootWindow(dpy);

	//wm = new CompositeManager;

	sw = DisplayWidth(dpy, screen);
	sh = DisplayHeight(dpy, screen);
	rootSize = [sw, sh];
	root = RootWindow(dpy, screen);

	/* init atoms */
	/* init cursors */
	cursor[CurNormal] = new ws.x.draw.Cur(dpy, XC_left_ptr);
	cursor[CurResize] = new ws.x.draw.Cur(dpy, XC_sizing);
	cursor[CurMove] = new ws.x.draw.Cur(dpy, XC_fleur);

	wm.fillAtoms;
	net.fillAtoms;
	motif.fillAtoms;

	//updatebars();
	updateMonitors();
	/* EWMH support per view */
	XDeleteProperty(dpy,root, net.supported);
	foreach(n; FieldNameTuple!NetAtoms)
		mixin("XChangeProperty(dpy, root, net.supported, XA_ATOM, 32, PropModeAppend, cast(ubyte*)&net." ~ n ~ ", 1);");
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

void run(){
	XEvent ev;

	while(running){
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

		if(dragUpdate.length && dragging){
			doDrag(dragUpdate.to!(int[2]));
			dragUpdate = [];
		}

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
		sleep(1/120.0);
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

void doDrag(int[2] pos){

	auto x = pos.x;
	auto y = pos.y;

	if(!clients.canFind(dragging.client))
		return;

	static Monitor mon = null;
	Monitor m;
	if((m = findMonitor(pos)) != mon && mon){
		if(monitor && monitor.active)
			monitor.active.unfocus(true);
		monitor = m;
		if(monitor.active)
			monitor.active.focus;
		//focus(null);
	}
	mon = m;

	auto client = dragging.client;
	auto monitor = client.monitor;

	if(.monitor != monitor){
		monitor.remove(client);
		m.add(client);
		monitor = m;
	}

	auto snapBorder = 10;

	if(
		(y <= monitor.pos.y+cfg.tabsTitleHeight)
				== client.isFloating
			&& x > monitor.pos.x+snapBorder
			&& x < monitor.pos.x+monitor.size.w-snapBorder)
		client.togglefloating;

	if(client.isFloating){
		if(x <= monitor.pos.x+snapBorder && x >= monitor.pos.x){
			if(client.isFloating){
				monitor.remove(client);
				client.isFloating = false;
				monitor.workspace.split.add(client, -1);
			}
			return;
		}else if(x >= monitor.pos.x+monitor.size.w-snapBorder && x <= monitor.pos.x+monitor.size.w){
			if(client.isFloating){
				monitor.remove(client);
				client.isFloating = false;
				monitor.workspace.split.add(client, monitor.workspace.split.clients.length);
			}
			return;
		}
		auto xt = dragging.offset.x * client.size.w / dragging.width;
		client.moveResize([x, y].a + [xt, dragging.offset.y], client.sizeFloating);
	}
	else
		{}
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

void manage(Window w, XWindowAttributes* wa){
	if(!w)
		throw new Exception("No window given");
	if(wintoclient(w))
		return;
	//auto monitor = findMonitor([wa.x, wa.y], [wa.width, wa.height]);
	auto c = new Client(w, monitor);
	XSelectInput(dpy, w, EnterWindowMask|FocusChangeMask|PropertyChangeMask|StructureNotifyMask|KeyReleaseMask|KeyPressMask);
	monitor.add(c, c.originWorkspace);
	if(c.isFloating && c.pos.x == 0 && c.pos.y == 0)
		c.pos = monitor.size.a/2 - c.size.a/2;
	XChangeProperty(dpy, root, net.clientList, XA_WINDOW, 32, PropModeAppend, cast(ubyte*)&c.win, 1);
	c.updateStrut;
	if(c.isVisible){
		c.show;
		c.focus;
	}else
		c.requestAttention;
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
			monitor = wintomon(root);
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
		XDeleteProperty(dpy, root, net.windowActive);
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
