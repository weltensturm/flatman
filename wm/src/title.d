module flatman.title;


import flatman;


class Title: Base {
	
	Client client;
	bool showTabs = true;
	bool mousePressed;
	bool mouseFocus;
	Picture glow;
	Tabs container;

	this(Client client, Tabs container, Picture glow){
		this.client = client;
		this.container = container;
		this.glow = glow;
	}
	
	override void onMouseFocus(bool focus){
		mouseFocus = focus;
		super.onMouseFocus(focus);
	}

	override void onMouseMove(int x, int y){
		if(mousePressed){
			mousePressed = false;
			.drag(client, [-client.size.w/2, cfg.tabsTitleHeight/2]);
		}
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.buttonLeft){
			if(!pressed && mousePressed)
				client.focus;
			mousePressed = pressed;
		}else if(button == Mouse.buttonMiddle){
			killclient(client);
		}else if(button == Mouse.wheelDown)
			sizeDec;
		else if(button == Mouse.wheelUp)
			sizeInc;
	}

	override void onDraw(){
		auto hover = mouseFocus;
		auto state = (
				client.isUrgent ? "urgent"
				: client.isfullscreen ? "fullscreen"
				: flatman.active == client ? "active"
				: hover ? "hover"
				: !container.containerFocused && client == active ? "activeBg"
				: "normal");
		draw.clip(pos, size);

		if(showTabs){

			if(container.containerFocused && (state == "active" || state == "fullscreen" || state == "activeBg")){

				XRenderComposite(
					dpy,
					PictOpOver,
					glow,
					None,
					draw.to!XDraw.frontBuffer,
					0,
					5,
					0,20,
					pos.x+size.w/2-100,
					0,
					200,
					40
				);
			}

			auto textOffset = pos.x + (size.w/2 - draw.width(client.name)/2).max(size.h);
			/+
			draw.setColor([0.1,0.1,0.1]);
			foreach(x; [-1,0,1])
				foreach(y; [-1,0,1])
					draw.text([x+textOffset, y], size.h, client.name);
			+/
			auto colors = [
				"urgent": cfg.tabsTitleUrgent,
				"fullscreen": cfg.tabsTitleFullscreen,
				"active": cfg.tabsTitleActive,
				"hover": cfg.tabsTitleHover,
				"activeBg": cfg.tabsTitleNormal,
				"normal": cfg.tabsTitleNormal
			];
			draw.setColor(cfg.tabsBackgroundHover);
			draw.rect(pos, [size.w, 1]);
			draw.setColor(colors[state]);
			draw.text([textOffset, 0], size.h, client.name);
			draw.setColor([0.3, 0.3, 0.3]);

			if(hover){
				draw.setColor([0.2,0.2,0.2]);
				draw.rect(pos.a+[size.w-size.h/2-size.h/4-4, size.h/4-4], [size.h/2+8, size.h/2+8]);
				draw.setColor([0.5,0.5,0.5]);
				cross(pos.a+[size.w-size.h/2, size.h/2], 5);
				cross(pos.a+[size.w-size.h/2, size.h/2+1], 5);
			}

			if(client.icon.length){
				if(!client.xicon){
					client.xicon = draw.to!XDraw.icon(client.icon, client.iconSize.to!(int[2]));
				}
				auto scale = (size.h-4.0)/client.iconSize.h;
				draw.to!XDraw.icon(client.xicon, (textOffset-client.iconSize.w*scale).lround.to!int, 2, scale);
			}
		}
		draw.noclip;
	}

	void cross(int[2] pos, int size){
		draw.line(pos.a+[size+1, size+1], pos.a+[-size, -size]);
		draw.line(pos.a+[-size, size], pos.a+[size+1, -size-1]);
	}

	
}