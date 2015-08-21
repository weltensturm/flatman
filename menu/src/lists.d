module menu.lists;

import menu;


class ListDesktop: DynamicList {

	this(DesktopEntry[] applications){
		padding = 3;
		applications.each!((DesktopEntry app){
			auto button = new ButtonDesktop([app.name, app.exec].bangJoin);
			button.resize([5,25]);
			add(button);
		});
		style.bg = [0.1,0.1,0.1,1];
	}

	override void onDraw(){
		super.onDraw;
		draw.setColor([0.3,0.3,0.3]);
		draw.rect(pos, [2, size.h]);
	}

}

void sortDir(ref string[] dirs){
	dirs.sort!("a.toUpper < b.toUpper", SwapStrategy.stable);
	dirs.sort!("!a.startsWith(\".\") && b.startsWith(\".\")", SwapStrategy.stable);
}

void loadAddDir(string directory, Base container){
	writeln(directory);
	string[] dirs;
	string[] files;
	directory = directory.chomp("/") ~ "/";
	foreach(string entry; directory.dirEntries(SpanMode.shallow)){
		if(entry.isDir)
			dirs ~= entry.chompPrefix(directory);
		else
			files ~= entry.chompPrefix(directory);
	}
	dirs.sortDir;
	files.sortDir;
	dirs.each!(delegate(string dir){
		auto button = new ButtonFile(directory ~ dir);
		button.resize([5,25]);
		auto tree = new Tree(button);
		tree.padding = 0;
		bool once;
		button.leftClick ~= {
			if(!once)
				loadAddDir(directory ~ dir, tree);
			once = true;
		};
		container.add(tree);
		tree.update;
	});
	foreach(file; files){
		auto button = new ButtonFile(directory ~ file);
		button.resize([5,25]);
		container.add(button);
	}
}

class ListFiles: Scroller {

	DynamicList list;

	this(){
		list = addNew!DynamicList;
		list.padding = 0;
		list.style.bg = [0.1,0.1,0.1,1];
		loadAddDir(context, list);
	}

	override void onDraw(){
		draw.setColor([0.1,0.1,0.1]);
		draw.rect(pos, size);
		super.onDraw;
		draw.setColor([0.3,0.3,0.3]);
		draw.rect(pos, [2, size.h]);
	}


}



class ListFrequent: DynamicList {

	Entry[] history;

	this(){
		padding = 3;
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
				button.resize([5,25]);
				button.parameter = split[2];
				add(button);
			}
		}
		style.bg = [0.1,0.1,0.1,1];
	}

	override void onDraw(){
		super.onDraw;
		draw.setColor([0.3,0.3,0.3]);
		draw.rect(pos, [2, size.h]);
	}

}
