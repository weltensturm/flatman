module bar.switcher;


import bar;

/+
class Switcher: ws.wm.Window {

	Bar bar;

	this(Bar bar){
		this.bar = bar;
		super(1, 1, "flatman bar switcher");
		move([bar.size.w/6, 0]);

		auto workspace = new Property!(XA_CARDINAL, false)(windowHandle, "_NET_WM_DESKTOP");
		workspace = -1;
		wm.add(this);
	}

	override void drawInit(){
		_draw = new XDraw(this);
		_draw.setFont("Ubuntu", 10);
	}

	override void onMouseFocus(bool focus){
		writeln(focus);
		super.onMouseFocus(focus);
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(pressed)
			hide;
	}

	override void onShow(){
		int g=XGrabPointer(
				wm.displayHandle,
				windowHandle,
				false,
				ButtonPressMask |
						ButtonReleaseMask |
						PointerMotionMask |
						FocusChangeMask |
						EnterWindowMask |
						LeaveWindowMask,
				GrabModeAsync,
				GrabModeAsync,
				None,
				None,
				CurrentTime);
		writeln("grabbing pointer");
		super.onShow;
	}

	override void onHide(){
		XUngrabPointer(wm.displayHandle, CurrentTime);
		super.onHide;
	}

	override void onDraw(){
		int width;
		int height; 
		Client[] clients;
		foreach(client; bar.clients){
			if(client.workspace == bar.currentWorkspace && client.title.length){
				height += 24;
				auto w = 24*2 + draw.width(client.title);
				if(w > width)
					width = w;
				clients ~= client;
			}
		}
		if(height != size.h || width != size.w){
			resize([width, height]);
		}

		draw.setColor([0.2,0.2,0.2]);
		draw.rect([0,0], size);

		int offset = 0;
		foreach(client; clients){
			draw.setColor([0.3,0.3,0.3]);
			auto txt = client.title;

			if(client == bar.currentClient){
				draw.setColor([0.85,0.85,0.85]);
				draw.rect(pos.a + [0, offset], [size.w, 24]);
				draw.setColor([0.1,0.1,0.1]);
			}

			if(client.icon.length){


				auto scale = (20.0)/client.iconSize.h;
				auto iconWidth = client.iconSize.w*scale;
				
				draw.text([5+iconWidth.to!int-5, offset+5], txt);

				if(!client.xicon){
					client.xicon = draw.to!XDraw.icon(client.icon, client.iconSize.to!(int[2]));
				}
				draw.to!XDraw.icon(client.xicon, 5+5, size.h-offset-22, scale);
			}else if(txt.length){
				draw.text([5, offset+5], txt);
			}else{
				draw.text([5, offset+5], client.window.to!string);
			}
			offset += 24;
		}
		draw.finishFrame;
	}

}

+/