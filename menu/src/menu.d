module menu.menu;

import menu;

__gshared:


ulong root;

Menu menuWindow;

CardinalListProperty screenSize;
CardinalProperty currentDesktop;


enum categories = [
	"AudioVideo", "Audio", "Video", "Graphics",
	"Development", "Education", "Game", "Network",
	"Office", "Utility", "System", "Settings"
];


void main(string[] args){
	XInitThreads();
	menuWindow = new Menu(400, 500, "flatman-menu");
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


class Entry {
	int count;
	string text;
}


string bangJoin(string[] parts){
	return parts.map!`a.replace("!", "\\!")`.join("!");
}

string[] bangSplit(string text){
	return text.split(regex(`(?<!\\)\!`)).map!`a.replace("\\!", "!")`.array;
}


class Scheduler {

	struct Event {
		long msecs;
		void delegate() callback;
	}

	Event[] events;

	void tick(){
		foreach(event; events.dup){
			if(event.msecs <= Clock.currSystemTick.msecs){
				events = events.without(event);
				event.callback();
			}
		}
	}

	void queue(long msecs, void delegate() callback){
		events ~= Event(msecs, callback);
	}

}


class Menu: ws.wm.Window {

	AtomListProperty state;

	long currentDesktopInternal;
	long showTime;
	bool focus;

	x11.X.Window[][long] desktops;

	PathChooser path;
	Tabs tabs;

	bool active;

	DesktopEntry[][string] appCategories;

	Scheduler scheduler;

	this(int w, int h, string title){
		dpy = XOpenDisplay(null);
		.root = XDefaultRootWindow(dpy);
		screenSize = new CardinalListProperty(.root, "_NET_DESKTOP_GEOMETRY");
		currentDesktop = new CardinalProperty(.root, "_NET_CURRENT_DESKTOP");
		auto screen = screenSize.get(2);

		path = addNew!PathChooser;
		path.text.font = "Consolas:size=9";
		path.text.text = context.nice;

		tabs = addNew!Categories;
		tabs.addPage("Frequent", new ListFrequent);
		
		super(w, h, title);

		auto applications = getAll;

		foreach(app; applications){
			foreach(category; categories){
				if(app.categories.canFind(category)){
					appCategories[category] ~= app;
				}
			}
		}

		scheduler = new Scheduler;

		void delegate() keepRaised;
		keepRaised = {
			XRaiseWindow(dpy, windowHandle);
			scheduler.queue(Clock.currSystemTick.msecs + 5000, keepRaised);
		};

		scheduler.queue(Clock.currSystemTick.msecs + 5000, keepRaised);


	}

	override void drawInit(){
		_draw = new XDraw(dpy, DefaultScreen(dpy), windowHandle, size.w, size.h);
		_draw.setFont("Consolas:size=9", 0);
	}

	override void gcInit(){}

	override void show(){
		new CardinalProperty(windowHandle, "_NET_WM_DESKTOP").set(-1);
		new AtomProperty(windowHandle, "_NET_WM_WINDOW_TYPE").set(atom("_NET_WM_WINDOW_TYPE_DIALOG"));
		super.show;
	}

	void tick(){
		auto target = active ? [0,0] : [-size.w+1, -size.h+1];
		if(target != pos){
			pos.x -= cast(int)((pos.x-target.x)/1.9).lround;
			pos.y -= cast(int)((pos.y-target.y)/1.9).lround;
			XMoveWindow(dpy, windowHandle, pos.x, pos.y);
			XSync(dpy, false);
		}
	}

	override void resize(int[2] size){
		super.resize(size);
		path.move([0, size.h-25]);
		path.resize([size.w-2, 25]);
		tabs.move([0,2]);
		tabs.resize(size.a-[2,2+25]);
	}

	override void onDraw(){
		if(!active)
			return;
		//draw.setColor([0.1,0.1,0.1]);
		draw.setColor([0.867,0.514,0]);
		draw.rect(pos, size);
		draw.setColor([0.1,0.1,0.1]);
		draw.rect(pos.a+[0,2], size.a-[2,2]);
		super.onDraw;
		draw.finishFrame;
	}

	override void onMouseFocus(bool focus){
		if(active != focus && !active){
			remove(tabs);
			tabs = addNew!Categories;
			tabs.addPage("Files", new ListFiles);
			tabs.addPage("History", new ListFrequent);
			foreach(name; categories){
				if(name !in appCategories)
					continue;
				tabs.addPage(name, new ListDesktop(appCategories[name].sort!"a.name[0].toLower < b.name[0].toLower".array));
			}
			resize(size);
			tabs.pages[0].button.leftClick();
		}
		active = focus;
		super.onMouseFocus(focus);
	}

}


class Categories: Tabs {

	this(){
		super(left);
		font = "Consolas:size=9";
		offset = 0;
		style.bg = [0.3, 0.3, 0.3, 1];
		style.bg.hover = [0.1, 0.1 ,0.1, 1];
		style.fg = [1, 1, 1, 1];
		buttonSize.w = 110;
		buttonSize.h = 25;
		setStyle(style);
	}

}


string context(){
	auto file = "~/.dinu/%s".format(currentDesktop.get).expandTilde;
	if(file.exists && file.readText.exists)
		return file.readText;
	return "~".expandTilde;
}

string nice(string path){
	return path.replace("~".expandTilde, "~");
}

private Mutex logMutex;

shared static this(){
	logMutex = new Mutex;
}


void log(string text){
	synchronized(logMutex){
		auto path = "~/.dinu/%s.log".format(currentDesktop.get).expandTilde;
		if(path.exists)
			std.file.append(path, text ~ '\n');
		else
			std.file.write(path, text ~ '\n');
	}
}

void logExec(string text){
	log(text);
	synchronized(logMutex){
		auto path = "~/.dinu/%s.exec".format(currentDesktop.get).expandTilde;
		if(path.exists)
			std.file.append(path, text ~ '\n');
		else
			std.file.write(path, text ~ '\n');
	}
}


class PathChooser: Base {

	Text text;
	Button up;
	Button open;

	this(){
		text = addNew!Text;
		up = addNew!Button("⇧");
		open = addNew!Button("⇨");
	}

	override void resize(int[2] size){
		text.resize(size);

		up.resize([size.h-4, size.h-4]);
		up.moveLocal([size.w-size.h*2, 2]);
		writeln(up.pos, ' ', up.size);

		open.resize([size.h-4, size.h-4]);
		open.moveLocal([size.w-size.h, 2]);
		super.resize(size);
	}

	override void onDraw(){
		draw.setColor([0.35,0.35,0.35]);
		draw.rect(pos, size);
		super.onDraw;
	}

}
