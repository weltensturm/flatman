module dock.dock;

import dock;

__gshared:


ulong root;


Menu menu;

void main(string[] args){
	XInitThreads();
	menu = new Menu(600, 30*13+5, "flatman-menu");
	wm.add(menu);
	while(wm.hasActiveWindows){
		wm.processEvents;
		menu.onDraw;
		menu.tick;
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

CardinalListProperty screenSize;
CardinalProperty currentDesktop;

class Menu: ws.wm.Window {

	AtomListProperty state;

	long currentDesktopInternal;
	long showTime;
	bool focus;

	x11.X.Window[][long] desktops;

	Tabs tabs;

	bool active;

	DesktopEntry[][string] appCategories;

	this(int w, int h, string title){
		dpy = XOpenDisplay(null);
		.root = XDefaultRootWindow(dpy);
		screenSize = new CardinalListProperty(.root, "_NET_DESKTOP_GEOMETRY");
		currentDesktop = new CardinalProperty(.root, "_NET_CURRENT_DESKTOP");
		auto screen = screenSize.get(2);

		tabs = addNew!Categories;
		tabs.addPage("Frequent", new ListFrequent);
		
		super(w, h, title);

		auto applications = getAll;

		auto categories = [
			"AudioVideo", "Audio", "Video", "Development",
			"Education", "Game", "Graphics", "Network",
			"Office", "Settings", "System", "Utility"
		];

		foreach(app; applications){
			foreach(category; categories){
				if(app.categories.canFind(category)){
					appCategories[category] ~= app;
				}
			}
		}

		writeln("insanity: ", appCategories.length);

	}

	override void drawInit(){
		_draw = new XDraw(dpy, DefaultScreen(dpy), windowHandle, size.w, size.h);
		_draw.setFont("Consolas:size=10", 0);
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
			XMoveWindow(dpy, windowHandle,
				pos.x - cast(int)((pos.x-target.x)/1.9).lround,
				pos.y - cast(int)((pos.y-target.y)/1.9).lround
				);
			XRaiseWindow(dpy, windowHandle);
		}
	}

	void update(){}

	override void resize(int[2] size){
		super.resize(size);
		tabs.resize(size);
	}

	override void onDraw(){
		draw.setColor([0.1,0.1,0.1]);
		draw.rect(pos, size);
		super.onDraw;
		draw.finishFrame;
	}

	override void onMouseFocus(bool focus){
		if(active != focus){
			update;
			active = focus;
			remove(tabs);
			tabs = addNew!Categories;
			tabs.addPage("Desktop %d".format(currentDesktop.get), new ListFrequent);
			foreach(name, apps; appCategories){
				tabs.addPage(name, new ListDesktop(apps.sort!"a.name[0] < b.name[0]".array));
			}
			resize(size);
			tabs.pages[0].button.leftClick();
		}
		super.onMouseFocus(focus);
	}

}


class Categories: Tabs {

	this(){
		super(left);
		offset = 0;
		style.bg = [0.3, 0.3, 0.3, 1];
		style.bg.hover = [0.1, 0.1 ,0.1, 1];
		style.fg = [1, 1, 1, 1];
		setStyle(style);
	}

}


class ListDesktop: List {

	this(DesktopEntry[] applications){
		padding = 3;
		entryHeight = 25;
		applications.each!((DesktopEntry app){
			auto button = addNew!ButtonDesktop([app.name, app.exec].bangJoin);
		});
		style.bg = [27/255.0,27/255.0,27/255.0,1];
	}

	override void onDraw(){
		super.onDraw;
		draw.setColor([0.3,0.3,0.3]);
		draw.rect(pos, [2, size.h]);
	}

}


class ListFrequent: List {

	Entry[] history;

	this(){
		padding = 3;
		entryHeight = 25;
		auto historyFile = "~/.dinu/%s.exec".expandTilde.format(currentDesktop.get);
		writeln(historyFile);
		Entry[string] tmp;
		history = [];
		if(historyFile.exists){
			foreach(line; historyFile.readText.splitLines){
				auto m = line.matchAll(`([0-9]+) (\S+)(?: (.*))?`);
				if(m.captures[3] !in tmp){
					auto e = new Entry;
					e.text = m.captures[3];
					tmp[e.text] = e;
					history ~= e;
				}
				tmp[m.captures[3]].count++;
			}
			history.sort!"a.count > b.count";
		}
		foreach(entry; history){
			auto split = entry.text.bangSplit;
			ButtonExec button;
			switch(split[0]){
				case "desktop":
					button = new ButtonDesktop(split[1]);
					break;
				case "script":
					button = new ButtonScript(split[1]);
					break;
				case "file":
					button = new ButtonFile(split[1]);
					break;
				default:
					writeln("unknown type: ", split[0]);
			}
			if(button){
				button.parameter = split[2];
				add(button);
			}
		}
		style.bg = [27/255.0,27/255.0,27/255.0,1];
	}

	override void onDraw(){
		super.onDraw;
		draw.setColor([0.3,0.3,0.3]);
		draw.rect(pos, [2, size.h]);
	}

}


class ButtonExec: Button {

	string parameter;
	string type;

	this(){
		super("");
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.buttonLeft && !pressed){
			spawnCommand;
			menu.onMouseFocus(false);
		}
	}

	string command(){assert(0);}

	string serialize(){assert(0);}

	void spawnCommand(){
		auto dg = {
			try{
				string command = (command.strip ~ ' ' ~ parameter).strip;
				writeln("running: \"%s\"".format(command));
				auto userdir = "~/.dinu/%s".format(currentDesktop.get).expandTilde;
				auto pipes = pipeShell(command);
				auto pid = pipes.pid.processID;
				logExec("%s exec %s!%s!%s".format(pid, type, serialize.replace("!", "\\!"), parameter.replace("!", "\\!")));
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

}

class ButtonDesktop: ButtonExec {

	string name;
	string exec;

	this(string data){
		auto split = data.bangSplit;
		name = split[0];
		exec = split[1];
		type = "desktop";
	}

	override void onDraw(){
		if(mouseFocus){
			draw.setColor([0.4, 0.4, 0.4]);
			draw.rect(pos, size);
		}
		draw.setColor([189/255.0, 221/255.0, 255/255.0]);
		draw.text(pos.a+[10,0], size.h, name);
		draw.setColor([0.6,0.6,0.6]);
		draw.text(pos.a + [draw.width(name)+15,0], size.h, exec);
	}

	override string command(){
		return exec.replace("%U", parameter).replace("%F", parameter);
	}

	override string serialize(){
		return [name, exec].bangJoin;
	}

}

class ButtonScript: ButtonExec {

	string exec;

	this(string data){
		exec = data;
		type = "script";
	}

	override void onDraw(){
		if(mouseFocus){
			draw.setColor([0.4, 0.4, 0.4]);
			draw.rect(pos, size);
		}
		draw.setColor([187/255.0,187/255.0,255/255.0]);
		draw.text(pos.a+[10,0], size.h, exec);
		draw.setColor([0.6,0.6,0.6]);
		draw.text(pos.a + [draw.width(exec)+15,0], size.h, parameter);
	}

	override string command(){
		return "%s %s".format(exec.strip, parameter.strip).strip;
	}

	override string serialize(){
		return exec;
	}

}

class ButtonFile: ButtonExec {

	string file;

	this(string data){
		file = data;
		type = "file";
	}

	override void onDraw(){
		if(mouseFocus){
			draw.setColor([0.4, 0.4, 0.4]);
			draw.rect(pos, size);
		}
		int x = 10;
		foreach(i, part; file.split("/")){
			bool last = i == file.split("/").length-1;
			if(last)
				draw.setColor([0.933,0.933,0.933]);
			else
				draw.setColor([0.733,0.933,0.733]);
			draw.text(pos.a + [x,0], size.h, part);
			x += draw.width(part);
			draw.setColor([0.6,0.6,0.6]);
			if(!last){
				draw.text(pos.a + [x,0], size.h, "/");
				x += draw.width("/");
			}
		}
	}

	override string command(){
		return "exo-open %s || xdg-open %s".format(file.strip, file.strip).strip;
	}

	override string serialize(){
		return file;
	}

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

