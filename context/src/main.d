module context;


import
	std.stdio,
	std.path,
	std.file,
	std.random,
	std.conv,
	x11.X,
	x11.Xlib,
	x11.Xatom,
	ws.x.property;


enum PATH = "~/.flatman/";


void main(string[] args){
	if(args.length < 2)
		getContext.writeln;
	else if(args[1] == "-p")
		getContextPath.writeln;
	else
		args[1].setContext;
}


string getContext(){
	auto cur = (PATH ~ "current").expandTilde;
	if(!cur.exists || !cur.readText.exists)
		return "~";
	return cur.readText.readText;
}


string getContextPath(){
	return (PATH ~ "current").expandTilde.readText;
}


void setContext(string context){
	if(!PATH.expandTilde.exists)
		mkdir(PATH.expandTilde);
	foreach(e; PATH.expandTilde.dirEntries("*.context", SpanMode.shallow)){
		if(e.readText == context){
			std.file.write((PATH ~ "current").expandTilde, e);
			return;
		}
	}
	auto path = (uniform01*100000000000000).to!long.to!string ~ ".context";
	std.file.write(PATH.expandTilde ~ "current", path);
	std.file.write(PATH.expandTilde ~ path, context);
}

