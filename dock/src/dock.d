module dock.dock;

import dock;

__gshared:


ulong root;

extern(C) nothrow int function(Display *, XErrorEvent *) xerrorxlib;

void main(){
	xerrorxlib = XSetErrorHandler(&xerror);
	auto wsdock = new WorkspaceDock(400, 300, "flatman-dock");
	wm.add(wsdock);
	while(wm.hasActiveWindows){
		wm.processEvents;
		wsdock.onDraw;
		wsdock.tick;
		Thread.sleep(10.msecs);
	}
}


Atom atom(string name){
	return XInternAtom(dpy, name.toStringz, false);
}

struct WindowData {
	x11.X.Window window;
	int x, y, width, height;
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

	WindowData[][long] desktops;

	Pid launcher;

	this(int w, int h, string title){
		dpy = XOpenDisplay(null);
		dock.root = XDefaultRootWindow(dpy);
		screenSize = new CardinalListProperty(dock.root, "_NET_DESKTOP_GEOMETRY");
		currentDesktop = new CardinalProperty(dock.root, "_NET_CURRENT_DESKTOP");
		desktopCount = new CardinalProperty(dock.root, "_NET_NUMBER_OF_DESKTOPS");
		clients = new WindowListProperty(dock.root, "_NET_CLIENT_LIST");
		auto screen = screenSize.get(2);
		auto count = desktopCount.get;
		w = cast(int)(screen.w/count);
		super(w, cast(int)screen.h, title);
	}

	override void gcInit(){}

	override void show(){
		windowDesktop = new CardinalProperty(windowHandle, "_NET_WM_DESKTOP");
		windowDesktop.set(-1);
		new AtomProperty(windowHandle, "_NET_WM_WINDOW_TYPE").set(atom("_NET_WM_WINDOW_TYPE_DOCK"));
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
		XSync(dpy, false);
		foreach(client; clients.get(-1)){
			auto ws = new CardinalProperty(client, "_NET_WM_DESKTOP");
			XWindowAttributes wa;
			XGetWindowAttributes(dpy, client, &wa);
			desktops[ws.get] ~= WindowData(client, wa.x, wa.y, wa.width, wa.height);
		}
		foreach(c; children)
			remove(c);
		auto count = desktopCount.get;
		auto screen = screenSize.get(2);
		auto height = cast(int)(screen.h/count);
		auto w = cast(int)(screen.w/count);
		int desktopsHeight;
		foreach(i; 0..count)
			desktopsHeight += (count-1-i in desktops ? height : draw.fontHeight+20);
		int y = size.h/2 - desktopsHeight/2;
		foreach(i; 0..count){
			auto ws = addNew!WorkspaceView(this, count-1-i);
			ws.move([0, y]);
			ws.resize([w, count-1-i in desktops ? height : draw.fontHeight+20]);
			y += ws.size.h-5;
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

	void runLauncher(WorkspaceView view){
		try
			if(launcher){
				launcher.kill;
				launcher.wait;
				launcher = null;
			}
		catch{}
		launcher = spawnProcess(["flatman-menu", view.id.to!string, (pos.x-200).to!string, (screenSize.get(2).h-view.pos.y-view.size.h).to!string]);
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
					5+cast(int)(w.x*scale).lround,
					5+cast(int)(w.y*scale).lround
				]);
				wv.resize([
					cast(int)(w.width*scale).lround-5,
					cast(int)(w.height*scale).lround-5
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
		new CardinalProperty(ghost.window.window, "_NET_WM_DESKTOP").request([id,2]);
		dock.update;
		preview = false;
	}

	override void onDraw(){
		dock.draw.setColor([0.1,0.1,0.1]);
		dock.draw.rect(pos, size);
		auto m = (preview || id == dock.currentDesktop.get) ? 3 : 1;
		if(id in dock.desktops)
			dock.draw.setColor([0.3*m,0.3*m,0.3*m]);
		else
			dock.draw.setColor([0.1*m,0.1*m,0.1*m]);
		dock.draw.rect(pos.a+[5,5], size.a-[10,10]);

		super.onDraw;

		if(id in dock.desktops)
			dock.draw.setColor([1,1,1]);
		else
			dock.draw.setColor([0.6,0.6,0.6]);
		dock.draw.text(pos.a+[10,10], name);
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

	WindowData window;
	int desktop;

	this(WindowData window, int desktop){
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
			writeln(dragOffset, ' ', pos, ' ', [x,y]);
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
		draw.setColor([0.4,0.4,0.4]);
		draw.rect(pos, size);
		super.onDraw;
	}

}


class Ghost: Base {

	WindowData window;
	int desktopSource;

	this(WindowData window, int desktopSource){
		this.window = window;
		this.desktopSource = desktopSource;
	}

	override void onDraw(){
		draw.setColor([0.6,0.6,0.6]);
		draw.rect(pos, size);
	}

}


extern(C) nothrow int xerror(Display* dpy, XErrorEvent* ee){
	if(ee.error_code == XErrorCode.BadWindow)
		return 0;
	return xerrorxlib(dpy, ee); /* may call exit */
}
