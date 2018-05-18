module menu.apps;


import menu;


void addApps(DynamicList list, DesktopEntry[][string] apps, string[string] categories){

	categories.values.sort!"a.toUpper < b.toUpper".each!((string name){
		if(name !in apps)
			return;
		auto buttonCategory = new RootButton(name);
		buttonCategory.resize([5,25]);
		buttonCategory.rightClick ~= {
			alias A = ListPopup.Action;
			A[] buttons;
			buttons ~= A("Add", {
			});
		};
		auto tree = new Tree(buttonCategory);
		buttonCategory.set(tree);
		tree.expanded = true;
		list.add(tree);

		/+
		buttonCategory.leftClick ~= {
			foreach(c; list.children){
				if(auto t = cast(Tree)c){
					if(t != tree && t.expanded)
						t.toggle;
				}
			}
		};
		+/
	
		foreach(app; apps[name].sort!"a.name.toUpper < b.name.toUpper"){
			auto button = new ButtonDesktop([app.name, app.exec].bangJoin);
			button.resize([5,20]);
			tree.add(button);
		}

		tree.update;
	});
}


class ButtonExec: Button {

	string exec;
	string parameter;
	string type;
	double clickTime = 0;
	int status = int.max;
	int pid;

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

	void drawStatus(){
		if(pid != 0 && status != 0){
			if(status == int.max)
				draw.setColor([0.15,0.15,0.15]);
			else
				draw.setColor([0.15,0.1,0.1]);
			draw.rect(pos, size);
		}
	}

	string sortName(){
		return exec ~ " " ~ parameter;
	}

}


DesktopEntry findApp(string command){
	auto all = getAll;
	foreach(entry; all){
		if(entry.exec == command)
			return entry;
	}
	return null;
}


class ButtonDesktop: ButtonExec {

	string name;
	bool previewDrop;

	this(string data){
		auto split = data.bangSplit;
		name = split[0];
		exec = split[1];
		type = "desktop";
		rightClick ~= &openPopup;
	}

	override void onDraw(){
		drawStatus;
		if(mouseFocus || previewDrop){
			auto mul = 1.2-(now-clickTime-0.2).min(0.2);
			draw.setColor([0.15*mul, 0.15*mul, 0.15*mul]);
			draw.rect(pos, size);
		}
		draw.setFont(config.buttonTree.font, config.buttonTree.fontSize);
		draw.setColor([189/255.0, 221/255.0, 255/255.0]);
		draw.text(pos.a+[10,0], size.h, name);
		auto textw = draw.width(name) + draw.fontHeight*2;
		draw.clip(pos.a + [textw,0], size.a - [textw,0]);
		draw.setColor([0.3,0.3,0.3]);
		draw.text(pos.a + [size.w,0], size.h, exec, 2);
		draw.noclip;
	}

	void openPopup(){
		alias A = ListPopup.Action;
		A[] buttons;
		buttons ~= A("Edit", {
			auto app = findApp(exec);
			if(app){
				["subl3", "-n", app.path].execute;
			}
		});

		buttons ~= A("Trash", {  });
		auto popup = new ListPopup(buttons);
		menuWindow.popups ~= popup;
		wm.add(popup);
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

	override string sortName(){
		return name ~ " " ~ super.sortName;
	}

}


class ButtonScript: ButtonExec {

	this(string data){
		exec = data;
		type = "script";
	}

	override void onDraw(){
		drawStatus;
		draw.setFont(config.buttonTree.font, config.buttonTree.fontSize);
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
