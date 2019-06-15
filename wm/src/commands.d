module flatman.commands;

import flatman;


string delegate(bool, string[])[string] functions;


string call(Args...)(bool pressed, string fn, Args args){
	string[Args.length] stringArgs;
	foreach(i, arg; args)
		stringArgs[i] = arg.to!string;
	return call(pressed, fn, stringArgs);
}


string call()(bool pressed, string fn, string[] args){
	Command(fn, pressed, args);
	if(fn in functions){
		return functions[fn](pressed, args);
	}
	`ERROR: Function not found "%s"`.format(fn).log;
	return "";
}


void register(T, Args...)(string name, T delegate(Args) dg){
	functions[name] = delegate(bool pressed, string[] args){
		if(!pressed && !is(Args[0] == bool))
			return "";
		with(Log(`"%s(%s, %s)"`.format(name, pressed, args))){
			Args tuple;
			static if(!is(Args[0] == bool) && Args.length == 1){
				tuple[0] = args.join(" ");
			}else static if(is(Args[0] == bool)){
				tuple[0] = pressed;
				foreach(i, type; Args[1..$])
					tuple[i+1] = args[i].to!type;
			}else{
				foreach(i, type; Args)
					tuple[i] = args[i].to!(Args[i]);
			}
			static if(is(T == void)){
				dg(tuple);
				return "";
			}else
				return dg(tuple).to!string;
		}
	};
}


void register(T, Args...)(string name, T function(Args) fn){
	register(name, fn.toDelegate);
}


void spawnCommand(string command){
	auto t = new Thread({ spawnShell(command).wait; });
	t.isDaemon = true;
	t.start;
}


void registerFunctions(){
	register("exec", &spawnCommand);
	register("focus", &focusCmd);
	register("resize", &resize);
	register("move", &move);
	register("toggle", &toggle);
	register("killclient", {killClient;});
	register("quit", &quit);
	register("workspace", &workspace);
	register("workspace-history", &workspaceHistory);
	register("reload", &reload);
	register("insert", &toggleTabs);
	register("overview", &overview);
}


void workspaceHistory(string){}


void focusCmd(string what, string dir){
	if(what == "tab")
		focusTab(dir);
	else if(what == "dir")
		focusDir(dir);
}

void resize(string what){
	if(what == "+")
		monitor.workspace.split.sizeInc;
	else if(what == "-")
		monitor.workspace.split.sizeDec;
	else if(what == "mouse")
		mouseResize;
}

void move(string what){
	final switch(what){
		case "right":
			moveRight;
			break;
		case "left":
			moveLeft;
			break;
		case "up":
			moveUp;
			break;
		case "down":
			moveDown;
			break;
		case "mouse":
			mouseMove;
			break;
	}
}

void toggle(string what){
	final switch(what){
		case "titles":

			break;
		case "floating":
			if(active)
				active.togglefloating;
			break;
		case "fullscreen":
			toggleFullscreen;
			break;
	}
}

void workspace(string dir, string how){
	if(dir == "+"){
		if(how == "create")
			newWorkspace(monitor.workspaceActive+1);
		switchWorkspace(monitor.workspaceActive+1);
	}else if(dir == "-"){
		if(how == "create")
			newWorkspace(monitor.workspaceActive);
		switchWorkspace(monitor.workspaceActive-1);
	}else if(dir == "first"){
		if(how == "create")
			newWorkspace(0);
		switchWorkspace(0);
	}else if(dir == "last"){
		if(how == "create")
			newWorkspace(monitor.workspaces.length);
		switchWorkspace(monitor.workspaces.length.to!int-1);
	}
}

void reload(){
	//config.load;
	//flatman.keys = [];
	//registerConfigKeys;
	//grabkeys;
	restart = true;
	running = false;
}

void toggleTabs(){
	auto s = monitor.workspace.split.to!Split;
	if(s.clients){
		auto tabs = s.children[s.clientActive].to!Tabs;
		tabs.showTabs = !tabs.showTabs;
		tabs.resize(tabs.size);
	}
}

bool doOverview = false;
SysTime overviewStart;
enum overviewTime = 1000/(60*0.06);


void overview(bool activate){
	if(!activate && overviewStart < Clock.currTime-overviewTime.to!long.msecs || activate && !doOverview){
		overviewStart = Clock.currTime;
		if(activate){
			doOverview = true;
			root.replace(Atoms._FLATMAN_OVERVIEW, 1L);
			Overview(true);
		}else{
			doOverview = false;
			root.replace(Atoms._FLATMAN_OVERVIEW, 0L);
			Overview(false);
			if(active){
				focus(active);
			}
		}
	}else if(activate && overviewStart > Clock.currTime-overviewTime.to!long.msecs)
		overviewStart = Clock.currTime-overviewTime.to!long.msecs;
}


void teleport(Client client, Client target, long mode){
	client.monitor.remove(client);
	if(auto c = cast(Split)target.parent){
		auto i = c.children.countUntil(target);
		c.add(client, i);
	}else if(auto c = cast(Container)target.parent){
		c.add(client);
	}else{
		"could not add %s to %s".format(client, target).log;
		monitor.add(client);
	}
}
