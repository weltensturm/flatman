module menu.menu;

import menu;

__gshared:


ulong root;

Menu menuWindow;

CardinalProperty currentDesktop;


struct Options {
	@("-s") int screen = 0;
}

Options options;


enum categories = [
	"AudioVideo": "Media",
	"Graphics": "Graphics",
	"Development": "Programming",
	"Education": "Education",
	"Game": "Games",
	"Network": "Internet",
	"Office": "Office",
	"Other": "Other",
	"Utility": "Accessories",
	"System": "System Tools",
	"Settings": "System Settings"
];


void main(string[] args){
	options.fill(args);
	Context.init;
	new Menu(600, 500, "flatman-menu");
	wm.add(menuWindow);
	menuWindow.show;
	while(wm.hasActiveWindows){
		auto frameStart = now;
		wm.processEvents;
		menuWindow.tick;
		menuWindow.onDraw;
		auto frameEnd = now;
		Thread.sleep(((frameStart + 1.0/60.0 - frameEnd).max(0)*1000).lround.msecs);
	}
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
	Scroller appScroller;

	Tree contexts;

	Base keyboardFocus;

	GlContext context;

	this(int w, int h, string title){
		menuWindow = this;
		dpy = wm.displayHandle;
		.root = XDefaultRootWindow(dpy);
		currentDesktop = new CardinalProperty(.root, "_NET_CURRENT_DESKTOP");

		inotify = new Inotify;

		auto applications = getAll;

		foreach(app; applications){
			if(!app.exec.length || app.noDisplay)
				continue;
			bool found;
			foreach(category; app.categories){
				if(category in categories && category != "Other"){
					found = true;
					appCategories[categories[category]] ~= app;
					break;
				}
			}
			if(!found)
				appCategories["Other"] ~= app;
		}

		scroller = addNew!Scroller;
		appScroller = addNew!Scroller;

		auto list = scroller.addNew!DynamicList;
		list.padding = 0;
		list.style.bg = [0.1,0.1,0.1,1];
		//list.addApps(appCategories, categories);
		contexts = list.addFiles;
		list.addTrash;

		auto appList = appScroller.addNew!DynamicList;
		appList.padding = 0;
		appList.style.bg = [0.1,0.1,0.1,1];
		appList.addHistory;
		appList.addApps(appCategories, categories);

		super(w, h, title);
		updateSize;

		draw.setColor([0,0,0]);
		draw.rect(pos,size);
		draw.finishFrame;

		wm.on(.root, [
			ConfigureNotify: (XEvent* ev) => updateSize
		]);
	}

	Screen targetScreen(){
		auto screens = screens;
		return screens[options.screen];
	}

	void updateSize(){
		resize([size.w, targetScreen.h]);
	}

	/+
	override void drawInit(){
		context = new GlContext(windowHandle);
		context.blendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		context.enable(GL_BLEND);
		draw = new GlDraw(context);
		draw.setFont(config.font, config.fontSize);
	}
	+/

	override void show(){
		new CardinalProperty(windowHandle, "_NET_WM_DESKTOP").set(-1);
		new AtomProperty(windowHandle, "_NET_WM_WINDOW_TYPE").set(atom("_NET_WM_WINDOW_TYPE_DIALOG"));
		super.show;
	}

	void tick(){
		/+
		auto screen = targetScreen;
		auto targetPos = [screen.x, screen.y];
		auto targetSize = [active ? 600 : 1, active ? screen.h : 1];
		if(targetPos != pos){
			move(pos);
			pos = targetPos;
			writeln("pos ", pos);
			XSync(dpy, false);
		}
		if(targetSize != size){
			resize(size);
			size = targetSize;
			writeln("size ", size);
			XSync(dpy, false);
		}
		+/
		if(active){
			try {
				Inotify.update;
			}catch(Exception e)
				writeln(e);
			foreach(c; contexts.children[1..$].to!(Path[]))
				c.tick;
		}
	}

	override void resized(int[2] size){
		super.resized(size);
		scroller.move([0,0]);
		scroller.resize([size.w/2-1,size.h-2]);
		appScroller.move([size.w/2,0]);
		appScroller.resize([size.w/2-2, size.h-2]);
	}

	override void onHide(){
		XMapWindow(dpy, windowHandle);
	}

	override void onDraw(){
		if(!active){
			draw.setColor([0,0,0]);
			draw.rect(pos, size);
			draw.finishFrame;
			return;
		}
		Animation.update;
		//draw.setColor([0.867,0.514,0]);
		draw.setColor(config.border);
		draw.rect([0,0], size);
		draw.setColor(config.background);
		draw.rect([0,0], size.a-[2,0]);
		draw.setColor(config.border);
		draw.rect([size.w/2-1,0], [1, size.h]);

		draw.setColor([0,0,0]);
		draw.rect([size.w-1,0], [1,size.h]);
		super.onDraw;
		//draw.finishFrame;
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(popups.length){
			while(popups.length)
				popups[0].hide;
			return;
		}
		super.onMouseButton(button, pressed, x, y);
	}

	override void onMouseMove(int x, int y){
		if(popups.length)
			return;
		super.onMouseMove(x, y);
	}

	override void onMouseFocus(bool focus){
		if(focus || !popups.length){
			active = focus;
			auto screen = targetScreen;
			int[2] targetPos = [screen.x, screen.y];
			int[2] targetSize = [active ? 600 : 1, screen.h];
			if(targetPos != pos){
				move(targetPos);
			}
			if(targetSize != size){
				resize(targetSize);
			}
		}
		super.onMouseFocus(focus);
	}

	override void onKeyboard(dchar c){
		if(keyboardFocus)
			keyboardFocus.onKeyboard(c);
	}

	override void onKeyboard(Keyboard.key key, bool pressed){
		if(key == Keyboard.escape && !pressed){
			if(keyboardFocus){
				keyboardFocus.parent.remove(keyboardFocus);
				keyboardFocus = null;
			}else
				menuWindow.onMouseFocus(false);
		}
		if(keyboardFocus)
			keyboardFocus.onKeyboard(key, pressed);
		else if(key == 'q'){
			hide;
			wm.remove(this);
		}
	}

	override void onKeyboardFocus(bool focus){
		writeln("FOCUS! ", focus);
		super.onKeyboardFocus(focus);
	}

}


class RootButton: Button {

	string name;

	Tree tree;

	bool mouseDown;

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

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.buttonLeft)
			mouseDown = pressed;
		super.onMouseButton(button, pressed, x, y);
	}

	override void onDraw(){
		if(pos.y+size.h<0 || pos.y>menuWindow.size.h)
			return;
		/+
		double mod = (hasMouseFocus ? 1.1 : 1) * (tree && tree.expanded ? 1.3 : 1);
		+/
		if(pressed){
			draw.setColor([0.15,0.15,0.15]);
			draw.rect(pos, size);
		}
		draw.setFont(config.buttonTab.font, config.buttonTab.fontSize);
		auto mod = (tree && tree.expanded ? 1 : 0.7);
		draw.setColor([0.9*mod,0.9*mod,0.9*mod]);
		draw.text(pos.a + [10, 0], size.h, name);
	}

}


string nice(string path){
	return path.replace("~".normalize, "~");
}

string normalize(string path){
	return path.expandTilde.buildNormalizedPath;
}

