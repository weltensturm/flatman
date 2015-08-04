module dock.dock;

import dock;

__gshared:


ulong root;


void main(){
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

class WorkspaceDock: ws.wm.Window {

	Draw draw;

	CardinalListProperty screenSize;
	CardinalProperty currentDesktop;
	CardinalProperty desktopCount;
	WindowListProperty clients;
	
	CardinalProperty windowDesktop;

	long currentDesktopInternal;
	long showTime;
	bool focus;

	x11.X.Window[][long] desktops;


	this(int w, int h, string title){
		dpy = XOpenDisplay(null);
		root = XDefaultRootWindow(dpy);
		screenSize = new CardinalListProperty(root, "_NET_DESKTOP_GEOMETRY");
		currentDesktop = new CardinalProperty(root, "_NET_CURRENT_DESKTOP");
		desktopCount = new CardinalProperty(root, "_NET_NUMBER_OF_DESKTOPS");
		clients = new WindowListProperty(root, "_NET_CLIENT_LIST");
		auto screen = screenSize.get(2);
		auto count = desktopCount.get;
		w = cast(int)(screen.w/count);
		super(w, cast(int)screen.h, title);
		draw = new Draw(dpy, DefaultScreen(dpy), windowHandle, size.w, size.h);
		draw.load_fonts(["Consolas:size=10"]);
		windowDesktop = new CardinalProperty(windowHandle, "_NET_WM_DESKTOP");
		windowDesktop.request([-1,2]);
	}

	override void resize(int[2] size){
		super.resize(size);
		if(draw)
			draw.resize(size.w, size.h);
	}

	override void onDraw(){
		draw.setColor("#050505");
		draw.rect([0,0], size);
		super.onDraw;
		draw.map(windowHandle, 0, 0, size.w, size.h);
	}

	void tick(){
		if(visible)
			update;
		if(currentDesktop.get != currentDesktopInternal){
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
			desktops[ws.get] ~= client;
		}
		foreach(c; children)
			remove(c);
		auto count = desktopCount.get;
		auto screen = screenSize.get(2);
		auto height = cast(int)(screen.h/count);
		auto w = cast(int)(screen.w/count);
		int desktopsHeight;
		foreach(i; 0..count)
			desktopsHeight += (count-1-i in desktops ? height : draw.fonts[0].h+20);
		int y = size.h/2 - desktopsHeight/2;
		foreach(i; 0..count){
			auto ws = addNew!WorkspaceView(this, count-1-i);
			ws.move([0, y]);
			ws.resize([w, count-1-i in desktops ? height : draw.fonts[0].h+20]);
			y += ws.size.h-5;
		}
	}

	override void onMouseFocus(bool focus){
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

	this(WorkspaceDock dock, long id){
		this.dock = dock;
		this.id = id;
		update;
	}

	void update(){
		try{
			name = "~/.dinu/%s".format(id).expandTilde.readText.baseName;
		}catch{}
	}

	override void onDraw(){
		dock.draw.setColor("#222222");
		dock.draw.rect(pos, size);
		if(id == dock.currentDesktop.get)
			dock.draw.setColor("#bbbbbb");
		else{
			if(id in dock.desktops)
				dock.draw.setColor("#444444");
			else
				dock.draw.setColor("#222222");
		}
		dock.draw.rect(pos.a+[5,5], size.a-[10,10]);
		if(id in dock.desktops)
			dock.draw.setColor("#ffffff");
		else
			dock.draw.setColor("#999999");
		dock.draw.text(name, pos.a+[10,10]);
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.buttonLeft && pressed){
			dock.currentDesktop.request([id, CurrentTime]);
		}
	}

}