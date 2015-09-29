module menu.buttons;

import menu;


class ButtonExec: Button {

	string parameter;
	string type;

	this(){
		super("");
		font = "Consolas:size=9";
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		super.onMouseButton(button, pressed, x, y);
		if(button == Mouse.buttonLeft && !pressed){
			spawnCommand;
		}
	}

	void spawnCommand(){
		menuWindow.onMouseFocus(false);
	}

}

class ButtonDesktop: ButtonExec {

	string name;
	string exec;

	this(string data){
		auto split = data.bangSplit;
		name = split[0];
		exec = split[1];
		type = "desktop";
		font = "Consolas:size=9";
	}

	override void onDraw(){
		draw.setFont(font, fontSize);
		//draw.setColor([27/255.0,27/255.0,27/255.0,1]);
		//draw.rect(pos, size);
		if(mouseFocus){
			draw.setColor([0.2, 0.2, 0.2]);
			draw.rect(pos, size);
		}
		draw.setColor([189/255.0, 221/255.0, 255/255.0]);
		draw.text(pos.a+[10,0], size.h, name);
		auto textw = draw.width(name) + draw.fontHeight*2;
		draw.clip(pos.a + [textw,0], size.a - [textw,0]);
		draw.setColor([0.3,0.3,0.3]);
		draw.text(pos.a + [size.w,0], size.h, exec, 2);
		draw.noclip;
	}

	override void spawnCommand(){
		if(parameter.length)
			parameter = "\"" ~ parameter ~ "\"";
		foreach(n; "uUfF")
			exec = exec.replace("%" ~ n, parameter);
		execute(exec, "desktop", parameter, [name,exec].bangJoin);
	}

}

class ButtonScript: ButtonExec {

	string exec;

	this(string data){
		exec = data;
		type = "script";
		font = "Consolas:size=9";
	}

	override void onDraw(){
		draw.setFont(font, fontSize);
		//draw.setColor([27/255.0,27/255.0,27/255.0,1]);
		//draw.rect(pos, size);
		if(mouseFocus){
			draw.setColor([0.2, 0.2, 0.2]);
			draw.rect(pos, size);
		}
		draw.setColor([187/255.0,187/255.0,255/255.0]);
		draw.text(pos.a+[10,0], size.h, exec);
		draw.setColor([0.6,0.6,0.6]);
		draw.text(pos.a + [draw.width(exec)+15,0], size.h, parameter);
	}

	override void spawnCommand(){
		execute(exec, parameter);
	}

}


class ButtonFile: ButtonExec {

	string file;
	string parentDir;
	bool isDir;
	bool dirExpanded;

	bool previewDrop;

	Base dragGhost;
	int[2] dragOffset;
	Base dropWhere;

	this(string data, string parentDir=""){
		chdir(context);
		try
			isDir = data.exists && data.isDir;
		catch{}
		if(isDir){
			auto enter = new Button("→");
			enter.font = "Consolas:size=9";
			enter.style.bg.hover = [0.5,0.5,0.5,1];
			enter.leftClick ~= {
				setContext(data);
				menuWindow.onMouseFocus(false);
				menuWindow.onMouseFocus(true);
			};
			add(enter);
		}
		file = data;
		type = "file";
		if(parentDir.length)
			parentDir ~= "/";
		this.parentDir = parentDir;
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
		int x = 10+cast(int)parentDir.count("/")*20;
		if(file == ".")
			return;
		auto text = file.baseName;
		if(isDir){
			if(text.startsWith("."))
				draw.setColor([0.4,0.5,0.4]);
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
		auto res = "mv '%s' '%s'".format(button.source.file, file).executeShell;
		if(res.status){
			res.output.writeln;
		}else{
			menuWindow.onMouseFocus(false);
			menuWindow.onMouseFocus(true);
		}
		previewDrop = false;
	}


	override void spawnCommand(){
		if(isDir)
			return;
		openFile(file.buildNormalizedPath);
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
