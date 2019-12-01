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


alias Overview = Event!("FlatmanOverview", void function(bool));


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
		with(Log("reloading config")){
			foreach(bar; bars){
				bar.close;
				bar.destroy;
				wm.remove(bar);
			}
			bars = [];
			void delegate()[] delay;
			auto screens = .screens(wm.displayHandle);
			bool systraySet = false;
			foreach(barName, barConf; config.bars){
				foreach(i, screen; screens){
					if(barConf.screen == "all" || barConf.screen.to!int == i){
						auto bar = new Bar(this, barName ~ " - " ~ i.to!string, barConf.strut, barConf.overviewOnly);
						bar.screen = i;
						bar.alignment = barConf.alignment;
						wm.add(bar);
						bar.show;
						if(!barConf.systray || systraySet){
							bar.systray(false);
						}else{
							systraySet = true;
							delay ~= { bar.systray(true); };
						}
						bars ~= bar;
					}
				}
			}
			if(!bars.length)
				Log("WARNING: no bars created");
			foreach(d;delay){d();}
			updateScreens;
		}
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

		alias Rect = Tuple!(int[2], int[2]);

		Tuple!(int[2], int[2]) delegate(int[2], int[2])[string] alignments = [
			"left": (pos, size) => Rect([24, size.h], [pos.x, pos.y]),
			"right": (pos, size) => Rect([24, size.h], [pos.x+size.w, pos.y]),
			"top": (pos, size) => Rect([size.w, 24], [pos.x, pos.y]),
			"bottom": (pos, size) => Rect([size.w, 24], [pos.x, pos.y+size.h-24])
		];

		screens = .screens(wm.displayHandle);
		Log("screens: " ~ screens.to!string);
		auto realEstate = screens.dup;
		foreach(bar; bars){
			if(bar.screen in screens){
				auto screen = realEstate[bar.screen];
				auto rect = alignments[bar.alignment]([screen.x, screen.y], [screen.w, screen.h]);
				if(bar.strut){
					final switch(bar.alignment){
						case "left":
							realEstate[bar.screen].x += rect[0].w;
							realEstate[bar.screen].w -= rect[0].w;
							break;
						case "right":
							realEstate[bar.screen].w -= rect[0].w;
							break;
						case "top":
							realEstate[bar.screen].y += rect[0].h;
							realEstate[bar.screen].h -= rect[0].h;
							break;
						case "bottom":
							realEstate[bar.screen].h -= rect[0].h;
							break;
					}
				}
				bar.resize(rect[0]);
				bar.move(rect[1]);
				bar.show;
			}else{
				bar.hide;
				Log("WARNING: could not find screen " ~ bar.screen.to!string);
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

    @WindowProperty
	void evProperty(WindowHandle window, XPropertyEvent* e){
		if(window == .root && e.atom == Atoms._FLATMAN_OVERVIEW){
			if(window.props._FLATMAN_OVERVIEW.get!long)
				Overview(true);
			else
				Overview(false);
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

