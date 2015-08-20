module menu.lists;

import menu;


class ListDesktop: List {

	this(DesktopEntry[] applications){
		padding = 3;
		entryHeight = 25;
		applications.each!((DesktopEntry app){
			auto button = addNew!ButtonDesktop([app.name, app.exec].bangJoin);
		});
		style.bg = [0.3,0.3,0.3,1];
	}

	override void onDraw(){
		super.onDraw;
		draw.setColor([0.3,0.3,0.3]);
		draw.rect(pos, [2, size.h]);
	}

}

class ListFiles: List {

	this(){
		padding = 3;
		entryHeight = 25;
		ButtonFile[] buttons;
		foreach(entry; context.dirEntries(SpanMode.shallow)){
			auto name = entry.to!string.chompPrefix(context ~ "/");
			if(name.startsWith(".") || name.baseName.startsWith("."))
				continue;
			buttons ~= new ButtonFile(name);
		}
		buttons.sort!("a.file.toUpper < b.file.toUpper", SwapStrategy.stable);
		buttons.sort!("!a.file.startsWith(\".\") && b.file.startsWith(\".\")", SwapStrategy.stable);
		buttons.sort!("a.isDir && !b.isDir", SwapStrategy.stable);
		buttons ~= new ButtonFile(".");
		foreach(b; buttons)
			add(b);
		style.bg = [0.3,0.3,0.3,1];
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
		style.bg = [0.3,0.3,0.3,1];
	}

	override void onDraw(){
		super.onDraw;
		draw.setColor([0.3,0.3,0.3]);
		draw.rect(pos, [2, size.h]);
	}

}
