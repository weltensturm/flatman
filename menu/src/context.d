module menu.context;


import menu;


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