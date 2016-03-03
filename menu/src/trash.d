module menu.trash;


import menu;


void addTrash(DynamicList list){
	auto b = new RootButton("Trash");
	b.resize([5, config["button-tab", "height"].to!int]);
	auto t = list.addNew!Tree(b);
	b.set(t);

	b.leftClick ~= {
		foreach(c; list.children){
			if(auto tr = cast(Tree)c){
				if(t != tr && tr.expanded)
					tr.toggle;
			}
		}
	};

	ButtonTrash[] buttons;

	foreach(entry; "~/.local/share/Trash/info".normalize.dirEntries(SpanMode.shallow))
		if(entry.name.endsWith(".trashinfo"))
			try
				buttons ~= new ButtonTrash(entry.name);
			catch(Exception e)
				e.writeln;

	buttons.sort!((a, b) => a.date > b.date);

	void addButton(ButtonTrash button){
		button.font = config["button-tree", "font"];
		button.fontSize = config["button-tree", "font-size"].to!int;
		button.resize([5, config["button-tree", "height"].to!int]);
		auto menu = t.addNew!Tree(button);
		menu.inset = 20;

		auto mb = new Button("View");
		mb.font = button.font;
		mb.fontSize = button.fontSize;
		mb.resize([5, config["button-tree", "height"].to!int]);
		mb.leftClick ~= {
			if(button.isDir)
				contextPath.openDir("~/.local/share/Trash/files/".expandTilde ~ button.trashPath.baseName.stripExtension);
			else
				contextPath.openFile("~/.local/share/Trash/files/".expandTilde ~ button.trashPath.baseName.stripExtension);
		};
		menu.add(mb);

		mb = new Button("Restore");
		mb.font = button.font;
		mb.fontSize = button.fontSize;
		mb.resize([5, config["button-tree", "height"].to!int]);
		menu.add(mb);

		mb = new Button("Delete");
		mb.font = button.font;
		mb.fontSize = button.fontSize;
		mb.resize([5, config["button-tree", "height"].to!int]);
		menu.add(mb);
	}

	foreach(button; buttons){
		addButton(button);
	}

	auto watcher = menuWindow.inotify.addWatch("~/.local/share/Trash/info/".normalize, false);
	watcher.add ~= (p, f){
		try
			addButton(new ButtonTrash(p ~ '/' ~ f));
		catch{}
	};
}


class ButtonTrash: ButtonExec {

	string trashPath;
	string path;
	string date;
	bool isDir;

	this(string trashPath){
		this.trashPath = trashPath;
		foreach(line; trashPath.readText.splitLines){
			if(line.startsWith("Path="))
				path = line.chompPrefix("Path=").nice;
			else if(line.startsWith("DeletionDate="))
				date = line.chompPrefix("DeletionDate=").split("T").join(" ")[0..$-3];
		}
		isDir = ("~/.local/share/Trash/files/" ~ trashPath.baseName.stripExtension).normalize.isDir;
	}

	override void spawnCommand(){}

	override void onDraw(){
		if(pos.y+size.h<0 || pos.y>menuWindow.size.h)
			return;
		if(mouseFocus){
			auto mul = 1.2-(now-clickTime-0.2).min(0.2);
			draw.setColor([0.15*mul, 0.15*mul, 0.15*mul]);
			draw.rect(pos, size);
		}

		auto pathWidth = (size.w-draw.width(date)-15);

		auto offset = 1-((pathWidth-pos.x-cursorPos.x).to!double/pathWidth).min(1).max(0);

		auto advance = 10-(hasMouseFocus ? offset*(draw.width(path)+20-pathWidth).max(0) : 0).lround.to!int;
		auto parts = path.split("/");

		draw.clip(pos.a, [pathWidth, size.h]);
		draw.setFont(config["button-tree", "font"], config["button-tree", "font-size"].to!int);

		foreach(i, part; parts){
			draw.setColor(!isDir && i == parts.length-1 ? [1,1,1.0] : [0.733,0.933,0.733]);
			advance += draw.text(pos.a+[advance,0], size.h, part);
			draw.setColor([0.5,0.5,0.5]);
			if(isDir || i < parts.length-1)
				advance += draw.text([pos.x+advance, pos.y], size.h, "/");
		}
		draw.noclip;

		auto textw = draw.width(path) + draw.fontHeight*2;
		draw.setColor([0.4,0.4,0.4]);
		draw.text(pos.a + [size.w-draw.width(date)-15,0], size.h, date);
	}

}


void trash(string path){
	int nameCount;
	string base = path.baseName.stripExtension;
	string extension = path.extension;
	string trashName = base ~ extension;
	while(("~/.local/share/Trash/files/".expandTilde ~ trashName).exists){
		nameCount++;
		trashName = "%s.%s.%s".format(base, nameCount, extension);
	}
	rename(path, "~/.local/share/Trash/files/".expandTilde ~ trashName);
	string info =
			("[Trash Info]\n"
			~ "Path=%s\n"
			~ "DeletionDate=%s\n"
			).format(path, Clock.currTime.toISOExtString[0..19]);
	std.file.write("~/.local/share/Trash/info/".expandTilde ~ trashName ~ ".trashinfo", info);
}


void restore(string trashPath){

}
