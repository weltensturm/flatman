module menu.buttons;

import menu;


class ButtonExec: Button {

	string parameter;
	string type;

	this(){
		super("");
		font = "Consolas:size=11";
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		super.onMouseButton(button, pressed, x, y);
		if(button == Mouse.buttonLeft && !pressed){
			spawnCommand;
			menuWindow.onMouseFocus(false);
		}
	}

	string command(){assert(0);}

	string serialize(){assert(0);}

	void spawnCommand(){
		auto dg = {
			try{
				string command = (command.strip ~ ' ' ~ parameter).strip;
				writeln("running: \"%s\"".format(command));
				"context %s".format(context).writeln;
				if(context.isDir)
					chdir(context);
				auto pipes = pipeShell(command);
				auto pid = pipes.pid.processID;
				logExec("%s exec %s!%s!%s".format(pid, type, serialize.replace("!", "\\!"), parameter.replace("!", "\\!")));
				auto reader = task({
					foreach(line; pipes.stdout.byLine){
						if(line.length)
							log("%s stdout %s".format(pid, line));
					}
				});
				reader.executeInNewThread;
				foreach(line; pipes.stderr.byLine){
					if(line.length)
						log("%s stderr %s".format(pid, line));
				}
				reader.yieldForce;
				auto res = pipes.pid.wait;
				log("%s exit %s".format(pid, res));
			}catch(Throwable t)
				writeln(t);
		};
		task(dg).executeInNewThread;
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
		font = "Consolas:size=11";
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

	override string command(){
		if(parameter.length)
			parameter = "\"" ~ parameter ~ "\"";
		foreach(n; "uUfF")
			exec = exec.replace("%" ~ n, parameter);
		return exec;
	}

	override string serialize(){
		return [name, exec].bangJoin;
	}

}

class ButtonScript: ButtonExec {

	string exec;

	this(string data){
		exec = data;
		type = "script";
		font = "Consolas:size=11";
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

	override string command(){
		return "%s %s".format(exec.strip, parameter.strip).strip;
	}

	override string serialize(){
		return exec;
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
		file = data;
		type = "file";
		if(parentDir.length)
			parentDir ~= "/";
		this.parentDir = parentDir;
	}

	override void onDraw(){
		//draw.setColor([27/255.0,27/255.0,27/255.0,1]);
		//draw.rect(pos, size);
		draw.setFont(font, fontSize);
		if(mouseFocus || previewDrop){
			draw.setColor([0.2, 0.2, 0.2]);
			draw.rect(pos, size);
		}
		int x = 10+cast(int)parentDir.count("/")*20;
		auto text = file.chompPrefix(parentDir).split("/");
		if(file == ".")
			return;
		foreach(i, part; text){
			bool last = i == text.length-1;
			if(last && !isDir)
				draw.setColor([0.933,0.933,0.933]);
			else
				draw.setColor([0.733,0.933,0.733]);
			draw.text(pos.a + [x,0], size.h, part);
			x += draw.width(part);
			draw.setColor([0.6,0.6,0.6]);
			if(!last){
				draw.text(pos.a + [x,0], size.h, "/");
				x += draw.width("/");
			}
		}
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		Base.onMouseButton(button, pressed, x, y);
		if(isDir){
			if(dirExpanded || button != Mouse.buttonLeft || pressed)
				return;
			dirExpanded = true;
			chdir(context);
			ButtonFile[] buttons;
			foreach(entry; file.dirEntries(SpanMode.shallow)){
				auto name = entry.to!string.chompPrefix(context ~ "/");
				if(name.startsWith(".") || name.baseName.startsWith("."))
					continue;
				buttons ~= new ButtonFile(name, file);
			}
			buttons.sort!("a.file.toUpper < b.file.toUpper", SwapStrategy.stable);
			buttons.sort!("a.isDir && !b.isDir", SwapStrategy.stable);
			auto start = parent.children.countUntil(this);
			foreach(i, b; buttons){
				b.parent = parent;
				parent.children = parent.children[0..start+i+1] ~ b ~ parent.children[start+i+1..$];
			}
			parent.resize(parent.size);
		}else if(!dragGhost)
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


	override string command(){
		if(isDir)
			return "";
		return "exo-open \"%s\" || xdg-open \"%s\"".format(file.strip, file.strip).strip;
	}

	override string serialize(){
		return file;
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
