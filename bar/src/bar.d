module bar.bar;

import bar;


Display* dpy;
x11.X.Window root;
PropertyList properties;

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

class Bar: ws.wm.Window {

	int screen;

	Property!(XA_CARDINAL, false) workspace;
	Property!(XA_WINDOW, false) currentWindow;
	Property!(XA_CARDINAL, true) strut;

	Client currentClient;

	bool autohide = false;

	bool hidden;

	Picture glow;

	TaskList taskList;
	PowerButton powerButton;
	Tray tray;
	Battery battery;
	WorkspaceIndicator workspaceIndicator;
	ClockWidget clock;

	bool update = true;
	int second = 0;

	//Switcher switcher;

	App app;

	Widget[] widgets;

	this(App app){
		this.app = app;
		properties = new PropertyList;
		auto screens = screens(wm.displayHandle);

		taskList = addNew!TaskList(this);
		powerButton = addNew!PowerButton(this);
		powerButton.hide;

		battery = addNew!Battery;
		widgets ~= battery;

		workspaceIndicator = addNew!WorkspaceIndicator;
		widgets ~= workspaceIndicator;

		clock = addNew!ClockWidget;
		widgets ~= clock;

		super(screens[0].w, 24, "flatman bar");

		if(autohide){
			resize([size.w, 1]);
			hidden = true;
		}else
			resize(size);
	}

	void systray(bool enable){
		if(enable && !tray){
			tray = addNew!Tray(this);
			tray.resize(size);
			tray.change ~= (int clients){
				tray.move([size.w-clients*size.h - draw.width("000:0 00:00:00") - 20, 0]);
			};
		}else if(!enable && tray){
			tray.destroy;
			tray = null;
		}
	}

	override void show(){
		workspace = new Property!(XA_CARDINAL, false)(windowHandle, "_NET_WM_DESKTOP");
		workspace = -1;

		currentWindow = new Property!(XA_WINDOW, false)(.root, "_NET_ACTIVE_WINDOW", properties);
		currentWindow ~= (x11.X.Window window){
			foreach(client; app.clients){
				if(client.window == window){
					currentClient = client;
					break;
				}
			}
		};

		strut = new Property!(XA_CARDINAL, true)(windowHandle, "_NET_WM_STRUT_PARTIAL", properties);
		strut = [0, 0, size.h, 0, 0, 0, 0, 0, pos.x, pos.x+size.w, 0, 0];

		super.show;
	}

	override void drawInit(){
		_draw = new XDraw(this);
		draw.setFont("Segoe UI", 10);
		glow = generateGlow([0.877, 0.544, 0]);
		initAlpha;
	}

	override void onDestroy(){
		if(tray)
			tray.destroy;
		super.onDestroy;
	}

	void tick(){
		foreach(w; widgets)
			w.tick;
		foreach(w; widgets){
			if(w.savedWidth != w.width){
				w.savedWidth = w.width;
				resized(size);
			}
		}
	}

	override void onDraw(){
		tick;
		auto time = Clock.currTime;
		if(update || time.second != second){
			if(update)
				taskList.update(app.clients);

			//if(tray)
			//	tray.update;
			draw.setColor(config.theme.background);
			draw.rect([0,0], size);
			draw.setColor(config.theme.border);
			draw.rect([0,0], [size.w,1]);

			super.onDraw;
    		version(CompilePlugins){
				app.plugins.event("draw");
			}

			second = time.second;
			update = false;
		}
	}

	override void moved(int[2] pos){
		super.moved(pos);
		strut = [0, 0, size.h, 0, 0, 0, 0, 0, pos.x, pos.x+size.w, 0, 0];
		writeln("moved ", pos);
	}

	override void resized(int[2] size){
		super.resized(size);
		writeln("resized ", size);
		powerButton.move([size.w-size.h, 0]);
		powerButton.resize([size.h, size.h]);
		taskList.resize(size.a - [size.h*2, 0]);
		taskList.move([size.h, 0]);
		if(tray){
			tray.resize(size);
			tray.move([size.w-tray.clients.length.to!int*size.h - battery.width - 40 - draw.width("00:00:00") - 20 - 40, 0]);
		}
		battery.resize([battery.width, size.h]);
		battery.move([size.w-battery.width-clock.width-20, 0]);
		clock.resize([clock.width, size.h]);
		clock.move([size.w-clock.width, 0]);
		onDraw;
	}

}
