module menu.buttons;


import menu;


class ButtonExec: Button {

	string parameter;
	string type;

	this(){
		super("");
		font = "Arial";
		fontSize = 9;
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
		auto x = exec;
		foreach(n; "uUfF")
			x = x.replace("%" ~ n, parameter);
		execute(x, "desktop", parameter, [name,exec].bangJoin);
	}

}


class ButtonScript: ButtonExec {

	string exec;

	this(string data){
		exec = data;
		type = "script";
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
