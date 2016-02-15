module menu.apps;


import menu;


void addApps(DynamicList list, DesktopEntry[][string] apps, string[string] categories){

	foreach(name; categories.values.sort!"a.toUpper < b.toUpper"){
		if(name !in apps)
			continue;
		auto buttonCategory = new RootButton(name);
		buttonCategory.resize([5,25]);
		auto tree = new Tree(buttonCategory);
		buttonCategory.set(tree);
		tree.expanded = false;
		list.add(tree);

		foreach(app; apps[name].sort!"a.name.toUpper < b.name.toUpper"){
			auto button = new ButtonDesktop([app.name, app.exec].bangJoin);
			button.resize([5,20]);
			tree.add(button);
		}

		tree.update;
	}
}


class ButtonExec: Button {

	string parameter;
	string type;
	double clickTime = 0;

	this(){
		super("");
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		super.onMouseButton(button, pressed, x, y);
		if(button == Mouse.buttonLeft && !pressed){
			clickTime = now;
			spawnCommand;
		}
	}

	void spawnCommand(){
		//menuWindow.onMouseFocus(false);
	}

	override void onDraw(){
		if(mouseFocus){
			auto mul = 1.2-(now-clickTime-0.2).min(0.2);
			draw.setColor([0.15*mul, 0.15*mul, 0.15*mul]);
			draw.rect(pos, size);
		}
	}

}


class ButtonDesktop: ButtonExec {

	string name;
	string exec;
	bool previewDrop;

	this(string data){
		auto split = data.bangSplit;
		name = split[0];
		exec = split[1];
		type = "desktop";
	}

	override void onDraw(){
		if(mouseFocus || previewDrop){
			auto mul = 1.2-(now-clickTime-0.2).min(0.2);
			draw.setColor([0.15*mul, 0.15*mul, 0.15*mul]);
			draw.rect(pos, size);
		}
		draw.setFont(config["button-tree", "font"], config["button-tree", "font-size"].to!int);
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
		auto x = exec;
		foreach(n; "uUfF")
			x = x.replace("%" ~ n, parameter);
		contextPath.execute(type, [name,exec].bangJoin.replace("!", "\\!"), x, parameter);
	}

	override Base dropTarget(int x, int y, Base draggable){
		if(cast(ButtonFileGhost)draggable && ["%u","%U","%f","%F"].any!(a => exec.canFind(a)))
			return this;
		return super.dropTarget(x, y, draggable);
	}

	override void dropPreview(int x, int y, Base draggable, bool start){
		previewDrop = start;
	}

	override void drop(int x, int y, Base draggable){
		root.remove(draggable);
		auto button = cast(ButtonFileGhost)draggable;
		parameter = button.source.file;
		spawnCommand;
		previewDrop = false;
	}

}


class ButtonScript: ButtonExec {

	string exec;

	this(string data){
		exec = data;
		type = "script";
	}

	override void onDraw(){
		draw.setFont(config["button-tree", "font"], config["button-tree", "font-size"].to!int);
		super.onDraw;
		draw.setColor([187/255.0,187/255.0,255/255.0]);
		draw.text(pos.a+[10,0], size.h, exec);
		draw.setColor([0.6,0.6,0.6]);
		draw.text(pos.a + [draw.width(exec)+15,0], size.h, parameter);
	}

	override void spawnCommand(){
		contextPath.execute(type, exec.replace("!", "\\!"), exec, parameter.replace("!", "\\!"));
	}

}
