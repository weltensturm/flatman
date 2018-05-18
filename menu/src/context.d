module menu.context;


import menu;


__gshared:


class Context {
	
	__gshared string current;
	__gshared string currentPath;

	__gshared ws.event.Event!(string) change;

	static void init(){
		change = new ws.event.Event!string;
		string currentContext = "";
		Inotify.watch("~/.flatman/current".normalize, (path, file, action){
			current = "~/.flatman/current".normalize.readText;
			currentPath = current.readText;
			if(currentContext != currentPath){
				change(current);
				writeln("context = " ~ currentPath);
				currentContext = currentPath;
			}
		});
	}

}



class Entry {
	int count;
	string text;
}


string context(){
	return ["flatman-context"].execute.output.strip;
}


string contextPath(){
	return ["flatman-context", "-p"].execute.output.strip;
}


void setContext(string context){
	["flatman-context", context.normalize].execute;
}


string historyFile(){
	return contextPath ~ ".exec";
}

string logFile(){
	return contextPath ~ ".log";
}


string[] history(){
	Entry[string] tmp;
	Entry[] history;
	if(historyFile.exists){
		int count = 0;
		foreach(line; historyFile.readText.splitLines){
			auto m = line.matchAll(`([0-9]+) (\S+)(?: (.*))?`);
			if(m.captures[3] !in tmp){
				auto e = new Entry;
				e.text = m.captures[3];
				tmp[e.text] = e;
				history ~= e;
			}
			tmp[m.captures[3]].count = count++;
		}
		history.sort!"a.count > b.count";
	}
	return history.map!"a.text".array;
}


struct CommandInfo {
	int pid;
	string serialized;
	int status = int.max;
}


CommandInfo[] historyInfo(){
	CommandInfo[] history;
	foreach(line; historyFile.readText.splitLines){
		auto m = line.matchAll(`([0-9]+) exec(?: (.*))?`);
		if(!m.empty){
			history ~= CommandInfo(m.captures[1].to!int, m.captures[2]);
		}
		m = line.matchAll(`([0-9]+) exit(?: (.*))?`);
		if(!m.empty){
			foreach(ref h; history){
				if(h.pid == m.captures[1].to!int)
					h.status = m.captures[2].to!int;
			}
		}
	}
	return history;
}