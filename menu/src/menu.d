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

	ws.wm.Window[] popups;

	long currentDesktopInternal;
	long showTime;
	bool focus;

	x11.X.Window[][long] desktops;

	Tabs tabs;

	bool active;

	DesktopEntry[][string] appCategories;

	Scheduler scheduler;

	Inotify inotify;

	this(int w, int h, string title){
		menuWindow = this;
		dpy = XOpenDisplay(null);
		.root = XDefaultRootWindow(dpy);
		screenSize = new CardinalListProperty(.root, "_NET_DESKTOP_GEOMETRY");
		currentDesktop = new CardinalProperty(.root, "_NET_CURRENT_DESKTOP");
		auto screen = screenSize.get(2);

		scheduler = new Scheduler;
		inotify = new Inotify;

		tabs = addNew!Categories(w-2);
		tabs.addPage(new TabHeadButton("Files"), new ListFiles);
		tabs.addPage(new TabHeadButton("History"), new ListFrequent);
		tabs.addPage(new TabHeadButton("Apps"), new ListDesktop(appCategories, categories));
		tabs.pages[0].button.leftClick();
		
		super(w, screen.h.to!int, title);

		auto applications = getAll;

		foreach(app; applications){
			foreach(category, categoryNice; categories){
				if(app.categories.canFind(category)){
					appCategories[categoryNice] ~= app;
				}
			}
		}

		void delegate() keepRaised;
		keepRaised = {
			XRaiseWindow(dpy, windowHandle);
			scheduler.queue(Clock.currSystemTick.msecs + 5000, keepRaised);
		};

		scheduler.queue(Clock.currSystemTick.msecs + 5000, keepRaised);

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
		new AtomProperty(windowHandle, "_NET_WM_WINDOW_TYPE").set(atom("_NET_WM_WINDOW_TYPE_DIALOG"));
		super.show;
	}

	void tick(){
		inotify.update;
		auto target = [active ? 0 : -size.w+1, 0];
		if(target != pos){
			pos = target;
			XMoveWindow(dpy, windowHandle, pos.x, pos.y);
			XSync(dpy, false);
		}
	}

	override void resize(int[2] size){
		super.resize(size);
		tabs.move([0, 1]);
		tabs.resize(size.a-[2,2]);
	}

	override void onDraw(){
		if(!active)
			return;
		//draw.setColor([0.1,0.1,0.1]);
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
		if(!active){
		}
		super.onMouseFocus(focus);
	}

}


class Categories: Tabs {

	this(long width){
		super(top);
		font = "Arial";
		fontSize = 9;
		offset = 0.5;
		style.bg = [0.3, 0.3, 0.3, 1];
		style.bg.hover = [0.1, 0.1 ,0.1, 1];
		style.fg = [1, 1, 1, 1];
		buttonSize.w = (width/3).lround.to!int;
		buttonSize.h = 20;
		setStyle(style);
	}

}


class TabHeadButton: TabButton {

	string name;

	this(string name){
		super("");
		this.name = name;
	}

	override void onDraw(){
		auto x = size.w/2 - draw.width(name)/2;
		if(active || mouseFocus){
			draw.setColor([0.3,0.3,0.3]);
			draw.rect(pos, size);
		}
		draw.setColor([0.8,0.8,0.8]);
		draw.text(pos.a+[x,0], size.h, name);
	}

}


string context(){
	return "flatman-context".executeShell.output.strip;
}

void setContext(string context){
	("flatman-context " ~ context.normalize).executeShell;
}

string nice(string path){
	return path.replace("~".normalize, "~");
}

string normalize(string path){
	return path.expandTilde.buildNormalizedPath;
}

void execute(string command, string type, string parameter="", string serialized=""){
	auto dg = {
		try{
			string command = (command.strip ~ ' ' ~ parameter).strip;
			if(!serialized.length)
				serialized = command;
			writeln("running: \"%s\"".format(command));
			"context %s".format(context).writeln;
			chdir(context);
			auto pipes = pipeShell(command);
			auto pid = pipes.pid.processID;
			logExec(pid, type, serialized.replace("!", "\\!"), parameter);
			auto reader = task({
				foreach(line; pipes.stdout.byLine){
					if(line.length)
						log("%s stdout %s".format(pid, line));
				}
			});
			reader.executeInNewThread;
			foreach(line; pipes.stderr.byLine){
				if(line.length)
					log("%s stderr %s".format(pid, line));
			}
			reader.yieldForce;
			auto res = pipes.pid.wait;
			log("%s exit %s".format(pid, res));
		}catch(Throwable t)
			writeln(t);
	};
	task(dg).executeInNewThread;
}


private Mutex logMutex;

shared static this(){
	logMutex = new Mutex;
}


void log(string text){
	synchronized(logMutex){
		auto path = "%s.log".format("flatman-context -p".executeShell.output).expandTilde;
		if(path.exists)
			std.file.append(path, text ~ '\n');
		else
			std.file.write(path, text ~ '\n');
	}
}

void logExec(int pid, string type, string serialized, string parameter){
	string text = "%s exec %s!%s!%s".format(pid, type, serialized, parameter);
	log(text);
	synchronized(logMutex){
		auto path = "%s.exec".format("flatman-context -p".executeShell.output).expandTilde;
		if(path.exists)
			std.file.append(path, text ~ '\n');
		else
			std.file.write(path, text ~ '\n');
	}
}
