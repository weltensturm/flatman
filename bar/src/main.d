module bar.main;


import bar;


extern(C) nothrow int xerror(Display* dpy, XErrorEvent* e){
	try {
		char[128] buffer;
		XGetErrorText(wm.displayHandle, e.error_code, buffer.ptr, buffer.length);
		"XError: %s (major=%s, minor=%s, serial=%s)".format(buffer.to!string, e.request_code, e.minor_code, e.serial).writeln;
	}
	catch(Throwable){}
	return 0;
}


bool running = true;


extern(C) nothrow @nogc @system void stop(int){
	running = false;
}


void main(){
	XSetErrorHandler(&xerror);
	signal(SIGINT, &stop);
	auto app = new App;
	try {
		while(wm.hasActiveWindows && running){
			Inotify.update;
			wm.processEvents;
			foreach(bar; app.bars){
				bar.onDraw;
			}
			Thread.sleep(10.msecs);
		}
	}catch(Throwable t){}
	foreach(bar; app.bars){
		bar.onDestroy;
	}
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
		
        config.loadAndWatch(["/etc/flatman/bar.ws", "~/.config/flatman/bar.ws"], &configChanged);

		wm.on([
			CreateNotify: (XEvent* e) => evCreate(e.xcreatewindow.window),
			DestroyNotify: (XEvent* e) => evDestroy(e.xdestroywindow.window),
			ConfigureNotify: (XEvent* e) => evConfigure(e),
			MapNotify: (XEvent* e) => evMap(&e.xmap),
			UnmapNotify: (XEvent* e) => evUnmap(&e.xunmap),
			PropertyNotify: (XEvent* e) => evProperty(&e.xproperty)
		]);

		XSelectInput(wm.displayHandle, .root,
			StructureNotifyMask
		    | SubstructureNotifyMask
		    | ExposureMask
		    | PropertyChangeMask);

		scan;

	}
	
	void configChanged(){
		foreach(bar; bars){
			bar.onDestroy;
		}
		void delegate()[] delay;
		foreach(barConf; config.bars){
			auto bar = new Bar(this);
			bar.show;
			bar.screen = barConf.screen;
			if(!barConf.systray){
				bar.systray(false);
			}else{
				delay ~= { bar.systray(true); };
			}
			wm.add(bar);
			bars ~= bar;
		}
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
					evCreate(window);
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

	void evCreate(x11.X.Window window){
		XWindowAttributes wa;
		foreach(bar; bars){
			if(bar.windowHandle == window){
				return;
			}
		}
		if(!XGetWindowAttributes(wm.displayHandle, window, &wa) || wa.c_class == InputOnly){
			return;
		}
		auto client = new Client(window);
		if(wa.map_state != IsViewable)
			client.hidden = true;
		client.screen = screens.findScreen([wa.x, wa.y], [wa.width, wa.height]);
		clients ~= client;
		foreach(bar; bars){
			bar.update = true;
		}
	}

	void evDestroy(x11.X.Window window){
		properties.remove(window);
		foreach(i, c; clients){
			if(c.window == window){
				clients = clients.without(c);
				return;
			}
		}
		foreach(bar; bars){
			bar.update = true;
		}
	}

	void evConfigure(XEvent* e){
		if(e.xconfigure.window == .root){
			//resize([e.xconfigure.width, size.h]);
			updateScreens;
		}
		foreach(bar; bars){
			if(e.xconfigure.window == bar.windowHandle)
				return;
		}
		foreach(i, c; clients){
			if(c.window == e.xconfigure.window){
				c.screen = screens.findScreen([e.xconfigure.x, e.xconfigure.y], [e.xconfigure.width, e.xconfigure.height]);
				return;
			}
		}
	}

	void evMap(XMapEvent* e){
		foreach(i, c; clients){
			if(c.window == e.window){
				c.hidden = false;
				return;
			}
		}
		evCreate(e.window);
		foreach(bar; bars){
			bar.update = true;
		}
	}

	void evUnmap(XUnmapEvent* e){
		foreach(c; clients){
			if(c.window == e.window){
				c.hidden = true;
				return;
			}
		}
		foreach(bar; bars){
			bar.update = true;
		}
	}

	void evProperty(XPropertyEvent* e){
		properties.update(e);
		if(e.atom == XA_WM_NAME){
			foreach(client; clients){
				if(client.window == e.window){
					client.title = client.getTitle;
				}
			}
		}
		foreach(bar; bars){
			bar.update = true;
		}
	}

}

