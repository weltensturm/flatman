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
	while(wm.hasActiveWindows && running){
		wm.processEvents;
		app.bar.onDraw;
		Thread.sleep(10.msecs);
	}
	app.bar.onDestroy;
	writeln("quit");
}


class App {

	int mainScreen;

	common.screens.Screen[int] screens;

	Client[] clients;

	Bar bar;

    version(CompilePlugins){
	    Plugins plugins;
    }

	this(){

		dpy = wm.displayHandle;
		.root = XDefaultRootWindow(dpy);
		
		try {
			config.fillConfig(["/etc/flatman/bar.ws", "~/.config/flatman/bar.ws"]);
		}catch(Exception e){
			writeln(e.to!string);
		}

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


		bar = new Bar(this);
        version(CompilePlugins){
    		plugins = new Plugins(bar);
        }
		bar.show;
		wm.add(bar);

		scan;

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
		bar.resize([screens[0].w, bar.size.h]);
		bar.move([screens[0].x, screens[0].y]);
		bar.screen = 0;
	}

	void evCreate(x11.X.Window window){
		XWindowAttributes wa;
		if(window == bar.windowHandle || !XGetWindowAttributes(wm.displayHandle, window, &wa) || wa.c_class == InputOnly){
			return;
		}
		auto client = new Client(window);
		if(wa.map_state != IsViewable)
			client.hidden = true;
		client.screen = screens.findScreen([wa.x, wa.y], [wa.width, wa.height]);
		clients ~= client;
		bar.update = true;
	}

	void evDestroy(x11.X.Window window){
		properties.remove(window);
		foreach(i, c; clients){
			if(c.window == window){
				clients = clients.without(c);
				return;
			}
		}
		bar.update = true;
	}

	void evConfigure(XEvent* e){
		if(e.xconfigure.window == .root){
			//resize([e.xconfigure.width, size.h]);
			updateScreens;
		}
		if(e.xconfigure.window == bar.windowHandle)
			return;
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
		bar.update = true;
	}

	void evUnmap(XUnmapEvent* e){
		foreach(c; clients){
			if(c.window == e.window){
				c.hidden = true;
				return;
			}
		}
		bar.update = true;
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
		bar.update = true;
	}



}

