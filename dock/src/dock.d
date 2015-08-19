module dock.dock;

import dock;

__gshared:


ulong root;

extern(C) nothrow int function(Display *, XErrorEvent *) xerrorxlib;


WorkspaceDock dockWindow;

Composite composite;


void main(){
	xerrorxlib = XSetErrorHandler(&xerror);
	dockWindow = new WorkspaceDock(400, 300, "flatman-dock");
	composite = new Composite;
	wm.add(dockWindow);
	while(wm.hasActiveWindows){
		wm.processEvents;
		dockWindow.onDraw;
		dockWindow.tick;
		Thread.sleep(10.msecs);
	}
}


Atom atom(string name){
	return XInternAtom(dpy, name.toStringz, false);
}


class CompositeClient: ws.wm.Window {
	
	bool hasAlpha;
	Picture picture;
	Pixmap pixmap;
	CardinalProperty desktop;
	
	this(x11.X.Window window, int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		super(window);
		XSelectInput(wm.displayHandle, windowHandle, StructureNotifyMask);
		isActive = true;
		createPicture;
		desktop = new CardinalProperty(windowHandle, "_NET_WM_DESKTOP");
	}
	
	void createPicture(){
		XWindowAttributes attr;
		XGetWindowAttributes(dpy, windowHandle, &attr);
    	XRenderPictFormat *format = XRenderFindVisualFormat(dpy, attr.visual);
		hasAlpha = (format.type == PictTypeDirect && format.direct.alphaMask);
		XRenderPictureAttributes pa;
		pa.subwindow_mode = IncludeInferiors;
		auto pixmap = XCompositeNameWindowPixmap(dpy, windowHandle);
		picture = XRenderCreatePicture(dpy, pixmap, format, CPSubwindowMode, &pa);
		auto screen = dockWindow.screenSize.get(2);
		auto scale = 0.1;
		// Scaling matrix
		XTransform xform = {[
		    [XDoubleToFixed( 1 ), XDoubleToFixed( 0 ), XDoubleToFixed(     0 )],
		    [XDoubleToFixed( 0 ), XDoubleToFixed( 1 ), XDoubleToFixed(     0 )],
		    [XDoubleToFixed( 0 ), XDoubleToFixed( 0 ), XDoubleToFixed( scale )]
		]};
		XRenderSetPictureTransform(dpy, picture, &xform);
		XRenderSetPictureFilter(dpy, picture, "best", null, 0);
	}
	
	override void move(int[2] pos){
		this.pos = pos;
	}

	override void resize(int[2] size){
		this.size = size;
		XFreePixmap(dpy, pixmap);
		createPicture;
	}
	
	override void processEvent(Event e){
		assert(e.xany.window == windowHandle);
		super.processEvent(e);
	}

	override void onShow(){
		createPicture;
	}

}


class Composite {

	this(){
		foreach(i; 0..ScreenCount(dpy))
		    XCompositeRedirectSubwindows(dpy, RootWindow(dpy, i), 0);
    	XWindowAttributes attr;
		XGetWindowAttributes(dpy, dockWindow.windowHandle, &attr);
    	XRenderPictFormat *format = XRenderFindVisualFormat(dpy, attr.visual);
		XRenderPictureAttributes pa;
		pa.subwindow_mode = IncludeInferiors; // Don't clip child widgets
		dockWindow.picture = XRenderCreatePicture(dpy, (cast(XDraw)dockWindow._draw).drawable, format, CPSubwindowMode, &pa);
	}

	void draw(CompositeClient window, int[2] pos, int[2] size){
		XRenderComposite(
			dpy,
			window.hasAlpha ? PictOpOver : PictOpSrc,
			window.picture,
			None,
            dockWindow.picture,
            0, 0,
            0, 0,
            pos.x, dockWindow.size.h-pos.y-size.h,
            size.w, size.h
        );
	}


}


class Watcher(T) {

	T[] data;

	void check(T[] data){
		data = data.sort!"a < b".array;
		if(this.data != data){
			foreach(delta; data.setDifference(this.data))
				foreach(event; add)
					event(delta);
			foreach(delta; this.data.setDifference(data))
				foreach(event; remove)
					event(delta);
			foreach(event; update)
				event();
			this.data = data;
		}
	}

	void delegate(T)[] add;
	void delegate(T)[] remove;
	void delegate()[] update;

}


class WorkspaceDock: ws.wm.Window {

	CardinalListProperty screenSize;
	CardinalProperty currentDesktop;
	CardinalProperty desktopCount;
	WindowListProperty clients;
	
	CardinalProperty windowDesktop;

	long currentDesktopInternal;
	long showTime;
	bool focus;

	CompositeClient[][long] desktops;

	Pid launcher;

	Watcher!(x11.X.Window) windowWatcher;
	Watcher!string windowWorkspaceWatcher;

	CompositeClient[] windows;

	Picture picture;

	this(int w, int h, string title){
		dpy = wm.displayHandle;
		dock.root = XDefaultRootWindow(dpy);
		screenSize = new CardinalListProperty(dock.root, "_NET_DESKTOP_GEOMETRY");
		currentDesktop = new CardinalProperty(dock.root, "_NET_CURRENT_DESKTOP");
		desktopCount = new CardinalProperty(dock.root, "_NET_NUMBER_OF_DESKTOPS");
		clients = new WindowListProperty(dock.root, "_NET_CLIENT_LIST");
		auto screen = screenSize.get(2);
		w = cast(int)(screen.w/10);

		super(w, cast(int)screen.h, title);

		windowWatcher = new Watcher!(x11.X.Window);
		windowWatcher.add ~= (window){
			if(window == windowHandle)
				return;
			writeln("found window ", window);
			XWindowAttributes wa;
			XGetWindowAttributes(dpy, window, &wa);
			auto client = new CompositeClient(window, [wa.x,wa.y], [wa.width,wa.height]);
			windows ~= client;
			wm.add(client);
		};
		windowWatcher.remove ~= (window){
			windows = windows.filter!((a)=>a.windowHandle != window).array;
		};

		windowWorkspaceWatcher = new Watcher!string;
		windowWorkspaceWatcher.update ~= &update;
	}

	override void gcInit(){}

	override void show(){
		windowDesktop = new CardinalProperty(windowHandle, "_NET_WM_DESKTOP");
		windowDesktop.set(-1);
		auto type = [
			atom("_NET_WM_WINDOW_TYPE_DOCK"),
			atom("_NET_WM_WINDOW_TYPE_DIALOG"),
		];
		new AtomListProperty(windowHandle, "_NET_WM_WINDOW_TYPE").setAtoms(type);
		super.show;
	}

	override void drawInit(){
		_draw = new XDraw(dpy, DefaultScreen(dpy), windowHandle, size.w, size.h);
		_draw.setFont("Consolas:size=10", 0);
	}

	override void resize(int[2] size){
		super.resize(size);
		draw.resize(size);
	}

	override void onDraw(){
		draw.setColor([0.05,0.05,0.05]);
		draw.rect([0,0], size);
		super.onDraw;
		draw.finishFrame;
	}

	void tick(){
		windowWorkspaceWatcher.check(windows.map!`"%s:%d".format(cast(void*)a, a.desktop.get)`.array);
		if(currentDesktop.get != currentDesktopInternal){
			update;
			currentDesktopInternal = currentDesktop.get;
			showTime = Clock.currSystemTick.msecs+500;
		}
		int targetX = cast(int)screenSize.get(2).w-(visible ? size.w : 1);
		if(pos.x != targetX){
			XMoveWindow(dpy, windowHandle, pos.x - cast(int)((pos.x-targetX)/1.5).lround, 0);
			XRaiseWindow(dpy, windowHandle);
		}
	}

	bool visible(){
		return showTime > Clock.currSystemTick.msecs || focus;
	}

	void update(){
		desktops = desktops.init;
		windowWatcher.check(clients.get(-1));
		XSync(dpy, false);
		foreach(window; windows)
			desktops[window.desktop.get] ~= window;
		foreach(c; children)
			remove(c);
		auto count = desktopCount.get;
		auto screen = screenSize.get(2);
		auto height = cast(int)(screen.h/10)+draw.fontHeight+5;
		auto w = cast(int)(screen.w/count);
		int desktopsHeight;
		foreach(i; 0..count)
			desktopsHeight += (count-1-i in desktops ? height : draw.fontHeight+4);
		int y = size.h/2 - desktopsHeight/2;
		foreach(i; 0..count){
			auto ws = addNew!WorkspaceView(this, count-1-i);
			ws.move([0, y]);
			ws.resize([w, count-1-i in desktops ? height : draw.fontHeight+4]);
			y += ws.size.h + 5;
		}
	}

	override void onMouseFocus(bool focus){
		update;
		this.focus = focus;
		if(showTime < Clock.currSystemTick.msecs)
			showTime = Clock.currSystemTick.msecs+100;
	}
	
	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.wheelDown && pressed){
			foreach(i; currentDesktopInternal+1..desktopCount.get+1){
				if(i !in desktops)
					continue;
				currentDesktopInternal = i;
				currentDesktop.request([currentDesktopInternal, CurrentTime]);
				break;
			}
		}else if(button == Mouse.wheelUp && pressed){
			foreach_reverse(i; 0..currentDesktopInternal){
				if(i !in desktops)
					continue;
				currentDesktopInternal = i;
				currentDesktop.request([currentDesktopInternal, CurrentTime]);
				break;
			}
		}else{
			super.onMouseButton(button, pressed, x, y);
		}
	}

}


class WorkspaceView: Base {

	long id;
	WorkspaceDock dock;
	string name = "~";
	bool preview;

	this(WorkspaceDock dock, long id){
		this.dock = dock;
		this.id = id;
	}

	override void resize(int[2] size){
		super.resize(size);
		update;
	}

	void update(){
		foreach(c; children)
			remove(c);
		auto scale = (size.w-10) / cast(double)dock.screenSize.get(2).w;
		if(id in dock.desktops)
			foreach(w; dock.desktops[id]){
				auto wv = addNew!WindowIcon(w, cast(int)id);
				wv.moveLocal([
					5+cast(int)(w.pos.x*scale).lround,
					4+cast(int)((dock.screenSize.get(2).h-w.pos.y-w.size.h)*scale).lround
				]);
				wv.resize([
					cast(int)(w.size.w*scale).lround,
					cast(int)(w.size.h*scale).lround
				]);
			}
		try{
			name = "~/.dinu/%s".format(id).expandTilde.readText.baseName;
		}catch{}
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
		writeln("requesting window move to ", id);
		new CardinalProperty(ghost.window.windowHandle, "_NET_WM_DESKTOP").request([id,2]);
		dock.update;
		preview = false;
	}

	override void onMouseFocus(bool focus){
		preview = focus;
	}

	override void onDraw(){
		if(id in dock.desktops){
			if(id == dock.currentDesktop.get)
				draw.setColor([0.867,0.514,0]);
			else if(preview)
				draw.setColor([0.6,0.6,0.6]);
			else
				draw.setColor([0.3,0.3,0.3]);
			dock.draw.rect(pos.a+[3,2], [size.w-6, size.h-draw.fontHeight-6]);
			draw.setColor([0.3,0.3,0.3]);
			draw.rect(pos.a+[5,5], [size.w-11,size.h-draw.fontHeight-11]);
		}

		super.onDraw;

		if(id == dock.currentDesktop.get || preview){
			if(id !in dock.desktops){
				draw.setColor([0.4,0.4,0.4]);
				draw.rect(pos.a+[2,2], size.a-[4,4]);
			}
			dock.draw.setColor([1,1,1]);
		}else
			dock.draw.setColor([0.4,0.4,0.4]);
		dock.draw.text(pos.a+[7,size.h-draw.fontHeight-1], name, 0);
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.buttonLeft && !pressed)
			dock.currentDesktop.request([id, CurrentTime]);
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
		composite.draw(window, pos, size);
		/+
		if(hasMouseFocus){
			draw.setColor([0.6,0.6,0.6]);
			draw.rectOutline(pos.a+[1,1], size.a-[2,2]);
		}
		+/
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
		composite.draw(window, pos, size);
		draw.setColor([0.8,0.8,0.8]);
		draw.rectOutline(pos, size);
	}

}


extern(C) nothrow int xerror(Display* dpy, XErrorEvent* ee){
	return 0;
}
