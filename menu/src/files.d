module menu.files;


import menu;


string[] contexts;


Tree addFiles(DynamicList list){
	auto buttonContexts = new RootButton("Files");
	buttonContexts.resize([5, config.buttonTab.height]);
	auto contexts = list.addNew!FileTree(buttonContexts, false);
	contexts.inset = 0;
	contexts.tail = 10;
	buttonContexts.set(contexts);
	contexts.expanded = true;
	contexts.padding = 0;

	buttonContexts.leftClick ~= {
		foreach(c; list.children){
			if(auto t = cast(Tree)c){
				if(t != contexts && t.expanded)
					t.toggle;
			}
		}
	};
	
	auto addContext = (string context){
		.contexts ~= context;
		auto tree = contexts.addDir(context, true);
		tree.tail = 10;
		//tree.expander.leftClick.unbind;
		tree.expander.leftClick ~= {
			setContext(tree.path);
		};
	};

	foreach(entry; "~/.flatman/".normalize.dirEntries(SpanMode.breadth))
		if(entry.name.endsWith(".context"))
			addContext(entry.readText);

	Inotify.watch("~/.flatman/".expandTilde, (path, file, action){
		if(action == Inotify.Add && file.endsWith(".context")){
			auto c = (path ~ "/" ~ file).readText.strip;
			addContext(c);
		}else if(action == Inotify.Remove && file.endsWith(".context")){
			foreach(directory; contexts.children[1..$].to!(DirectoryTree[])){
				auto button = directory.children[0].to!ButtonFile;
				if(button.file.replace("/", "-") ~ ".context" == file){
					contexts.remove(directory);
					return;
				}
			}
		}else if(action == Inotify.Modify && file == "current"){
			auto d = (path ~ "/" ~ file).readText.strip;
			auto c = d.readText.strip;
			foreach(directory; contexts.children[1..$].to!(DirectoryTree[])){
				auto button = directory.children[0].to!ButtonFile;
				button.isSelectedContext = c == button.file;
				if(button.isSelectedContext != directory.expanded)
					directory.toggle;
			}
		}
	});

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
	string context;
	string parentDir;
	bool isDir;
	int display;
	bool isSelectedContext;
	bool dirExpanded;

	bool previewDrop;

	Base dragGhost;
	int[2] dragOffset;
	Base dropWhere;

	enum:int {
		BaseName,
		FullPath,
		ContextPath
	}

	this(string data, bool isDir, int display=BaseName){
		this.isDir = isDir;
		this.display = display;
		//data = data.normalize;
		if(isDir){
			auto enter = new Button("→");
			enter.font = "Arial";
			enter.fontSize = 9;
			enter.style.bg.hover = [0.5,0.5,0.5,1];
			enter.leftClick ~= () => setContext(data);
			add(enter);
			//if(display == FullPath && context != .context)
			//	leftClick ~= () => setContext(data);
		}
		file = data;
		context = file.chompPrefix(.context ~ "/");
		exec = data;
		type = "file";
		if(parentDir.length)
			parentDir ~= "/";
		this.parentDir = parentDir;
		isSelectedContext = .context == file;
		rightClick ~= &openPopup;
	}

	override string name(){
		return
			display==BaseName ? file.baseName
			: display==FullPath ? file.nice
			: display==ContextPath ? context.nice : "";
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
		buttons ~= A("Open", { Context.current.openFile(file.normalize); });

		if(isDir){

			buttons ~= A("Expand", { parent.to!FileTree.toggle; });

			if(display != FullPath)
				buttons ~= A("Enter", { ["flatman-context", file].execute; });

			buttons ~= A("Add File", {
				if(menuWindow.keyboardFocus)
					menuWindow.keyboardFocus.parent.remove(menuWindow.keyboardFocus);
				auto input = new InputFieldFile("file");
				parent.children = parent.children[0..1] ~ input ~ parent.children[1..$];
				input.parent = parent;
				parent.keyboardChild = input;
				input.resize([5, config.buttonTree.height]);
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
				input.resize([5, config.buttonTree.height]);
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
		
			if(contexts.canFind(file.normalize)){
				buttons ~= A("Remove Bookmark", {
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
		
		}else{

			if(["file", "-i", file].execute.output.canFind(": image")){

				buttons ~= A("Set Wallpaper", {
					["feh", "--bg-fill", file].execute;
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
		drawStatus;
		if(previewDrop || hasMouseFocus){
			draw.setColor([0.2, 0.2, 0.2]);
			draw.rect(pos, size);
		}else{
			/+
			if(isDir && display == FullPath){
				draw.setColor([0.15,0.15,0.15]);
				draw.rect(pos.a+[1,0], size.a-[1,0]);
			}
			+/
		}
		super.onDraw;
		if(file == ".")
			return;
		draw.setFont(config.buttonTab.font, config.buttonTab.fontSize);
		if(display != BaseName){
			int advance = 10;
			auto parts = name.split("/");
			foreach(i, part; parts){
				draw.setColor(
						isSelectedContext ? [1,0.7,.2]
						: i == parts.length-1 && !isDir ? [0.9,0.9,0.9]
						: [0.733,0.933,0.733]);
				advance += draw.text([pos.x+advance, pos.y], size.h, part);
				if(isDir || i < parts.length-1){
					draw.setColor([0.7,0.7,0.7]);
					advance += draw.text([pos.x+advance, pos.y], size.h, "/");
				}
			}
		}else{
			draw.setColor(
				isDir ?
					(name.startsWith(".") ? [0.4,0.5,0.4] : [0.733,0.933,0.733])
					: (name.startsWith(".") ? [0.4,0.4,0.4] : [0.933,0.933,0.933])
			);
			draw.text(pos.a + [10,0], size.h, name);			
		}

		/+
		draw.setColor([0.6,0.6,0.6]);
		if(hasMouseFocus)
			foreach(c; children)
				c.onDraw;
		+/
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
		Context.current.openFile(file.normalize);
	}

	override string sortName(){
		return file;
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
		inset = 12;
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
		super.onDraw;

		/+
		if(expanded && drawHint){
			draw.setColor([0.2,0.2,0.2]);
			draw.rect(pos.a+[1,2], [2, size.h-4]);
		}
		+/
	}

}


class DirectoryTree: FileTree, Path {

	shared Queue!string queue;

	ButtonFile button;

	bool loaded;

	this(ButtonFile button){
		queue = new shared Queue!string;
		this.button = button;
		button.resize([5,config.buttonTab.height]);
		padding = 0;
		super(button);
		if(button.display == ButtonFile.FullPath && button.isSelectedContext)
			toggle;
	}

	override void toggle(){
		if(!loaded){
			task({ loadAddDir(button.file, queue); }).executeInNewThread;
			Inotify.watch(button.file, (path, file, action){
				if(action == Inotify.Add)
					add(path ~ "/" ~ file);
				else if(action == Inotify.Remove)
					remove(path ~ "/" ~ file);
			});
			loaded = true;
		}
		super.toggle;
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


auto addDir(FileTree container, string directory, bool isContext=false){
	auto tree = new DirectoryTree(new ButtonFile(directory, true, isContext));
	container.add(tree);
	tree.update;
	return tree;
}


void addFile(FileTree container, string path){
	auto button = new ButtonFile(path, false);
	button.resize([5, config.buttonTree.height]);
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

