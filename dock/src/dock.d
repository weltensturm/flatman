module dock.dock;

import dock;

__gshared:


Display* dpy;
ulong root;

extern(C) nothrow int function(Display *, XErrorEvent *) xerrorxlib;


WorkspaceDock dockWindow;

Composite composite;


void main(){
	try {
		xerrorxlib = XSetErrorHandler(&xerror);
		dockWindow = new WorkspaceDock(400, 300, "flatman-dock");
		dockWindow.init;
		composite = new Composite;
		wm.add(dockWindow);
		while(wm.hasActiveWindows){
			auto frameStart = Clock.currSystemTick.msecs/1000.0;
			wm.processEvents;
			dockWindow.onDraw;
			dockWindow.tick;
			auto frameEnd = Clock.currSystemTick.msecs/1000.0;
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

	this(){
		foreach(i; 0..ScreenCount(dpy))
		    XCompositeRedirectSubwindows(dpy, RootWindow(dpy, i), 0);
		auto visual = DefaultVisual(wm.displayHandle, 0);
    	auto format = XRenderFindVisualFormat(dpy, visual);
		XRenderPictureAttributes pa;
		picture = XRenderCreatePicture(dpy, (cast(XDraw)dockWindow._draw).drawable, format, CPSubwindowMode, &pa);
		transparency = colorPicture(false, 0.7, 0, 0, 0);
	}

	void draw(CompositeClient window, int[2] pos, int[2] size, bool ghost=false){
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

	void rect(int[2] pos, int[2] size, float[4] color){
		XRenderColor c = {
			(color[0]*0xffff).to!ushort,
			(color[1]*0xffff).to!ushort,
			(color[2]*0xffff).to!ushort,
			(color[3]*0xffff).to!ushort
		};
		XRenderFillRectangle(wm.displayHandle, PictOpOver, picture, &c, pos.x, dockWindow.size.h-size.h-pos.y, size.w, size.h);
	}

	void render(Picture p, int[2] pos, int[2] size){

		XRenderComposite(wm.displayHandle, PictOpSrc, p, None, picture, 0,0,0,0,pos.x+6,dockWindow.size.h-size.h-pos.y+6,size.x-12,size.y-12);
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

class WorkspaceDock: ws.wm.Window {

	Property!(XA_CARDINAL, true) screenSizeProperty;
	long[] screenSize;
	
	Property!(XA_CARDINAL, false) workspaceCountProperty;
	long workspaceCount;

	Property!(XA_CARDINAL, false) workspaceProperty;
	long workspace;
	bool canSwitch;
	
	Property!(XA_STRING, false) workspaceNamesProperty;
	string[] workspaceNames;
	
	Picture root_picture;

	CompositeClient[] clients;
	x11.X.Window[] windows;
	CompositeClient[][long] workspaces;

	long showTime;
	bool focus;

	Pid launcher;

	Watcher!(x11.X.Window) windowWatcher;

	long activeBgPos = 0;

	this(int w, int h, string title){
		dpy = wm.displayHandle;
		.root = XDefaultRootWindow(dpy);
		
		screenSizeProperty = new Property!(XA_CARDINAL, true)(dock.root, "_NET_DESKTOP_GEOMETRY");
		screenSize = screenSizeProperty.get;
		
		workspaceProperty = new Property!(XA_CARDINAL, false)(dock.root, "_NET_CURRENT_DESKTOP");
		canSwitch = true;

		workspaceCountProperty = new Property!(XA_CARDINAL, false)(dock.root, "_NET_NUMBER_OF_DESKTOPS");
		workspaceCount = workspaceCountProperty.get;
		
		workspaceNamesProperty = new Property!(XA_STRING, false)(dock.root, "_NET_DESKTOP_NAMES");
		workspaceNames = workspaceNamesProperty.get.split('\0')[0..$-1];
		writeln(workspaceNames);

		w = cast(int)(screenSize.w/10);

		super(w, cast(int)screenSize.h, title);

		wm.handlerAll[CreateNotify] ~= e => evCreate(e.xcreatewindow.window);
		wm.handlerAll[DestroyNotify] ~= e => evDestroy(e.xdestroywindow.window);
		wm.handlerAll[ConfigureNotify] ~= e => evConfigure(e);
		wm.handlerAll[MapNotify] ~= e => evMap(&e.xmap);
		wm.handlerAll[UnmapNotify] ~= e => evUnmap(&e.xunmap);
		wm.handlerAll[PropertyNotify] ~= e => evProperty(&e.xproperty);

		XSelectInput(wm.displayHandle, .root,
		    SubstructureNotifyMask
		    | ExposureMask
		    | PropertyChangeMask);
		get_root_tile;

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

	void get_root_tile(){
		bool fill = false;
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
		// Fill pixmap if needed
		if(fill){
			XRenderColor c;
			c.red = c.green = c.blue = 0x8080;
			c.alpha = 0xffff;
			XRenderFillRectangle(wm.displayHandle, PictOpSrc, root_picture, &c, 0, 0, 1, 1);
		}
		auto root_pixmap = pixmap;
		version(CONFIG_VSYNC_OPENGL){
			if (BKEND_GLX == ps.o.backend)
				return glx_bind_pixmap(ps, &root_tile_paint.ptex, root_pixmap, 0, 0, 0);
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

	void evConfigure(XEvent* e){
		if(e.xconfigure.window == windowHandle)
			return;
		foreach(i, c; clients){
			if(c.windowHandle == e.xconfigure.window){
				c.processEvent(*e);
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
				showTime = Clock.currSystemTick.msecs+300;
			}else if(e.atom == workspaceCountProperty.property){
				workspaceCount = workspaceCountProperty.get;
				showTime = Clock.currSystemTick.msecs+300;
			}else if(e.atom == screenSizeProperty.property){
				screenSize = screenSizeProperty.get;
			}else if(e.atom == workspaceNamesProperty.property){
				workspaceNames = workspaceNamesProperty.get.split('\0')[0..$-1];
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
		/+
		auto type = [
			atom("_NET_WM_WINDOW_TYPE_DOCK"),
			atom("_NET_WM_WINDOW_TYPE_DIALOG"),
		];
		new Property!(XA_ATOM, true)(windowHandle, "_NET_WM_WINDOW_TYPE").setAtoms(type);
		+/
		super.show;
	}

	override void drawInit(){
		_draw = new XDraw(dpy, DefaultScreen(dpy), windowHandle, size.w, size.h);
		_draw.setFont("Consolas", 9);
	}

	override void resize(int[2] size){
		super.resize(size);
		draw.resize(size);
	}

	override void onDraw(){
		if(!visible)
			return;
		draw.setColor([0.05,0.05,0.05]);
		draw.rect([0,0], size);

		auto ratio = screenSize.w/cast(double)screenSize.h;
		auto height = cast(int)(size.w/ratio)+6;
		draw.setColor([0.867,0.514,0]);
		draw.rect(pos.a+[3,activeBgPos], [size.w-6, height-6]);

		super.onDraw;
		draw.setColor([0.6,0.6,0.6]);
		auto time = Clock.currTime;
		draw.text([size.w/2-draw.width("00:00:00 - 0000-00-00")/2, 5], "%02d:%02d:%02d - %04d-%02d-%02d".format(time.hour, time.minute, time.second, time.year, time.month, time.day), 0);
		draw.finishFrame;
	}

	void tick(){
		int targetX = cast(int)screenSize.w-(visible ? size.w : 1);
		if(pos.x != targetX || pos.y != 0){
			XMoveWindow(dpy, windowHandle, targetX, 0);
			//XRaiseWindow(dpy, windowHandle);
		}
	}

	bool visible(){
		return showTime > Clock.currSystemTick.msecs || focus;
	}

	void update(){
		XMapWindow(dpy, windowHandle);
		XSync(dpy, false);
		foreach(c; children)
			remove(c);
		auto count = workspaceCount*2+1;
		auto ratio = screenSize.w/cast(double)screenSize.h;
		auto height = cast(int)(size.w/ratio)+6;
		workspaces = workspaces.init;
		foreach(c; clients){
			if(!c.hidden)
				workspaces[c.workspace] ~= c;
		}
		int[] desktopsHeight;
		foreach(i; 0..count){
			bool empty = i % 2 == 0;
			desktopsHeight ~= empty ? (draw.fontHeight/1.4).to!int : height;
		}
		int y = size.h/2 - desktopsHeight.reduce!"a+b"/2;

		foreach(i; 0..count){
			bool empty = i % 2 == 0;
			auto ws = addNew!WorkspaceView(this, count-1-i, empty);
			if(i/2 < workspaceNames.length && i/2 >= 0)
				ws.name = workspaceNames[$-i/2-1];
			ws.move([0, y]);
			ws.resize([size.w, desktopsHeight[i]]);
			ws.update;
			y += ws.size.h;
		}
	}

	override void onMouseFocus(bool focus){
		this.focus = focus;
		if(showTime < Clock.currSystemTick.msecs)
			showTime = Clock.currSystemTick.msecs+300;
	}
	
	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if((button == Mouse.wheelDown || button == Mouse.wheelUp) && pressed){
			auto newWorkspace = workspace + (button == Mouse.wheelDown ? 1 : -1);
			if(newWorkspace >= 0 && newWorkspace+1 < workspaces.length){
				canSwitch = false;
				workspace = newWorkspace;
				workspaceProperty.request([workspace, CurrentTime]);
			}
		}else
			super.onMouseButton(button, pressed, x, y);
	}

}


class WorkspaceView: Base {

	long id;
	WorkspaceDock dock;
	string name = "~";
	bool preview;
	bool empty;

	this(WorkspaceDock dock, long id, bool empty){
		this.dock = dock;
		this.id = id/2;
		this.empty = empty;
	}

	override void resize(int[2] size){
		super.resize(size);
	}

	void update(){
		foreach(c; children)
			remove(c);
		auto scale = (size.w-12) / cast(double)dock.screenSize.w;
		if(id in dock.workspaces && !empty)
			foreach_reverse(w; dock.workspaces[id]){
				auto wv = addNew!WindowIcon(w, cast(int)id);
				auto y = w.pos.y;
				auto sh = dock.screenSize.y;
				while(y > sh)
					y -= sh;
				while(y < 0)
					y += sh;
				wv.moveLocal([
					6+cast(int)(w.pos.x*scale).lround,
					6+cast(int)((dock.screenSize.h-y-w.size.h)*scale).lround
				]);
				wv.resize([
					cast(int)(w.size.w*scale).lround,
					cast(int)(w.size.h*scale).lround
				]);
			}
	}

	override Base dropTarget(int x, int y, Base draggable){
		if(typeid(draggable) is typeid(Ghost))
			return this;
		return super.dropTarget(x, y, draggable);
	}

	override void dropPreview(int x, int y, Base draggable, bool start){
		preview = start;
	}

	override void drop(int x, int y, Base draggable){
		auto ghost = cast(Ghost)draggable;
		if(ghost.window.workspaceProperty.get != id){
			writeln("requesting window move to ", id);
			new Property!(XA_CARDINAL, false)(ghost.window.windowHandle, "_NET_WM_DESKTOP").request([id, 2, empty ? 1 : 0]);
		}
		preview = false;
	}

	override void onMouseFocus(bool focus){
		preview = focus;
	}

	override void onDraw(){
		if(preview || (id == dock.workspace && !empty)){
			if(id == dock.workspace && !empty)
				draw.setColor([0.867,0.514,0]);
			else
				draw.setColor([0.6,0.6,0.6]);
			dock.draw.rect(pos.a+[3,3], [size.w-6, size.h-6]);
		}

		if(!empty)
			composite.render(dockWindow.root_picture, pos, size);

		super.onDraw;

		if(!empty){
			composite.rect([pos.x+6, pos.y+6], [size.w-12, draw.fontHeight], [0,0,0,0.7]);
			//draw.rect(pos.a+[6,size.h-draw.fontHeight-6], [size.w-12, draw.fontHeight]);
			draw.setColor([0.1,0.1,0.1]);
			draw.setColor([0.867,0.867,0.867]);
			dock.draw.text(pos.a+[size.w/2,6], name, 0.5);
		}
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.buttonLeft && !pressed){
			dock.workspaceProperty.request([id, CurrentTime, empty ? 1 : 0]);
		}
		super.onMouseButton(button, pressed, x, y);
	}

}


class WindowIcon: Base {

	Base dragGhost;
	int[2] dragOffset;
	Base dropTarget;

	CompositeClient window;
	int desktop;

	this(CompositeClient window, int desktop){
		this.window = window;
		this.desktop = desktop;
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.buttonLeft){
			if(!pressed && dragGhost){
				root.remove(dragGhost);
				if(dropTarget)
					dropTarget.drop(x, y, dragGhost);
				dragGhost = null;
			}
		}
		super.onMouseButton(button, pressed, x, y);
	}

	override Base drag(int[2] offset){
		dragOffset = offset;
		return new Ghost(window, desktop);
	}

	override void onMouseMove(int x, int y){
		if(buttons.get(Mouse.buttonLeft, false) && !dragGhost){
			dragGhost = drag([x,y].a - pos);
			root.add(dragGhost);
			root.setTop(dragGhost);
			dragGhost.resize(size);
			writeln("dragStart");
		}
		if(dragGhost){
			dragGhost.move([x,y].a - dragOffset);
			if(root.dropTarget(x, y, dragGhost) != dropTarget){
				if(dropTarget)
					dropTarget.dropPreview(x, y, dragGhost, false);
				dropTarget = root.dropTarget(x, y, dragGhost);
				if(dropTarget)
					dropTarget.dropPreview(x, y, dragGhost, true);
			}
		}
		super.onMouseMove(x, y);
	}

	override void onDraw(){
		if(dragGhost)
			return;
		if(window.picture)
			composite.draw(window, pos, size);
		super.onDraw;
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