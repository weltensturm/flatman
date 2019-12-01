module bar.bar;

import bar;

import
	common.log,
	common.xevents;


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
	Property!(XA_CARDINAL, true) strutProperty;

	Client currentClient;

	bool autohide = false;

	string alignment;

	bool overviewOnly;
	bool strut;

	bool hidden;

	Picture glow;

	TaskList taskList;
	Tray tray;
	Battery battery;
	WorkspaceIndicator workspaceIndicator;
	ClockWidget clock;

	PropertyList properties;

	bool update = true;
	int second = 0;

	//Switcher switcher;

	App app;

	Widget[] widgets;

	this(App app, string barName, bool strut, bool overviewOnly){
		Log("creating bar - " ~ barName);
		this.app = app;
		this.strut = strut && !overviewOnly;
		this.overviewOnly = overviewOnly;
		auto screens = screens(wm.displayHandle);

		if(!overviewOnly){
			workspaceIndicator = addNew!WorkspaceIndicator;
			workspaceIndicator.alignment = Widget.Alignment.left;
			widgets ~= workspaceIndicator;

			taskList = addNew!TaskList(this);
			taskList.alignment = Widget.Alignment.center;
			widgets ~= taskList;

			tray = addNew!Tray(this);
			tray.alignment = Widget.Alignment.right;
			widgets ~= tray;

			battery = addNew!Battery;
			battery.alignment = Widget.Alignment.right;
			widgets ~= battery;

			clock = addNew!ClockWidget;
			clock.alignment = Widget.Alignment.right;
			widgets ~= clock;
		}else{
			widgets ~= addNew!WorkspaceList;
		}

		super(screens[0].w, 24, "flatman bar - " ~ barName);

		if(autohide){
			resize([size.w, 1]);
			hidden = true;
		}else
			resize(size);

		properties = new PropertyList;

        auto state = new Property!(XA_ATOM, true)(windowHandle, "_NET_WM_STATE");
        state = [Atoms._NET_WM_STATE_SKIP_PAGER, Atoms._NET_WM_STATE_SKIP_TASKBAR, Atoms._NET_WM_STATE_STICKY];

        auto motifHints = new Property!(XA_CARDINAL, true)(windowHandle, "_MOTIF_WM_HINTS");
        motifHints = [2, 0, 0, 0, 0];

        auto windowType = new Property!(XA_ATOM, false)(windowHandle, "_NET_WM_WINDOW_TYPE");
        windowType = Atoms._NET_WM_WINDOW_TYPE_DOCK;

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

		strutProperty = new Property!(XA_CARDINAL, true)(windowHandle, "_NET_WM_STRUT_PARTIAL", properties);
		if(this.strut){
			strutProperty = [0, 0, size.h, 0, 0, 0, 0, 0, pos.x, pos.x+size.w, 0, 0];
		}

		Events ~= this;

	}

	void systray(bool enable){
		if(!tray)
			return;
		if(enable){
			tray.enable;
		}else if(!enable){
			tray.disable;
		}
	}

	override void drawInit(){
		_draw = new XDraw(this);
		draw.setFont("Segoe UI", 10);
		glow = generateGlow([0.877, 0.544, 0]);
	}

	override void close(){
		Events.forget(this);
		widgets.each!(a => a.destroy);
		XRenderFreePicture(dpy, glow);
		super.close;
	}

	void tick(){
		foreach(w; widgets)
			w.tick;
		bool layout;
		foreach(w; widgets){
			if(w.savedWidth != w.width){
				w.savedWidth = w.width;
				layout = true;
			}
		}
		if(layout)
			this.layout();
	}

	override void onDraw(){
		draw.clear;
		tick;
		auto time = Clock.currTime;
		if(update || time.second != second){
			if(update && taskList)
				taskList.update(app.clients);

			draw.setColor(config.theme.background);
			draw.rect([0,0], size);
			draw.setColor(config.theme.border);
			draw.rect([0,0], [size.w,1]);

			super.onDraw;

			second = time.second;
			update = false;
		}
	}

	override void moved(int[2] pos){
		super.moved(pos);
		if(strut){
			strutProperty = [0, 0, size.h, 0, 0, 0, 0, 0, pos.x, pos.x+size.w, 0, 0];
		}
	}

	override void resized(int[2] size){
		super.resized(size);
		if(strut){
			strutProperty = [0, 0, size.h, 0, 0, 0, 0, 0, pos.x, pos.x+size.w, 0, 0];
		}
		layout;
		onDraw;
	}

	void layout(){
		int left = config.theme.padding;
		foreach(w; widgets.filter!(a => a.alignment == Widget.Alignment.left)){
			w.move([left, 0]);
			w.resize([w.savedWidth, size.h]);
			left += w.savedWidth + config.theme.padding;
		}
		int right = config.theme.padding;
		foreach_reverse(w; widgets.filter!(a => a.alignment == Widget.Alignment.right).array){
			w.move([size.w - w.savedWidth - right, 0]);
			w.resize([w.savedWidth, size.h]);
			right += w.savedWidth + config.theme.padding;
		}
		foreach(w; widgets){
			if(w.alignment == Widget.Alignment.center){
				w.move([left.max(right), 0]);
				w.resize([size.w - left.max(right)*2, size.h]);
			}
		}
		onDraw;
	}

    @WindowMap
	void evMap(WindowHandle){
		update = true;
	}

    @WindowUnmap
	void evUnmap(WindowHandle){
		update = true;
	}

    @WindowProperty
	void evProperty(WindowHandle, XPropertyEvent* e){
		properties.update(e);
		update = true;
	}

	@Overview
	void onOverview(bool on){
		if(overviewOnly){
			if(on)
				show;
			else
				hide;
		}
	}

}
