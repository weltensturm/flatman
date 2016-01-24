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
	Type type;

	this(){
		super("");
		font = "Consolas";
		fontSize = 10;
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

	override void onDraw(){
		if(mouseFocus){
			draw.setColor([0.15, 0.15, 0.15]);
			draw.rect(pos, size);
		}
	}

}


class ButtonDesktop: ButtonExec {

	string name;
	string exec;

	this(string data){
		auto split = data.bangSplit;
		name = split[0];
		exec = split[1];
		type = Type.desktop;
	}

	override void onDraw(){
		super.onDraw;
		draw.setFont(font, fontSize);
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
		execute(type, [name,exec].bangJoin.replace("!", "\\!"), x, parameter);
	}

}


class ButtonScript: ButtonExec {

	string exec;

	this(string data){
		exec = data;
		type = Type.script;
	}

	override void onDraw(){
		draw.setFont(font, fontSize);
		super.onDraw;
		draw.setColor([187/255.0,187/255.0,255/255.0]);
		draw.text(pos.a+[10,0], size.h, exec);
		draw.setColor([0.6,0.6,0.6]);
		draw.text(pos.a + [draw.width(exec)+15,0], size.h, parameter);
	}

	override void spawnCommand(){
		execute(type, exec.replace("!", "\\!"), exec, parameter.replace("!", "\\!"));
	}

}
