module context;


import
	std.stdio,
	std.path,
	std.file,
	std.random,
	std.conv,
	std.array,
	x11.X,
	x11.Xlib,
	x11.Xatom;


enum PATH = "~/.flatman/";


void main(string[] args){

	version(unittest){ import core.stdc.stdlib: exit; exit(0); }

	if(args.length < 2)
		getContext.writeln;
	else if(args[1] == "-p")
		getContextPath.writeln;
	else if(args[1] == "-c")
		args[2].clean.createContext;
	else
		args[1].clean.setContext;
}


string clean(string path){
	return path.expandTilde.absolutePath.buildNormalizedPath;
}

string getContext(){
	auto cur = (PATH ~ "current").clean;
	if(!cur.exists || !cur.readText.exists){
		setContext("~".clean);
		cur = (PATH ~ "current").clean;
	}
	return cur.readText.readText;
}


string getContextPath(){
	return (PATH ~ "current").expandTilde.readText;
}


void setContext(string context){
	context.createContext;
	auto path = context.replace("/", "-") ~ ".context";
	std.file.write(PATH.expandTilde ~ "current", PATH.expandTilde ~ path);
}

void createContext(string context){
	if(!PATH.expandTilde.exists)
		mkdir(PATH.expandTilde);
	auto path = context.replace("/", "-") ~ ".context";
	std.file.write(PATH.expandTilde ~ path, context);
}
