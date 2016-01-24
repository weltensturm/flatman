module menu.menu;

import menu;

__gshared:


ulong root;

Menu menuWindow;

CardinalListProperty screenSize;
CardinalProperty currentDesktop;


enum categories = [
	"AudioVideo": "Media",
	"Graphics": "Graphics",
	"Development": "Programming",
	"Education": "Education",
	"Game": "Games",
	"Network": "Internet",
	"Office": "Office",
	"Utility": "Accessories",
	"System": "System Tools",
	"Settings": "System Settings"
];


void main(string[] args){
	XInitThreads();
	new Menu(400, 500, "flatman-menu");
	wm.add(menuWindow);
	while(wm.hasActiveWindows){
		wm.processEvents;
		menuWindow.onDraw;
		menuWindow.tick;
		Thread.sleep(10.msecs);
	}
}


Atom atom(string name){
	return XInternAtom(dpy, name.toStringz, false);
}


class Menu: ws.wm.Window {

	AtomListProperty state;

	ws.wm.Window[] popups;

	long currentDesktopInternal;
	long showTime;
	bool focus;

	x11.X.Window[][long] desktops;

	bool active;

	DesktopEntry[][string] appCategories;

	Inotify inotify;

	Scroller scroller;

	this(int w, int h, string title){
		menuWindow = this;
		dpy = wm.displayHandle;
		.root = XDefaultRootWindow(dpy);
		screenSize = new CardinalListProperty(.root, "_NET_DESKTOP_GEOMETRY");
		currentDesktop = new CardinalProperty(.root, "_NET_CURRENT_DESKTOP");
		auto screen = screenSize.get(2);

		inotify = new Inotify;

		auto applications = getAll;

		foreach(app; applications){
			foreach(category, categoryNice; categories){
				if(app.categories.canFind(category)){
					appCategories[categoryNice] ~= app;
				}
			}
		}

		scroller = addNew!Scroller;

		auto list = scroller.addNew!DynamicList;
		list.padding = 0;
		list.style.bg = [0.1,0.1,0.1,1];
		auto watcher = menuWindow.inotify.addWatch("~/.flatman/".normalize, false);
		list.addFiles(watcher);
		list.addApps(appCategories, categories);
		list.addHistory(watcher);

		super(w, screen.h.to!int, title);

		draw.setColor([0,0,0]);
		draw.rect(pos,size);
		draw.finishFrame;
	}

	override void drawInit(){
		_draw = new XDraw(dpy, DefaultScreen(dpy), windowHandle, size.w, size.h);
		_draw.setFont("Arial", 9);
	}

	override void gcInit(){}

	override void show(){
		new CardinalProperty(windowHandle, "_NET_WM_DESKTOP").set(-1);
		//new AtomProperty(windowHandle, "_NET_WM_WINDOW_TYPE").set(atom("_NET_WM_WINDOW_TYPE_DIALOG"));
		super.show;
	}

	void tick(){
		auto target = [active ? 0 : -size.w+1, 0];
		if(target != pos){
			pos = target;
			XMoveWindow(dpy, windowHandle, pos.x, pos.y);
			XSync(dpy, false);
		}
		if(active)
			try
				inotify.update;
			catch(Exception e)
				writeln(e);
	}

	override void resize(int[2] size){
		super.resize(size);
		scroller.move([0, 1]);
		scroller.resize(size.a-[2,2]);
	}

	override void onDraw(){
		if(!active)
			return;
		draw.setColor([0.867,0.514,0]);
		draw.rect(pos, size);
		draw.setColor([0.1,0.1,0.1]);
		draw.rect(pos.a, size.a-[2,0]);
		super.onDraw;
		draw.setColor([0,0,0]);
		draw.rect(pos.a + [size.w-1,0], [1,size.h]);
		draw.finishFrame;
	}

	override void onMouseFocus(bool focus){
		if(active != focus && !active){
			resize(size);
		}
		if(focus || !popups.length)
			active = focus;
		super.onMouseFocus(focus);
	}


	override void onKeyboardFocus(bool focus){
		writeln("FOCUS! ", focus);
		super.onKeyboardFocus(focus);
	}

}


class RootButton: Button {

	string name;

	Tree tree;

	this(string name, Button[] buttons = []){
		this.name = name;
		super("");
		foreach(b; buttons){
			b.style.bg = style.bg.hover;
			add(b);
		}
	}

	void set(Tree tree){
		this.tree = tree;
	}

	override void resize(int[2] size){
		super.resize(size);
		foreach(i, c; children){
			c.move(pos.a + [size.w - 2 - size.h*i.to!int, 2]);
			c.resize([size.h-4,size.h-4]);
		}
	}

	override void onDraw(){
		double mod = (hasMouseFocus ? 1.1 : 1) * (tree && tree.expanded ? 1.3 : 1);
		draw.setColor([0.15*mod,0.15*mod,0.15*mod]);
		draw.rect(pos, size);
		draw.setFont("Consolas", 10);
		draw.setColor([0.9,0.9,0.9]);
		draw.text(pos.a + [10, 0], size.h, name);
	}

}


string nice(string path){
	return path.replace("~".normalize, "~");
}

string normalize(string path){
	return path.expandTilde.buildNormalizedPath;
}

