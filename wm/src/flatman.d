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

int screen;
Window root;
Display* dpy;

bool running = true;
bool restart;
Window[] unmanaged;

ws.x.draw.Cur[CurLast] cursor;

Monitor monitor;
Monitor[] monitors;

bool queueRestack;
bool updateStrut;

int[2] rootSize = [1,1];


DragSystem drag;
KeybindSystem keys;
WorkspaceHistory workspaceHistory;
EventSequence eventSequence;


int main(string[] args){
	
	version(unittest){ exit(0); }

	(Log.BOLD ~ Log.GREEN ~ "===== FLATMAN =====").log;
	"args %s".format(args[1..$]).log;
	try{
		auto configs = ["/etc/flatman/config.ws", "~/.config/flatman/config.ws"];
		environment["_JAVA_AWT_WM_NONREPARENTING"] = "1";
		if(!setlocale(LC_CTYPE, "") || !XSupportsLocale())
			"warning: no locale support".log;

		["mkdir", "-p", "~/.config/flatman".expandTilde].spawnProcess;
		["touch", "~/.config/flatman/config.ws".expandTilde].spawnProcess;

		auto cfgReload = {
			notify("Loading config");
			try{
				auto newConfig = NestedConfig();
				newConfig.fillConfigNested(configs);
				ConfigUpdate(newConfig);
				config = newConfig;
			}catch(ConfigException e){
				Log.error(e.msg);
				notify(e.msg);
			}catch(Exception e){
				notify(e.toString);
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
		Log.error("FATAL ERROR\n" ~ t.toString);
        stdout.flush;
        stderr.flush;
        return 1;
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
    return 0;
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

	registerAll;

	xerrorfatalxlib = XSetIOErrorHandler(&xerrorfatal);

	screen = DefaultScreen(dpy);
	root = XDefaultRootWindow(dpy);

	rootSize = [DisplayWidth(dpy, screen), DisplayHeight(dpy, screen)];
	root = RootWindow(dpy, screen);

	cursor[CurNormal] = new ws.x.draw.Cur(dpy, XC_left_ptr);
	cursor[CurResize] = new ws.x.draw.Cur(dpy, XC_sizing);
	cursor[CurMove] = new ws.x.draw.Cur(dpy, XC_fleur);

	wm.fillAtoms;

	moveResizeMonitors();

	XDeleteProperty(dpy, root, Atoms._NET_SUPPORTED);
	foreach(n; ewmh.netSupported)
		XChangeProperty(dpy, root, Atoms._NET_SUPPORTED, XA_ATOM, 32, PropModeAppend, cast(ubyte*)&n, 1);
	XDeleteProperty(dpy, root, Atoms._NET_CLIENT_LIST);

	ewmh.updateDesktopCount;
	ewmh.updateCurrentDesktop;
	XSetWindowAttributes wa;
	wa.cursor = cursor[CurNormal].cursor;
	wa.event_mask =
			SubstructureRedirectMask|SubstructureNotifyMask|ButtonPressMask
			|PointerMotionMask|EnterWindowMask|StructureNotifyMask
			|PropertyChangeMask;
	XChangeWindowAttributes(dpy, root, CWEventMask|CWCursor, &wa);
	XSelectInput(dpy, root, wa.event_mask);

	registerFunctions;

	keys = new KeybindSystem;
	drag = new DragSystem;
	workspaceHistory = new WorkspaceHistory;
	eventSequence = new EventSequence;
	
	ewmh.updateWorkarea;
	ewmh.setSupportingWm;

	ConfigUpdate(config);

}

void scan(){
	Window[][AtomType!XA_CARDINAL] workspaces;
	XWindowAttributes wa;

	with(Log(Log.YELLOW ~ "scan" ~ Log.DEFAULT)){
		foreach(w; queryTree){
			with(Log(Log.YELLOW ~ "%s %s".format(w, w.getTitle))){
				if(!XGetWindowAttributes(dpy, w, &wa)){
					"could not get window attributes".log;
				}else if(wa.override_redirect){
					"unmanaged".log;
					unmanaged ~= w;
				}else if(find(w)){
					"already managed?!".log;
				}else if(wa.map_state != IsViewable && getstate(w) != IconicState){
					"client is not visible".log;
				}else{
					"scan manages %s".format(w).log;
					long workspace;
					try {
						workspace = w.getprop!XA_CARDINAL(Atoms._NET_WM_DESKTOP);
					}catch(Exception e){
						Log.error(e.to!string);
						workspace = 0;
					}
					workspaces[workspace] ~= w;
				}
			}
		}

		auto workspaceNames = Atoms._NET_DESKTOP_NAMES
			.get!string
			.split('\0')
			.map!(a => a.replace("~", "~".expandTilde))
			.array;

		auto workspaceMax = object.keys(workspaces).fold!max(0L);

		while(monitor.workspaces.length < workspaceMax+1)
			newWorkspace(0);

		foreach(i, ws; workspaceNames){
			if(i < monitor.workspaces.length){
				auto context = ws
						.expandTilde
						.absolutePath
						.buildNormalizedPath
						.replace("/", "-");
				auto contextFile = "~/.flatman/".expandTilde ~ context ~ ".context";
				monitor.workspaces[i].updateContext(contextFile);
			}
		}

		foreach(ws; workspaces){
			foreach(win; ws){
				XWindowAttributes wa;
				XGetWindowAttributes(dpy, win, &wa);
				manage(win, &wa, false, true);
			}
		}
		switchWorkspace(0);
	}
}


void loop(){


	Inotify.update;

	if(updateStrut){
		foreach(m; monitors)
			m.resize(m.size);
		updateStrut = false;
	}

	Tick();

	if(requestFocus){
		(Log.RED ~ "focus" ~ Log.DEFAULT ~ " %s".format(requestFocus)).log;
		previousFocus = currentFocus;
		currentFocus = requestFocus;
		requestFocus = null;
		focus(currentFocus.monitor);
		monitor.setActive(currentFocus);
		XSetInputFocus(dpy, currentFocus.orig, RevertToPointerRoot, CurrentTime);
		XChangeProperty(dpy, .root, Atoms._NET_ACTIVE_WINDOW,
	                    XA_WINDOW, 32, PropModeReplace,
	                    cast(ubyte*) &(currentFocus.orig), 1);
        currentFocus.sendEvent(wm.takeFocus);
		restack;
	}
	
	if(queueRestack){
		with(Log("restack")){
			auto stack = unmanaged;
			foreach(monitor; monitors){
				if(monitor.active && monitor.active.isfullscreen)
					stack ~= monitor.active.win;
				if(monitor.workspace){
					stack ~= monitor.workspace.floating.stack;
				}
			}
			foreach(monitor; monitors){
				stack ~= monitor.globals.map!(a => a.win).array;
			}
			foreach(monitor; monitors){
               stack ~= monitor.workspace.split.stack;
			}
			XRestackWindows(dpy, stack.ptr, stack.length.to!int);
			queueRestack = false;
			//while(XCheckMaskEvent(dpy, EnterWindowMask|LeaveWindowMask, &ev)){}
		}

	}

	handleEvents;

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


void restack(){
	"queueRestack = true".log;
	queueRestack = true;
}

void quit(){
	running = false;
}

bool moveResizeMonitors(){
	with(Log("moveResizeMonitors")){
		bool dirty;
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


void cleanup(){
	with(Log(Log.BOLD ~ Log.GREEN ~ "CLEANUP")){
		XUngrabKey(dpy, AnyKey, AnyModifier, root);
		foreach(ws; monitor.workspaces){
			foreach(c; ws.clients){
				if(restart){
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

		Log.shutdown;

		taskPool.stop;

		drag.destroy;
		keys.destroy;
	}
}
