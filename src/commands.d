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


void focus(string what){
	monitor.workspace.focusDir(what == "+" ? 1 : -1);
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
	if(dir == "+"){
		if(how == "filled")
			monitor.nextWsFilled;
		else
			monitor.nextWs;
	}else{
		if(how == "filled")
			monitor.prevWsFilled;
		else
			monitor.prevWs;
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
