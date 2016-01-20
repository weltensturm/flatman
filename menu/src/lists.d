module menu.lists;


import menu;


class ListDesktop: Scroller {

	DynamicList list;

	this(DesktopEntry[][string] apps, string[string] categories){

		list = new DynamicList;
		list.padding = 3;
		list.style.bg = [0.1,0.1,0.1,1];
		add(list);

		foreach(name; categories.values.sort!"a.toUpper < b.toUpper"){
			if(name !in apps)
				continue;

			auto buttonCategory = new Button(name);
			buttonCategory.resize([5,20]);
			auto tree = new Tree(buttonCategory);
			tree.expanded = true;
			tree.padding = 0;
			list.add(tree);

			foreach(app; apps[name].sort!"a.name.toUpper < b.name.toUpper"){
				auto button = new ButtonDesktop([app.name, app.exec].bangJoin);
				button.resize([5,20]);
				tree.add(button);
			}

			tree.update;
		}

	}

	override void onDraw(){
		draw.setColor([0.1,0.1,0.1]);
		draw.rect(pos, size);
		super.onDraw;
		draw.setColor([0.3,0.3,0.3]);
		draw.rect(pos.a+[0,size.h-2], [size.w, 2]);
	}

}


class ListFrequent: Scroller {

	DynamicList list;

	Entry[] history;

	this(){
		list = addNew!DynamicList;
		list.padding = 0;
		list.style.bg = [0.1,0.1,0.1,1];
		auto historyFile = "~/.dinu/%s.exec".expandTilde.format(currentDesktop.get);
		writeln(historyFile);
		Entry[string] tmp;
		history = [];
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
				button.resize([5,20]);
				button.parameter = split[2];
				list.add(button);
			}
		}
		style.bg = [0.1,0.1,0.1,1];
	}

	override void onDraw(){
		draw.setColor([0.1,0.1,0.1]);
		draw.rect(pos, size);
		super.onDraw;
		draw.setColor([0.3,0.3,0.3]);
		draw.rect(pos.a+[0,size.h-2], [size.w, 2]);
	}

}
