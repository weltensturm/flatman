module dock.dock;

import dock;

__gshared:


Display* dpy;
ulong root;

extern(C) nothrow int function(Display *, XErrorEvent *) xerrorxlib;


WorkspaceDock dockWindow;

Composite composite;

Rect[x11.X.Window] damage;


enum wallpaperAtoms = [
	"_XROOTPMAP_ID",
	"_XSETROOT_ID",
];


bool running = true;


extern(C) nothrow @nogc @system void stop(int){
	running = false;
}


void main(){
	try {
		signal(SIGINT, &stop);
		xerrorxlib = XSetErrorHandler(&xerror);
		dockWindow = new WorkspaceDock(400, 300, "flatman-dock");
		dockWindow.init;
		composite = new Composite;
		wm.add(dockWindow);
		while(wm.hasActiveWindows && running){
			auto frameStart = now;
			wm.processEvents;
			dockWindow.onDraw;
			dockWindow.tick;
			auto frameEnd = now;
			Thread.sleep(((frameStart + 1.0/60.0 - frameEnd).max(0)*1000).lround.msecs);
		}
	}catch(Throwable t){
		writeln(t);
	}
}


x11.X.Window[] windows(){
	XFlush(wm.displayHandle);
	XGrabServer(wm.displayHandle);
	x11.X.Window root_return, parent_return;
	x11.X.Window* children;
	x11.X.Window[] wins;
	uint nchildren;
	XQueryTree(wm.displayHandle, root, &root_return, &parent_return, &children, &nchildren);
	if(children){
		foreach(window; children[0..nchildren])
			wins ~= window;
		XFree(children);
	}
	XUngrabServer(wm.displayHandle);
	XFlush(wm.displayHandle);
	return wins;
}



Atom atom(string name){
	return XInternAtom(dpy, name.toStringz, false);
}



class Composite {

	Picture picture;
	Picture transparency;

	int[4] clipInfo = [0,0,int.max,int.max];

	this(){
		foreach(i; 0..ScreenCount(dpy))
		    XCompositeRedirectSubwindows(dpy, RootWindow(dpy, i), 0);
		auto visual = DefaultVisual(wm.displayHandle, 0);
    	auto format = XRenderFindVisualFormat(dpy, visual);
		XRenderPictureAttributes pa;
		picture = XRenderCreatePicture(dpy, (cast(XDraw)dockWindow._draw).drawable, format, CPSubwindowMode, &pa);
		transparency = colorPicture(false, 0.7, 0, 0, 0);
	}

	void clip(int[2] pos, int[2] size){
		clipInfo = pos ~ size;
	}

	void noclip(){
		clipInfo = [0,0,int.max,int.max];
	}

	void draw(CompositeClient window, int[2] pos, int[2] size, bool ghost=false){

		XTransform xform = {[
		    [XDoubleToFixed( window.size.w.to!double/size.w ), XDoubleToFixed( 0 ), XDoubleToFixed(     0 )],
		    [XDoubleToFixed( 0 ), XDoubleToFixed( window.size.h.to!double/size.h ), XDoubleToFixed(     0 )],
		    [XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( 1 )]
		]};
		XRenderSetPictureTransform(dpy, window.picture, &xform);

		XRenderComposite(
			dpy,
			window.hasAlpha || ghost ? PictOpOver : PictOpSrc,
			window.picture,
			ghost ? transparency : None,
            picture,
            0, 0,
            0, 0,
            pos.x, dockWindow.size.h-pos.y-size.h,
            size.w, size.h
        );
	}

	void rect(int[2] pos, int[2] size, float[4] color, bool src=false){
		XRenderColor c = {
			(color[0]*0xffff).to!ushort,
			(color[1]*0xffff).to!ushort,
			(color[2]*0xffff).to!ushort,
			(color[3]*0xffff).to!ushort
		};
		XRenderFillRectangle(wm.displayHandle, src ? PictOpSrc : PictOpOver, picture, &c, pos.x, dockWindow.size.h-size.h-pos.y, size.w, size.h);
	}

	void render(Picture p, int[2] pos, int[2] size){

		XRenderComposite(wm.displayHandle, PictOpSrc, p, None, picture, 0,0,0,0,pos.x,dockWindow.size.h-size.h-pos.y,size.x,size.y);
	}

	Picture colorPicture(bool argb, double a, double r, double g, double b){
		auto pixmap = XCreatePixmap(wm.displayHandle, root, 1, 1, argb ? 32 : 8);
		if(!pixmap)
			return None;
		XRenderPictureAttributes pa;
		pa.repeat = True;
		auto picture = XRenderCreatePicture(wm.displayHandle, pixmap, XRenderFindStandardFormat(wm.displayHandle, argb 	? PictStandardARGB32 : PictStandardA8), CPRepeat, &pa);
		if(!picture){
			XFreePixmap(wm.displayHandle, pixmap);
			return None;
		}
		XRenderColor c;
		c.alpha = (a * 0xffff).to!ushort;
		c.red =   (r * 0xffff).to!ushort;
		c.green = (g * 0xffff).to!ushort;
		c.blue =  (b * 0xffff).to!ushort;
		XRenderFillRectangle(wm.displayHandle, PictOpSrc, picture, &c, 0, 0, 1, 1);
		XFreePixmap(wm.displayHandle, pixmap);
		return picture;
	}

}


struct Rect {
	int[2] pos;
	int[2] size;
}


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


class WorkspaceDock: ws.wm.Window {

	Property!(XA_CARDINAL, false) workspaceCountProperty;
	long workspaceCount;

	Property!(XA_CARDINAL, false) workspaceProperty;
	long workspace;
	bool canSwitch;
	int[2] screenSize;
	int[2] screenPos;
	
	Property!(XA_STRING, false) workspaceNamesProperty;
	string[] workspaceNames;
	ubyte[3][] workspaceColors;
	Picture root_picture;

	CompositeClient[] clients;
	x11.X.Window[] windows;
	CompositeClient[][long] workspaces;

	double showTime;
	bool focus;

	Pid launcher;

	Watcher!(x11.X.Window) windowWatcher;

	long activeBgPos = 0;

	int damage_event, damage_error;

	this(int w, int h, string title){
		dpy = wm.displayHandle;
		.root = XDefaultRootWindow(dpy);

		XDamageQueryExtension(dpy, &damage_event, &damage_error);
		
		auto screens = screens;
		screenSize = [screens[0].w, screens[0].h];
		screenPos = [screens[0].x, screens[0].y];
		
		workspaceProperty = new Property!(XA_CARDINAL, false)(dock.root, "_NET_CURRENT_DESKTOP");
		workspace = workspaceProperty.get;
		canSwitch = true;

		workspaceCountProperty = new Property!(XA_CARDINAL, false)(dock.root, "_NET_NUMBER_OF_DESKTOPS");
		workspaceCount = workspaceCountProperty.get;
		
		workspaceNamesProperty = new Property!(XA_STRING, false)(dock.root, "_NET_DESKTOP_NAMES");
		auto names = workspaceNamesProperty.get.split('\0');
		if(names.length)
			workspaceNames = names[0..$-1];

		w = (screenSize.w/8).to!int;

		super(w, cast(int)screenSize.h, title);
		move([screens[0].x, screens[0].y]);

		wm.handlerAll[CreateNotify] ~= e => evCreate(e.xcreatewindow.window);
		wm.handlerAll[DestroyNotify] ~= e => evDestroy(e.xdestroywindow.window);
		wm.handlerAll[ConfigureNotify] ~= e => evConfigure(e);
		wm.handlerAll[MapNotify] ~= e => evMap(&e.xmap);
		wm.handlerAll[UnmapNotify] ~= e => evUnmap(&e.xunmap);
		wm.handlerAll[PropertyNotify] ~= e => evProperty(&e.xproperty);
		wm.handlerAll[damage_event+XDamageNotify] ~= e => evDamage(cast(XDamageNotifyEvent*)e);

		XSelectInput(wm.displayHandle, .root,
			StructureNotifyMask
		    | SubstructureNotifyMask
		    | ExposureMask
		    | PropertyChangeMask);
		updateWallpaper;

	}

	void init(){
		XFlush(wm.displayHandle);
		XGrabServer(wm.displayHandle);
		x11.X.Window root_return, parent_return;
		x11.X.Window* children;
		uint nchildren;
		XQueryTree(wm.displayHandle, .root, &root_return, &parent_return, &children, &nchildren);
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

	void updateWallpaper(){
		bool fill = false;
		if(root_picture)
			XRenderFreePicture(dpy, root_picture);
		Pixmap pixmap = None;
		// Get the values of background attributes
		auto rootmapId = new Property!(XA_PIXMAP, false)(.root, "_XROOTPMAP_ID");
		auto setrootId = new Property!(XA_PIXMAP, false)(.root, "_XSETROOT_ID");
		foreach(bgprop; [rootmapId, setrootId]){
			auto res = bgprop.get;
			if(res){
				pixmap = res;
				break;
			}
		}
		// Make sure the pixmap we got is valid
		//if(pixmap && !validate_pixmap(ps, pixmap))
		//	pixmap = None;
		// Create a pixmap if there isn't any
		if(!pixmap){
			pixmap = XCreatePixmap(wm.displayHandle, .root, 1, 1, DefaultDepth(wm.displayHandle, 0));
			fill = true;
		}
		// Create Picture
		XRenderPictureAttributes pa;
		pa.repeat = True,
		root_picture = XRenderCreatePicture(wm.displayHandle, pixmap, XRenderFindVisualFormat(wm.displayHandle, DefaultVisual(wm.displayHandle, 0)), CPRepeat, &pa);
		//XFreePixmap(dpy, pixmap);
		// Fill pixmap if needed
		if(fill){
			XRenderColor c;
			c.red = c.green = c.blue = 0x8080;
			c.alpha = 0xffff;
			XRenderFillRectangle(wm.displayHandle, PictOpSrc, root_picture, &c, 0, 0, 1, 1);
		}
		XTransform xform = {[
		    [XDoubleToFixed( 1 ), XDoubleToFixed( 0 ), XDoubleToFixed(     0 )],
		    [XDoubleToFixed( 0 ), XDoubleToFixed( 1 ), XDoubleToFixed(     0 )],
		    [XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( (this.size.w.to!double-12)/screenSize.w )]
		]};
		XRenderSetPictureTransform(dpy, root_picture, &xform);
		XRenderSetPictureFilter(dpy, root_picture, "best", null, 0);
	}

	void evCreate(x11.X.Window window){
		XWindowAttributes wa;
		if(window == dockWindow.windowHandle || !XGetWindowAttributes(wm.displayHandle, window, &wa))
			return;
		if(wa.c_class == InputOnly)
			return;
		auto client = new CompositeClient(window, [wa.x,wa.y], [wa.width,wa.height], wa);
		"found window %s".format(window).writeln;
		clients ~= client;
	}

	void evDestroy(x11.X.Window window){
		foreach(i, c; clients){
			if(c.windowHandle == window){
				c.destroy;
				clients = clients.without(c);
				return;
			}
		}
	}

	void evDamage(XDamageNotifyEvent* e){
		damage[e.drawable] = Rect([e.area.x, e.area.y], [e.area.width, e.area.height]);
        XDamageSubtract(dpy, e.damage, None, None);
	}

	void evConfigure(XEvent* e){
		if(e.xconfigure.window == .root){
			screenSize = [screens[0].w, screens[0].h];
			screenPos = [screens[0].x, screens[0].y];
			resize([size.w, screenSize.h]);
		}
		else if(e.xconfigure.window == windowHandle)
			return;
		foreach(i, c; clients){
			if(c.windowHandle == e.xconfigure.window){
				c.processEvent(e);
				updateStack;
				return;
			}
		}
		"could not configure window %s".format(e.xconfigure.window).writeln;
	}

	void evMap(XMapEvent* e){
		foreach(i, c; clients){
			if(c.windowHandle == e.window){
				c.onShow;
				updateStack;
				return;
			}
		}
		evCreate(e.window);
	}

	void evUnmap(XUnmapEvent* e){
		foreach(c; clients){
			if(c.windowHandle == e.window){
				c.onHide;
				return;
			}
		}
	}

	void evProperty(XPropertyEvent* e){
		if(e.window == .root){
			if(e.atom == workspaceProperty.property){
				auto ws = workspaceProperty.get;
				if(ws == workspace)
					canSwitch = true;
				if(canSwitch)
					workspace = ws;
				showTime = now+0.5;
			}else if(e.atom == workspaceCountProperty.property){
				workspaceCount = workspaceCountProperty.get;
				showTime = now+0.5;
				canSwitch = true;
			}else if(e.atom == workspaceNamesProperty.property){
				workspaceNames = workspaceNamesProperty.get.split('\0')[0..$-1];
				import std.digest.md;
				workspaceColors = [];
				foreach(i, n; workspaceNames)
					workspaceColors ~= digest!MD5(n)[0..3];
			}else if(wallpaperAtoms.map!(s => s.atom).canFind(e.atom)){
				updateWallpaper;
			}else
				return;
			update;
		}else{
			foreach(c; clients){
				if(c.windowHandle == e.window){
					if(e.atom == c.workspaceProperty.property){
						c.workspace = c.workspaceProperty.get;
					}
				}
			}
		}
	}

	void updateStack(){
		XGrabServer(wm.displayHandle);
		x11.X.Window root_return, parent_return;
		x11.X.Window* children;
		uint nchildren;
		XQueryTree(wm.displayHandle, .root, &root_return, &parent_return, &children, &nchildren);
		if(children){
			auto clientsOld = clients;
			clients = [];
			outer:foreach(window; children[0..nchildren]){
				foreach(c; clientsOld){
					if(c.windowHandle == window){
						clients ~= c;
						continue outer;
					}
				}
			}
			XFree(children);
		}
		XUngrabServer(wm.displayHandle);
		update;
	}

	override void gcInit(){}

	override void show(){
		auto windowWorkspace = new Property!(XA_CARDINAL, false)(windowHandle, "_NET_WM_DESKTOP");
		windowWorkspace.set(-1);
		new Property!(XA_ATOM, false)(windowHandle, "_NET_WM_WINDOW_TYPE").set(atom("_NET_WM_WINDOW_TYPE_DIALOG"));
		super.show;
	}

	override void drawInit(){
		_draw = new XDraw(this);
		_draw.setFont("Consolas", 9);
	}

	override void resize(int[2] size){
		super.resize(size);
		draw.resize(size);
	}

	void tick(){
		int targetX = cast(int)screenSize.w-(visible ? size.w : 1)+screenPos.x.to!int;
		if(pos.x != targetX || pos.y != 0){
			//XMoveResizeWindow(dpy, windowHandle, targetX, 0, visible ? (screenSize.w/10).to!int : 2, size.h);
			XMoveWindow(dpy, windowHandle, targetX, 0);
			//XRaiseWindow(dpy, windowHandle);
		}
	}

	bool visible(){
		return showTime > now || focus;
	}

	void update(){
		XMapWindow(dpy, windowHandle);
		XSync(dpy, false);
		foreach(c; children)
			remove(c);
		auto count = workspaceCount*2+1;
		auto ratio = screenSize.w/cast(double)screenSize.h;
		auto height = cast(int)(size.w/ratio)-3;
		workspaces = workspaces.init;
		foreach(c; clients){
			if(!c.hidden){
				if(c.workspace == -1)
					foreach(ws; workspaces)
						ws ~= c;
				else
					workspaces[c.workspace] ~= c;
			}
		}
		int[] desktopsHeight;
		foreach(i; 0..count){
			bool empty = i % 2 == 0;
			bool combined = ((i+1)/2 > 0 && (i+1)/2 < workspaceNames.length && workspaceNames[$-(i+1)/2-1] == workspaceNames[$-(i+1)/2]);
			desktopsHeight ~= empty ? (combined ? 2 : (draw.fontHeight).to!int) : height;
		}

		auto heightSum = desktopsHeight.reduce!"a+b";
		auto resizeRatio = ((size.h-draw.fontHeight*2-10).to!double/heightSum).min(1);

		int y = size.h/2 - heightSum.min(size.h-draw.fontHeight*2-10)/2;

		foreach(i; 0..count){
			bool empty = i % 2 == 0;
			auto ws = addNew!WorkspaceView(this, count-1-i, empty);
			if(i/2 < workspaceNames.length && i/2 >= 0)
				ws.name = workspaceNames[$-i/2-1];
			if(i/2 < workspaceColors.length && i/2 >= 0)
				ws.color = workspaceColors[$-i/2-1];
			ws.resize([(height*ratio*resizeRatio).lround.to!int, (desktopsHeight[i]*resizeRatio).lround.to!int]);
			ws.move([size.w/2-ws.size.w/2, y]);
			ws.combined = (i/2 > 0 && i/2 < workspaceNames.length && workspaceNames[$-i/2-1] == workspaceNames[$-i/2]);
			ws.update;
			y += ws.size.h;
		}

	}

	override void onDraw(){
		if(!visible)
			return;
		//composite.rect([0,0], size, [0.05,0.05,0.05,0.5], true);
		draw.setColor(0x222222);
		draw.rect([0,0], size);

		auto ratio = screenSize.w/cast(double)screenSize.h;
		auto height = cast(int)(size.w/ratio)+6;
		//draw.setColor([0.867,0.514,0]);
		//draw.rect(pos.a+[3,activeBgPos], [size.w-6, height-6]);

		super.onDraw;
		draw.setColor([0.6,0.6,0.6]);
		auto time = Clock.currTime;
		draw.text([size.w/2-draw.width("00:00:00 - 0000-00-00")/2, 5], "%02d:%02d:%02d - %04d-%02d-%02d".format(time.hour, time.minute, time.second, time.year, time.month, time.day), 0);
		draw.finishFrame;
	}

	override void onMouseFocus(bool focus){
		this.focus = focus;
		if(focus)
			showTime = now+0.3;
	}
	
	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if((button == Mouse.wheelDown || button == Mouse.wheelUp) && pressed){
			auto selectedWorkspace = workspace + (button == Mouse.wheelDown ? 1 : -1);
			if(selectedWorkspace >= 0 && selectedWorkspace < workspaces.length){
				canSwitch = false;
				workspace = selectedWorkspace;
				workspaceProperty.request([workspace, CurrentTime]);
			}
		}else
			super.onMouseButton(button, pressed, x, y);
	}

}

class Ghost: Base {

	CompositeClient window;
	int desktopSource;

	this(CompositeClient window, int desktopSource){
		this.window = window;
		this.desktopSource = desktopSource;
	}

	override void onDraw(){
		if(window.picture)
			composite.draw(window, pos, size, true);
		draw.setColor([0.8,0.8,0.8]);
		draw.rectOutline(pos, size);
	}

}


extern(C) nothrow int xerror(Display* dpy, XErrorEvent* e){
	try {
		char[128] buffer;
		XGetErrorText(wm.displayHandle, e.error_code, buffer.ptr, buffer.length);
		"XError: %s (major=%s, minor=%s, serial=%s)".format(buffer.to!string, e.request_code, e.minor_code, e.serial).writeln;
	}
	catch {}
	return 0;
}
