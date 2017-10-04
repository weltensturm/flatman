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

int[] battery;

class Bar: ws.wm.Window {

	int screen;

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

	App app;

	this(App app){
		this.app = app;
		properties = new PropertyList;
		auto screens = screens(wm.displayHandle);

		taskList = addNew!TaskList(this);
		powerButton = addNew!PowerButton(this);
		powerButton.hide;

		super(screens[0].w, 24, "flatman bar");

		tray = addNew!Tray(this);
		tray.resize(size);
		tray.change ~= (int clients){
			tray.move([size.w-clients*size.h - draw.width("000 00:00:00") - 20, 0]);
		};
		if(autohide){
			resize([size.w, 1]);
			hidden = true;
		}else
			resize(size);
	}

	override void show(){
		workspace = new Property!(XA_CARDINAL, false)(windowHandle, "_NET_WM_DESKTOP");
		workspace = -1;

		workspaceNames = new Property!(XA_STRING, false)(.root, "_NET_DESKTOP_NAMES", properties);

		currentWorkspace = new Property!(XA_CARDINAL, false)(.root, "_NET_CURRENT_DESKTOP", properties);

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
		strut = [0, 0, size.h, 0, 0, 0, 0, 0, 0, 0, 0, size.h];

		super.show;
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
				taskList.update(app.clients);
			
			draw.setColor(config.background);
			draw.rect([0,0], size);

			left = 200;
			auto names = workspaceNames.value.split('\0');
			if(currentWorkspace.value < names.length){
				draw.setColor(config.foreground);
				auto parts = names[currentWorkspace].split("/");
				auto x = draw.text([5,5], parts[0..$-1].join("/"));
				if(parts.length > 1)
					x += draw.text([5+x, 5], "/");
				draw.setColor(config.foregroundMain);
				draw.text([5+x, 5], parts[$-1]);
			}
			draw.setColor(config.border);
			draw.rect([0,0], [size.w,1]);

			enum baseline = 8.0;
			enum dangerRatio = 1/3.0;
			draw.setColor([0.5, 0.5, 0.5]);
			auto right = draw.width("0000 00:00:00")+10;
			try {
				auto match = ["acpi", "-b"].execute.output.matchFirst("([0-9]+)%, ((?:[0-9]+:?)+) (remaining|until charged)");
				writeln(match);
				if(!match.empty){
					auto split = match[2].split(":");
					auto hour = split[0].to!int;
					auto minute = split[1].to!int;
					auto percent = match[1].to!int;
					battery ~= hour*60+minute;
					if(battery.length > 5)
						battery = battery[$-5..$];

					auto avg = battery.sum/battery.length;

					if(match[3] == "until charged"){
						draw.setColor([0.3, 0.7, 0.3]);
					}else if(hour == 0)
						draw.setColor([1, 0, 0]);
					else if(hour*60+minute <= percent*baseline*dangerRatio)
						draw.setColor([1, 1, 0]);
					else
						draw.setColor([0.9, 0.9, 0.9]);
					right -= draw.text([size.w-right, 5], "%02d".format(match[1].to!int.min(99)), 0);
					draw.setColor([0.5, 0.5, 0.5]);
					draw.text([size.w-right, 5], "%02d".format(((hour*60+minute)/10).min(99)), 0);
				}
			}catch(Exception e){}

			draw.setColor(config.foreground);
			right = draw.width("00:00:00")+10;
			draw.text([size.w-right, 5], "%02d:%02d:%02d".format(time.hour, time.minute, time.second), 0);

			super.onDraw;
    		version(CompilePlugins){
				app.plugins.event("draw");
			}

			draw.finishFrame;

			second = time.second;
			update = false;
		}
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
			tray.move([size.w-tray.clients.length.to!int*size.h - draw.width("00:00:00") - 20, 0]);
		}
		onDraw;
	}

}
