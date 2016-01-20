module menu.files;


import menu;


string[] contexts;


class ListFiles: Scroller {

	DynamicList list;

	this(){
		list = addNew!DynamicList;
		list.padding = 5;
		list.style.bg = [0.1,0.1,0.1,1];

		auto buttonContexts = new RootButton("Files");
		buttonContexts.resize([5,25]);
		auto contexts = list.addNew!Tree(buttonContexts);
		contexts.expanded = true;
		contexts.padding = 0;
		auto changeContext = (string p, string f){
			if(!f.endsWith(".context") && !f.endsWith("current"))
				return;
			foreach(c; contexts.children){
				if(c != buttonContexts)
					contexts.remove(c);
			}
			.contexts = [];
			foreach(entry; "~/.flatman/".normalize.dirEntries(SpanMode.breadth)){
				if(entry.name.endsWith(".context")){
					auto c = entry.name.normalize.readText;
					.contexts ~= c;
				}
			}
			foreach(context; .contexts.sort!"a.toUpper < b.toUpper")
				contexts.addDir(context, context);
		};
		changeContext("", ".context");
		auto watcher = menuWindow.inotify.addWatch("~/.flatman/".normalize, false);
		watcher.add ~= changeContext;
		watcher.change ~= changeContext;
		watcher.remove ~= changeContext;
	}

	override void onDraw(){
		draw.setColor([0.1,0.1,0.1]);
		draw.rect(pos, size);
		super.onDraw;
		draw.setColor([0.3,0.3,0.3]);
		draw.rect(pos.a+[0,size.h-2], [size.w, 2]);
	}

}


class Directory: Tree {

	string directory;
	string root;
	Inotify.WatchStruct* watcher;

	this(ButtonFile button, string directory, string root){
		button.resize([5,20]);
		padding = 0;
		super(button);
		bool once;
		button.leftClick ~= {
			if(!once){
				loadAddDir(directory, this, root);
				watcher = menuWindow.inotify.addWatch(directory, false);
				watcher.add ~= (p, f) => add(p ~ '/' ~ f);
				watcher.remove ~= (p, f) => remove(p ~ '/' ~ f);
			}
			once = true;
		};
		if(button.isContext && button.isSelectedContext)
			button.leftClick();
	}

	void add(string file){
		auto path = directory ~ '/' ~ file;
		if(!path.exists)
			return;
		if(path.isDir)
			addDir(this, path, root);
		else
			addFile(this, path);
	}

	void remove(string file){
		foreach(c; children){
			if(c != expander && typeid(c) == typeid(ButtonFile) && c.to!ButtonFile.file == directory ~ '/' ~ file){
				super.remove(c);
				return;
			}
		}
	}

}


class RootButton: Button {

	string name;

	this(string name, Button[] buttons = []){
		super("");
		this.name = name;
		foreach(b; buttons){
			b.style.bg = style.bg.hover;
			add(b);
		}
	}

	override void resize(int[2] size){
		super.resize(size);
		foreach(i, c; children){
			c.move(pos.a + [size.w - 2 - size.h*i.to!int, 2]);
			c.resize([size.h-4,size.h-4]);
		}
	}

	override void onDraw(){
		if(hasMouseFocus)
			super.onDraw;
		draw.setFont("Arial", 10);
		draw.setColor([0.9,0.9,0.9]);
		draw.text(pos, size.h, name);
	}

}


class ButtonFile: ButtonExec {

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

	this(string data, string parentDir=""){
		//chdir(context);
		try
			isDir = data.exists && data.isDir;
		catch{}
		if(isDir){
			isContext = data.normalize == parentDir.normalize;
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

		rightClick ~= {
			Button[] test;

			auto b = new Button("Open");
			b.font = "Arial";
			b.fontSize = 9;
			b.style.bg.hover = [0.5,0.5,0.5,1];
			b.leftClick ~= {
				openFile(file.normalize);
			};
			test ~= b;

			if(isDir){
				if(contexts.canFind(file.normalize)){
					b = new Button("Remove Context");
					b.font = "Arial";
					b.fontSize = 9;
					b.style.bg.hover = [0.5,0.5,0.5,1];
					test ~= b;
					b.leftClick ~= {
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
					};
				}else{
					b = new Button("Add Context");
					b.font = "Arial";
					b.fontSize = 9;
					b.style.bg.hover = [0.5,0.5,0.5,1];
					test ~= b;
					b.leftClick ~= {
						["flatman-context", file].execute;
					};
				}
				
			}

			b = new Button("Delete");
			b.font = "Arial";
			b.fontSize = 9;
			b.style.bg.hover = [0.5,0.5,0.5,1];
			test ~= b;

			auto popup = new ListPopup(test);
			menuWindow.popups ~= popup;
			wm.add(popup);
		};
	}

	override void resize(int[2] size){
		super.resize(size);
		foreach(i, c; children){
			c.move(pos.a + [size.w - 2 - size.h*i.to!int, 2]);
			c.resize([size.h-4,size.h-4]);
		}
	}

	override void onDraw(){
		draw.setFont(font, fontSize);
		if(mouseFocus || previewDrop){
			draw.setColor([0.2, 0.2, 0.2]);
			draw.rect(pos, size);
		}
		int x = 10;
		if(file == ".")
			return;
		auto text = isContext ? file.nice : file.baseName;
		if(isDir){
			if(text.startsWith("."))
				draw.setColor([0.4,0.5,0.4]);
			else if(isContext && isSelectedContext)
				draw.setColor([1,0.7,.2]);
			else
				draw.setColor([0.733,0.933,0.733]);
		}else{
			if(text.startsWith("."))
				draw.setColor([0.4,0.4,0.4]);
			else
				draw.setColor([0.933,0.933,0.933]);
		}
		draw.text(pos.a + [x,0], size.h, text);
		x += draw.width(text);
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
		//dragOffset = offset;
		return new ButtonFileGhost(this);
	}


	override Base dropTarget(int x, int y, Base draggable){
		if(isDir && typeid(draggable) is typeid(ButtonFileGhost))
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
		openFile(file.normalize);
	}

}


class ButtonFileGhost: Base {

	ButtonFile source;

	this(ButtonFile source){
		this.source = source;
	}

	override void onDraw(){
		draw.setColor([0.8,0.8,0.8]);
		draw.text(pos, source.file);
	}

}


void sortDir(ref string[] dirs){
	dirs.sort!("a.toUpper < b.toUpper", SwapStrategy.stable);
	dirs.sort!("!a.startsWith(\".\") && b.startsWith(\".\")", SwapStrategy.stable);
}


void addDir(Base container, string directory, string root){
	auto tree = new Directory(new ButtonFile(directory, root), directory, root);
	container.add(tree);
	tree.update;
}


void addFile(Base container, string path){
	auto button = new ButtonFile(path);
	button.resize([5,20]);
	container.add(button);
}


void loadAddDir(string directory, Base container, string root){
	string[] dirs;
	string[] dirsHidden;
	string[] files;
	string[] filesHidden;
	directory = (directory.chomp("/") ~ "/");
	root = (root.chomp("/") ~ "/");
	try{
		foreach(DirEntry entry; directory.dirEntries(SpanMode.shallow)){
			auto name = entry.name.chompPrefix(directory);
			if(entry.isDir){
				if(!name.startsWith("."))
					dirs ~= name;
				else
					dirsHidden ~= name;
			}else{
				if(!name.startsWith("."))
					files ~= name;
				else
					filesHidden ~= name;
			}
		}
	}catch(Exception e){
		e.writeln;
	}
	dirs.sortDir;
	dirsHidden.sortDir;
	files.sortDir;
	filesHidden.sortDir;
	dirs.each!(a => container.addDir(directory ~ a, root));
	files.each!(a => container.addFile(directory ~ a));
	dirsHidden.each!(a => container.addDir(directory ~ a, root));
	filesHidden.each!(a => container.addFile(directory ~ a));
}

