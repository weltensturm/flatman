module bar.main;

import bar;

import std.typecons, common.xevents, common.log;


extern(C) nothrow int xerror(Display* dpy, XErrorEvent* e){
	try {
		lastXerror = "X11 error: %s %s"
				.format(cast(XRequestCode)e.request_code, cast(XErrorCode)e.error_code);
		lastXerror.writeln;
	}
	catch(Throwable){}
	return 0;
}


Display* dpy;
x11.X.Window root;


bool running = true;


extern(C) nothrow @nogc @system void stop(int){
	running = false;
}


void main(){

	version(unittest){ import core.stdc.stdlib: exit; exit(0); }

	Log.setLevel(Log.Level.info);

	XSetErrorHandler(&xerror);
	signal(SIGINT, &stop);
	auto app = new App;
	try {
		while(wm.hasActiveWindows && running){
			Inotify.update;
			wm.processEvents((e){
				handleEvent(e);
			});
			foreach(bar; app.bars){
				bar.onDraw;
			}
			Thread.sleep(10.msecs);
		}
	}catch(Throwable t){
		writeln(t);
	}
	foreach(bar; app.bars){
		bar.close;
	}

	Log.shutdown;
	writeln("quit");
}


class App {

	int mainScreen;

	common.screens.Screen[int] screens;

	Client[] clients;

	Bar[] bars;

	this(){

		dpy = wm.displayHandle;
		.root = XDefaultRootWindow(dpy);

		debug(XError){
			XSynchronize(dpy, true);
		}

		Events ~= this;

        config.loadAndWatch(["/etc/flatman/bar.ws", "~/.config/flatman/bar.ws"],
        	(string msg, bool){ writeln("CONFIG ERROR\n", msg); });

		XSelectInput(wm.displayHandle, .root,
			StructureNotifyMask
		    | SubstructureNotifyMask
		    | ExposureMask
		    | PropertyChangeMask);

		initAlpha;
		scan;

	}

	@(ConfigLoaded!Config)
	void configChanged(){
		Log("reloading config");
		foreach(bar; bars){
			bar.close;
			bar.destroy;
		}
		bars = [];
		void delegate()[] delay;
		auto screens = .screens(wm.displayHandle);
		foreach(barConf; config.bars){
			if(barConf.screen !in screens)
				continue;
			auto bar = new Bar(this);
			wm.add(bar);
			bar.show;
			bar.screen = barConf.screen;
			if(!barConf.systray){
				bar.systray(false);
			}else{
				delay ~= { bar.systray(true); };
			}
			bars ~= bar;
		}
		if(!bars.length)
			writeln("WARNING: no bars created");
		foreach(d;delay){d();}
		updateScreens;
	}

	void scan(){
		XFlush(wm.displayHandle);
		XGrabServer(wm.displayHandle);
		x11.X.Window root_return, parent_return;
		x11.X.Window* children;
		uint nchildren;
		XQueryTree(dpy, .root, &root_return, &parent_return, &children, &nchildren);
		if(children){
			foreach(window; children[0..nchildren]){
				if(.root == root_return)
					evCreate(false, window);
			}
			XFree(children);
		}
		XUngrabServer(wm.displayHandle);
		XFlush(wm.displayHandle);
	}

	void updateScreens(){
		screens = .screens(wm.displayHandle);
		writeln(screens);
		foreach(bar; bars){
			if(bar.screen in screens){
				bar.show;
				bar.resize([screens[bar.screen].w, bar.size.h]);
				bar.move([screens[bar.screen].x, screens[bar.screen].y]);
			}else{
				bar.hide;
				writeln("WARNING: could not find screen ", bar.screen);
			}
		}
	}

	@WindowCreate
	void evCreate(bool override_redirect, x11.X.Window window){
		foreach(bar; bars){
			if(bar.windowHandle == window){
				return;
			}
		}
		XWindowAttributes wa;
		if(!XGetWindowAttributes(wm.displayHandle, window, &wa) || wa.c_class == InputOnly || wa.override_redirect){
			return;
		}
		Log.info("CreateWindow " ~ window.to!string);
		auto client = new Client(window);
		if(wa.map_state != IsViewable)
			client.hidden = true;
		client.screen = screens.findScreen([wa.x, wa.y], [wa.width, wa.height]);
		clients ~= client;
		foreach(bar; bars){
			bar.update = true;
		}
	}

	@WindowDestroy
	void evDestroy(x11.X.Window window){
		if(auto client = find(window)){
			clients = clients.without(client);
			foreach(bar; bars){
				bar.update = true;
				if(bar.currentClient == client)
					bar.currentClient = null;
			}
			destroy(client);
		}
	}

	@WindowConfigure
	void evConfigure(WindowHandle window, XConfigureEvent* e){
		if(window == .root){
			updateScreens;
		}
		foreach(bar; bars){
			if(e.window == bar.windowHandle)
				return;
		}
		foreach(i, c; clients){
			if(c.window == window){
				c.screen = screens.findScreen([e.x, e.y], [e.width, e.height]);
				return;
			}
		}
	}

	Client find(WindowHandle handle){
		foreach(c; clients){
			if(c.window == handle)
				return c;
		}
		return null;
	}

}

