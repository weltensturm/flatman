module bar.bar;

import bar;


Display* dpy;
x11.X.Window root;
PropertyList properties;

struct Screen {
	int x, y, w, h;
}

Screen[int] screens(){
	int count;
	auto screenInfo = XineramaQueryScreens(dpy, &count);
	Screen[int] res;
	foreach(screen; screenInfo[0..count])
		res[screen.screen_number] = Screen(screen.x_org, screen.y_org, screen.width, screen.height);
	XFree(screenInfo);
	return res;

}


Picture generateGlow(float[3] color){
	auto pixmap = XCreatePixmap(dpy, root, 200, 40, 32);
	XRenderPictureAttributes pa;
	pa.repeat = true;
	auto picture = XRenderCreatePicture(dpy, pixmap, XRenderFindStandardFormat(dpy, PictStandardARGB32), CPRepeat, &pa);
	XRenderColor c;
	foreach(x; 0..200){
		foreach(y; 0..1){
			auto len = asqrt((x-100.0).pow(2) + y*y).min(100);
			auto alpha = (1-len/100).pow(3);
			c.red =  (color[0]*alpha*0xffff).to!ushort;
			c.green =  (color[1]*alpha*0xffff).to!ushort;
			c.blue =  (color[2]*alpha*0xffff).to!ushort;
			c.alpha = (alpha*0xffff).to!ushort;
			XRenderFillRectangle(dpy, PictOpSrc, picture, &c, x, y, 1, 1);
		}
	}
	XFreePixmap(dpy, pixmap);
	return picture;
}

void fillAtoms(T)(ref T data){
	foreach(n; FieldNameTuple!T){
		mixin("data." ~ n ~ " = XInternAtom(wm.displayHandle, __traits(getAttributes, data."~n~")[0], false);");
	}
}

struct WmAtoms {
	@("WM_PROTOCOLS") Atom protocols;
	@("WM_DELETE_WINDOW") Atom delete_;
}

WmAtoms wm_;


class Bar: ws.wm.Window {

	Client[] clients;

	Property!(XA_CARDINAL, false) workspace;
	Property!(XA_CARDINAL, false) currentWorkspace;
	Property!(XA_WINDOW, false) currentWindow;
	Property!(XA_CARDINAL, true) strut;
	Property!(XA_STRING, false) workspaceNames;

	Client currentClient;

	bool autohide = false;

	bool hidden;

	Picture glow;

	TaskList taskList;
	PowerButton powerButton;
	Tray tray;

	int right, left;

	bool update = true;
	int second = 0;

	//Switcher switcher;

	this(){
		properties = new PropertyList;
		dpy = wm.displayHandle;
		.root = XDefaultRootWindow(dpy);
		auto screens = screens;

		wm_.fillAtoms;

		wm.on([
			CreateNotify: (XEvent* e) => evCreate(e.xcreatewindow.window),
			DestroyNotify: (XEvent* e) => evDestroy(e.xdestroywindow.window),
			ConfigureNotify: (XEvent* e) => evConfigure(e),
			MapNotify: (XEvent* e) => evMap(&e.xmap),
			UnmapNotify: (XEvent* e) => evUnmap(&e.xunmap),
			PropertyNotify: (XEvent* e) => evProperty(&e.xproperty)
		]);

		XSelectInput(wm.displayHandle, .root,
		    SubstructureNotifyMask
		    | ExposureMask
		    | PropertyChangeMask);

		taskList = addNew!TaskList(this);
		powerButton = addNew!PowerButton(this);
		powerButton.hide;

		super(screens[0].w, 24, "flatman bar");

		tray = addNew!Tray(this);
		tray.resize(size);
		tray.change ~= (int clients){
			tray.move([size.w-clients*size.h - draw.width("00:00:00") - 20, 0]);
		};
		if(autohide){
			resize([size.w, 1]);
			hidden = true;
		}

		scan;
	}

	override void show(){
		super.show;
		workspace = new Property!(XA_CARDINAL, false)(windowHandle, "_NET_WM_DESKTOP");
		workspace = -1;

		workspaceNames = new Property!(XA_STRING, false)(.root, "_NET_DESKTOP_NAMES", properties);

		currentWorkspace = new Property!(XA_CARDINAL, false)(.root, "_NET_CURRENT_DESKTOP", properties);

		currentWindow = new Property!(XA_WINDOW, false)(.root, "_NET_ACTIVE_WINDOW", properties);
		currentWindow ~= (x11.X.Window window){
			foreach(client; clients){
				if(client.window == window){
					currentClient = client;
					break;
				}
			}
		};

		strut = new Property!(XA_CARDINAL, true)(windowHandle, "_NET_WM_STRUT_PARTIAL", properties);
		strut = [0, 0, size.h, 0, 0, 0, 0, 0, 0, 0, 0, size.h];

	}

	override void drawInit(){
		_draw = new XDraw(this);
		draw.setFont("Segoe UI", 10);
		glow = generateGlow([0.877, 0.544, 0]);
		initAlpha;
	}

	override void onDestroy(){
		tray.destroy;
		super.onDestroy;
	}

	override void onDraw(){
		auto time = Clock.currTime;
		if(update || time.second != second){
			if(update)
				taskList.update(clients);
			
			draw.setColor([0.13333,0.13333,0.13333]);
			draw.rect([0,0], size);

			left = 200;
			auto names = workspaceNames.value.split('\0');
			if(currentWorkspace.value < names.length){
				draw.setColor([0.8,0.8,0.8]);
				draw.text([5,5], names[currentWorkspace]);
			}
			draw.setColor([0.25,0.25,0.25]);
			draw.rect([0,0], [size.w,1]);

			draw.setColor([0.8,0.8,0.8]);
			auto right = draw.width("00:00:00")+10;
			draw.text([size.w-right, 5], "%02d:%02d:%02d".format(time.hour, time.minute, time.second), 0);

			super.onDraw;

			draw.finishFrame;

			second = time.second;
			update = false;
		}
	}

	override void resize(int[2] size){
		super.resize(size);
		powerButton.resize([size.h, size.h]);
		powerButton.move([size.w-size.h, 0]);
		taskList.resize(size.a - [size.h*2, 0]);
		taskList.move([size.h, 0]);
		tray.resize(size);
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

	void evCreate(x11.X.Window window){
		XWindowAttributes wa;
		if(window == windowHandle || !XGetWindowAttributes(wm.displayHandle, window, &wa) || wa.c_class == InputOnly){
			return;
		}
		auto client = new Client(window);
		if(wa.map_state != IsViewable)
			client.hidden = true;
		clients ~= client;
		update = true;
	}

	void evDestroy(x11.X.Window window){
		properties.remove(window);
		foreach(i, c; clients){
			if(c.window == window){
				clients = clients.without(c);
				return;
			}
		}
		update = true;
	}

	void evConfigure(XEvent* e){
		if(e.xconfigure.window == .root)
			resize([e.xconfigure.width, size.h]);
		if(e.xconfigure.window == windowHandle)
			return;
		foreach(i, c; clients){
			if(c.window == e.xconfigure.window){
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
		update = true;
	}

	void evUnmap(XUnmapEvent* e){
		foreach(c; clients){
			if(c.window == e.window){
				c.hidden = true;
				return;
			}
		}
		update = true;
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
		update = true;
	}

}
