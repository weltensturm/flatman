module flatman.commands;

import flatman;


string delegate(string[])[string] functions;


string call(Args...)(string fn, Args args){
	string[Args.length] stringArgs;
	foreach(i, arg; args)
		stringArgs[i] = arg.to!string;
	`calling "%s" with "%s"`.format(fn, stringArgs).log;
	return call(fn, stringArgs);
}


string call()(string fn, string[] args){
	if(fn in functions)
		return functions[fn](args);
	`ERROR: Function not found "%s"`.format(fn).log;
	return "";
}


void register(T,Args...)(string name, T delegate(Args) dg){
	functions[name] = delegate(string[] args){
		Args tuple;
		static if(Args.length == 1){
			tuple[0] = args.join(" ");
		}else{
			foreach(i, type; Args)
				tuple[i] = args[i].to!(Args[i]);
		}
		static if(is(T == void)){
			dg(tuple);
			return "";
		}else
			return dg(tuple).to!string;
	};
}


void register(T,Args...)(string name, T function(Args) fn){
	register(name, fn.toDelegate);
}


void registerFunctions(){
	register("exec", (string command){ spawnShell(command); });
	register("focus", &focus);
	register("resize", &resize);
	register("move", &move);
	register("toggle", &toggle);
	register("killclient", {killclient;});
	register("quit", &quit);
	register("workspace", &workspace);
	register("reload", &reload);
	register("insert", &toggleTabs);
}


void focus(string what, string dir){
	if(what == "dir")
		monitor.workspace.focusDir(dir == "+" ? 1 : -1);
	else if(what == "stack")
		monitor.workspace.focusTabs(dir == "+" ? 1 : -1);
}

void resize(string what){
	if(what == "+")
		sizeInc;
	else if(what == "-")
		sizeDec;
	else if(what == "mouse")
		mouseresize;
}

void move(string what){
	final switch(what){
		case "+":
			monitor.moveRight;
			break;
		case "-":
			monitor.moveLeft;
			break;
		case "up":
			monitor.moveUp;
			break;
		case "down":
			monitor.moveDown;
			break;
		case "mouse":
			mousemove;
			break;
	}
}

void toggle(string what){
	final switch(what){
		case "titles":
			
			break;
		case "floating":
			togglefloating;
			break;
		case "fullscreen":
			togglefullscreen;
			break;
	}
}

void workspace(string dir, string how){
	with(monitor){
		if(dir == "+"){
			if(how == "filled"){
				foreach(i; workspaceActive+1..workspaces.length){
					if(workspaces[i].clients.length){
						switchWorkspace(cast(int)i);
						return;
					}
				}
			}else if(how == "create"){
				newWorkspace(workspaceActive+1);
				switchWorkspace(workspaceActive+1);
			}else
			switchWorkspace(workspaceActive+1);
		}else if(dir == "-"){
			if(how == "filled"){
				foreach_reverse(i; 0..workspaceActive){
					if(workspaces[i].clients.length){
						switchWorkspace(i);
						return;
					}
				}
			}else if(how == "create"){
				newWorkspace(workspaceActive);
				switchWorkspace(workspaceActive-1);
			}else
				switchWorkspace(workspaceActive-1);
		}else if(dir == "first"){
			if(how == "create"){
				newWorkspace(0);
				firstWs;
			}else
				switchWorkspace(0);
		}else if(dir == "last"){
			if(how == "create"){
				newWorkspace(workspaces.length);
				lastWs;
			}else
				switchWorkspace(workspaces.length.to!int-1);
		}
	}
}

void reload(){
	config.load;
	flatman.keys = [];
	registerConfigKeys;
	grabkeys;
}

void toggleTabs(){
	auto s = monitor.workspace.split.to!Split;
	if(s.clients){
		auto tabs = s.children[s.clientActive].to!Tabs;
		tabs.showTabs = !tabs.showTabs;
		tabs.resize(tabs.size);
		tabs.onDraw;
	}
}
