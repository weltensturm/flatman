module menu.files;


import menu;


string[] contexts;


Tree addFiles(DynamicList list, Inotify.WatchStruct* watcher){
	auto buttonContexts = new RootButton("Files");
	buttonContexts.resize([5, config["button-tab", "height"].to!int]);
	auto contexts = list.addNew!FileTree(buttonContexts, false);
	contexts.inset = 0;
	contexts.tail = 10;
	buttonContexts.set(contexts);
	contexts.expanded = true;
	contexts.padding = 0;

	auto addContext = (string context){
		.contexts ~= context;
		contexts.addDir(context, true);
	};

	auto add = (string p, string f){
		if(!f.endsWith(".context"))
			return;
		auto c = (p ~ "/" ~ f).readText.strip;
		addContext(c);
	};

	auto remove = (string p, string f){
		if(!f.endsWith(".context"))
			return;
		foreach(directory; contexts.children[1..$].to!(DirectoryTree[])){
			auto button = directory.children[0].to!ButtonFile;
			writeln(f, ' ', button.file.replace("/", "-"));
			if(button.file.replace("/", "-") ~ ".context" == f){
				contexts.remove(directory);
				return;
			}
		}
	};

	auto change = (string p, string f){
		if(!f.endsWith("current"))
			return;
		auto d = (p ~ "/" ~ f).readText.strip;
		auto c = d.readText.strip;
		foreach(directory; contexts.children[1..$].to!(DirectoryTree[])){
			auto button = directory.children[0].to!ButtonFile;
			button.isSelectedContext = c == button.file;
			if(button.isSelectedContext != directory.expanded)
				button.leftClick();
		}
	};

	foreach(entry; "~/.flatman/".normalize.dirEntries(SpanMode.breadth))
		if(entry.name.endsWith(".context"))
			add(entry.name.dirName, entry.name.baseName);

	addContext("/");

	watcher.add ~= add;
	watcher.change ~= change;
	watcher.remove ~= remove;

	return contexts;
}


interface Path {
	string name();
	string path();
	bool isDirectoryTree();
	void tick();
}


class InputFieldFile: InputField {

	string type;

	this(string type){
		this.type = type;
	}

	override void onDraw(){
		auto color = style.fg.normal;
		
		auto t = now;

		auto alpha = (sin(t*PI*2)+0.5).min(1).max(0)*0.9+0.1;
		draw.setColor([1*alpha,1*alpha,1*alpha]);
		int x = 10+draw.width(text[0..cursor]);
		draw.rect(pos.a + [x+4, 2], [1, size.h-4]);
		
		if(errorTime+2 > t){
			alpha = clamp!float(errorTime+2 - t, 0, 1)/1;
			draw.setColor([1,0,0,alpha]);
			draw.rect(pos, size);
			draw.setFont("Consolas", 9);
			draw.setColor([1,1,1,alpha]);
			draw.text(pos.a + [2, 0], size.h, error);
		}
		draw.setColor(type == "directory" ? (text.startsWith(".") ? [0.4,0.5,0.4] : [0.733,0.933,0.733])
					: (text.startsWith(".") ? [0.4,0.4,0.4] : [0.933,0.933,0.933]));
		draw.text(pos.a+[10,0], size.h, text);
	}


}


class ButtonFile: ButtonExec, Path {

	string file;
	string parentDir;
	bool isDir;
	bool isContext;
	bool isSelectedContext;
	bool dirExpanded;

	bool previewDrop;

	Base dragGhost;
	int[2] dragOffset;
	Base dropWhere;

	this(string data, bool isDir, bool isContext=false){
		this.isDir = isDir;
		this.isContext = isContext;
		//data = data.normalize;
		if(isDir){
			auto enter = new Button("→");
			enter.font = "Arial";
			enter.fontSize = 9;
			enter.style.bg.hover = [0.5,0.5,0.5,1];
			enter.leftClick ~= () => setContext(data);
			add(enter);
		}
		file = data;
		type = "file";
		if(parentDir.length)
			parentDir ~= "/";
		this.parentDir = parentDir;
		isSelectedContext = context == file;
		rightClick ~= &openPopup;
	}

	override string name(){
		return isContext ? file : file.baseName;
	}

	override string path(){
		return file;
	}

	override bool isDirectoryTree(){
		return isDir;
	}

	override void tick(){}

	void openPopup(){
		alias A = ListPopup.Action;
		A[] buttons;
		buttons ~= A("Open", { contextPath.openFile(file.normalize); });
		if(isDir){
			buttons ~= A("Add File", {
				if(menuWindow.keyboardFocus)
					menuWindow.keyboardFocus.parent.remove(menuWindow.keyboardFocus);
				auto input = new InputFieldFile("file");
				parent.children = parent.children[0..1] ~ input ~ parent.children[1..$];
				input.parent = parent;
				parent.keyboardChild = input;
				input.resize([5, config["button-tree", "height"].to!int]);
				input.onEnter ~= (s){
					try {
						std.file.write(file ~ '/' ~ input.text, "");
						parent.remove(input);
						menuWindow.keyboardFocus = null;
					}catch(Exception e)
						throw new InputException(input, "Could not create file.");
				};
				menuWindow.keyboardFocus = input;
			});

			buttons ~= A("Add Directory", {
				if(menuWindow.keyboardFocus)
					menuWindow.keyboardFocus.parent.remove(menuWindow.keyboardFocus);
				auto input = new InputFieldFile("directory");
				parent.children = parent.children[0..1] ~ input ~ parent.children[1..$];
				input.parent = parent;
				parent.keyboardChild = input;
				input.resize([5, config["button-tree", "height"].to!int]);
				input.onEnter ~= (s){
					try {
						mkdir(file ~ '/' ~ input.text);
						parent.remove(input);
						menuWindow.keyboardFocus = null;
					}catch(Exception e)
						throw new InputException(input, "Could not create file.");
				};
				menuWindow.keyboardFocus = input;
			});
		
			buttons ~= A("Set Context", { ["flatman-context", file].execute; });

			if(contexts.canFind(file.normalize)){
				buttons ~= A("Remove Context", {
					foreach(entry; "~/.flatman/".normalize.dirEntries(SpanMode.breadth)){
						if(entry.name.endsWith(".context")){
							auto c = entry.name.normalize.readText;
							if(c == file){
								std.file.remove(entry.name);
								.contexts = .contexts.without(c);
								return;
							}
						}
					}
				});
			}
		
		}
		buttons ~= A("Trash", {
			trash(file);
		});
		auto popup = new ListPopup(buttons);
		menuWindow.popups ~= popup;
		wm.add(popup);
	}

	override void resize(int[2] size){
		super.resize(size);
		foreach(i, c; children){
			c.move(pos.a + [size.w - size.h*i.to!int, 0]);
			c.resize([size.h,size.h]);
		}
	}

	override void onDraw(){
		if(pos.y+size.h<0 || pos.y>menuWindow.size.h)
			return;
		if(previewDrop){
			draw.setColor([0.2, 0.2, 0.2]);
			draw.rect(pos, size);
		}else{
			if(isDir && parent.to!Tree.expanded){
				draw.setColor([0.13,0.13,0.13]);
				draw.rect(pos.a+[1,0], size.a-[1,0]);
			}
			super.onDraw;
		}
		if(file == ".")
			return;
		auto text = isContext ? file.nice : file.baseName;
		draw.setFont(config["button-tab", "font"], config["button-tab", "font-size"].to!int);
		if(isContext){
			int advance = 10;
			auto parts = text.split("/");
			foreach(i, part; parts){
				draw.setColor(isSelectedContext ? [1,0.7,.2] : [0.733,0.933,0.733]);
				advance += draw.text([pos.x+advance, pos.y], size.h, part);
				draw.setColor([0.5,0.5,0.5]);
				advance += draw.text([pos.x+advance, pos.y], size.h, "/");
			}
		}else{
			draw.setColor(
				isDir ?
					(text.startsWith(".") ? [0.4,0.5,0.4] : [0.733,0.933,0.733])
					: (text.startsWith(".") ? [0.4,0.4,0.4] : [0.933,0.933,0.933])
			);
			draw.text(pos.a + [10,0], size.h, text);			
		}

		draw.setColor([0.6,0.6,0.6]);
		if(hasMouseFocus)
			foreach(c; children)
				c.onDraw;
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		Base.onMouseButton(button, pressed, x, y);
		if(!dragGhost)
			super.onMouseButton(button, pressed, x, y);
		if(button == Mouse.buttonLeft){
			if(!pressed && dragGhost){
				root.remove(dragGhost);
				if(dropWhere)
					dropWhere.drop(x, y, dragGhost);
				dragGhost = null;
			}
		}
	}

	override void onMouseMove(int x, int y){
		if(!isDir && buttons.get(Mouse.buttonLeft, false) && !dragGhost){
			dragGhost = drag([x,y].a - pos);
			root.add(dragGhost);
			root.setTop(dragGhost);
			dragGhost.resize(size);
			writeln("dragStart");
		}
		if(dragGhost){
			dragGhost.move([x,y].a - dragOffset);
			if(root.dropTarget(x, y, dragGhost) != dropWhere){
				if(dropWhere)
					dropWhere.dropPreview(x, y, dragGhost, false);
				dropWhere = root.dropTarget(x, y, dragGhost);
				if(dropWhere)
					dropWhere.dropPreview(x, y, dragGhost, true);
			}
		}
		super.onMouseMove(x, y);
	}

	override Base drag(int[2] offset){
		return new ButtonFileGhost(this);
	}

	override Base dropTarget(int x, int y, Base draggable){
		if(isDir && cast(ButtonFileGhost)draggable)
			return this;
		return super.dropTarget(x, y, draggable);
	}

	override void dropPreview(int x, int y, Base draggable, bool start){
		previewDrop = start;
	}

	override void drop(int x, int y, Base draggable){
		root.remove(draggable);
		auto button = cast(ButtonFileGhost)draggable;
		"moving %s to %s".format(button.source.file, file).writeln;
		chdir(context);
		auto res = "mv '%s' '%s'".format(button.source.file.normalize, file.normalize).executeShell;
		if(res.status){
			res.output.writeln;
		}
		previewDrop = false;
	}

	override void spawnCommand(){
		if(isDir)
			return;
		contextPath.openFile(file.normalize);
	}

}



auto dirSorter(Path a, Path b){
	if(a.name.startsWith(".") != b.name.startsWith("."))
		return b.name.startsWith(".");
	if(a.isDirectoryTree != b.isDirectoryTree)
		return a.isDirectoryTree;
	return a.name.toUpper < b.name.toUpper;
}



class FileTree: Tree {

	bool drawHint;

	this(Button button, bool drawHint=true){
		super(button);
		inset = 15;
		tail = 0;
		this.drawHint = drawHint;
	}

	override Base add(Base element){
		if(children.length > 1){
			bool found;
			foreach(i, c; children){
				if(cast(Path)c && cast(Path)element && c != expander && dirSorter(element.to!Path, c.to!Path)){
					//children = children[0..i] ~ element ~ children[i..$];
					children.insertInPlace(i, element);
					found = true;
					break;
				}
			}
			if(!found)
				children ~= element;
		}else
			children ~= element;

		element.parent = this;
		
		update;
		return element;
	}

	override void onDraw(){
		if(pos.y+size.h<0 || pos.y>menuWindow.size.h)
			return;
		if(expanded && drawHint){
			draw.setColor([0.2,0.2,0]);
			draw.rect(pos.a+[15,0], [1, size.h-children[0].size.h]);
			draw.rect(pos.a+[15,0], [size.w-15, 1]);
		}
		super.onDraw;
	}

}


class DirectoryTree: FileTree, Path {

	Inotify.WatchStruct* watcher;

	shared Queue!string queue;

	ButtonFile button;

	string root;

	this(ButtonFile button, string directory){
		queue = new shared Queue!string;
		this.button = button;
		this.root = root;
		button.resize([5,config["button-tree", "height"].to!int]);
		padding = 0;
		super(button);
		bool once;
		button.leftClick ~= {
			if(!once){
				task({ loadAddDir(directory, queue); }).executeInNewThread;
				watcher = menuWindow.inotify.addWatch(directory, false);
				watcher.add ~= (p, f) => add(p ~ '/' ~ f);
				watcher.remove ~= (p, f) => remove(p ~ '/' ~ f);
			}
			once = true;
		};
		if(button.isContext && button.isSelectedContext)
			button.leftClick();
	}

	override string name(){
		return button.name;
	}

	override string path(){
		return button.file;
	}

	override bool isDirectoryTree(){
		return true;
	}

	alias add = super.add;

	void add(string path){
		try {
			if(!path.exists)
				return;
			if(path.isDir)
				this.addDir(path);
			else
				this.addFile(path);
		}catch(Exception e)
			writeln(e);
	}

	void remove(string file){
		writeln("removing " ~ file);
		foreach(c; children){
			if(c != expander && cast(Path)c && c.to!Path.path == file){
				super.remove(c);
				return;
			}
		}
	}

	override void tick(){
		foreach(i;0..10)
			if(queue.has)
				add(queue.get);
		foreach(c; children)
			if(auto p = cast(Path)c)
				p.tick;
	}

	override void onDraw(){
		super.onDraw;
	}

}


class ButtonFileGhost: Base {

	ButtonFile source;

	this(ButtonFile source){
		this.source = source;
	}

	override void onDraw(){
		draw.setColor([0.8,0.8,0.8]);
		draw.text(pos, source.file.baseName);
	}

}


void addDir(FileTree container, string directory, bool isContext=false){
	auto tree = new DirectoryTree(new ButtonFile(directory, true, isContext), directory);
	container.add(tree);
	tree.update;
}


void addFile(FileTree container, string path){
	auto button = new ButtonFile(path, false);
	button.resize([5, config["button-tree", "height"].to!int]);
	container.add(button);
}


auto dirSorter(DirEntry a, DirEntry b){
	if(a.name.baseName.startsWith(".") != b.name.baseName.startsWith("."))
		return b.name.baseName.startsWith(".");
	if(a.isDir != b.isDir)
		return a.isDir;
	return a.name.baseName.toUpper < b.name.baseName.toUpper;
}



void loadAddDir(string directory, shared Queue!string queue){
	directory = (directory.chomp("/") ~ "/");
	try{
		DirEntry[] paths;
		foreach(DirEntry entry; directory.dirEntries(SpanMode.shallow))
			paths ~= entry;
		paths.sort!dirSorter;
		foreach_reverse(p; paths)
			queue.add(p.name);
	}catch(Exception e)
		e.writeln;
}

