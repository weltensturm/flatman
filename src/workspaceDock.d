module flatman.workspaceDock;

import flatman;


class WorkspaceDock {

	Window window;
	flatman.Monitor monitor;

	int[2] pos;
	int[2] size;
	
	this(int[2] pos, int[2] size, flatman.Monitor monitor){
		this.pos = pos;
		this.size = size;
		this.monitor = monitor;
		XSetWindowAttributes wa;
		wa.override_redirect = true;
		wa.background_pixmap = ParentRelative;
		wa.event_mask = ButtonPressMask|ExposureMask|PointerMotionMask|LeaveWindowMask;
		window = XCreateWindow(
			dpy, root, pos.x, pos.y, size.w, size.h,
			0, DefaultDepth(dpy, screen), CopyFromParent,
			DefaultVisual(dpy, screen),
			CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa
		);
		XDefineCursor(dpy, window, cursor[CurNormal].cursor);
		//XMapRaised(dpy, window);
	}

	void update(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		XMoveResizeWindow(dpy, window, pos.x, pos.y, size.w, size.h);
	}

	void resize(int[2] size){
		update(pos, size);
	}

	void show(){
		XMapRaised(dpy, window);
		XGrabKey(dpy, XKeysymToKeycode(dpy, XK_Alt_L), AnyModifier, window, true, GrabModeAsync, GrabModeAsync);
	}

	void hide(){
		XUnmapWindow(dpy, window);
		XUngrabKey(dpy, XKeysymToKeycode(dpy, XK_Alt_L), AnyModifier, window);
	}

	void destroy(){
		XUnmapWindow(dpy, window);
		XDestroyWindow(dpy, window);
	}

	void onButton(XEvent* e){
		XButtonPressedEvent* ev = &e.xbutton;
		if(ev.button == Mouse.buttonLeft){
			auto border = 5;
			foreach(i, ws; monitor.workspaces){
				auto x = border;
				auto w = size.w-border*2;
				auto scale = cast(double)w/monitor.size.w;
				auto h = cast(int)(size.h*scale);
				auto y = cast(int)i*(h+border)+border;
				if(ev.x >= x && ev.x <= x+w && ev.y >= y && ev.y <= y+h){
					monitor.switchWorkspace(cast(int)i);
					foreach(wi, c; ws.clients){
						auto wx = x+(c.pos.x*scale).lround;
						auto wy = y+(c.pos.y*scale).lround;
						auto ww = (c.size.w*scale).lround-1;
						auto wh = (c.size.h*scale).lround-1;
						if(ev.x >= wx && ev.x <= x+ww && ev.y > wy && ev.y <= wy+wh){
							auto workspace = monitorActive.workspace;
							//workspace.focus(cast(int)workspace.activeWindow-cast(int)wi);
							//log((cast(int)workspace.activeWindow-cast(int)wi).to!string);
						}
					}
				}
			}
		}else if(ev.button == Mouse.wheelDown){
			monitorActive.nextWs;
		}else if(ev.button == Mouse.wheelUp){
			monitorActive.prevWs;
		}
	}

	void onDraw(){
		draw.setColor(normbgcolor);
		draw.rect(0,0,size.w,size.h);
		int border = 5;
		foreach(i, ws; monitor.workspaces){
			auto x = border;
			auto w = size.w-border*2;
			auto scale = cast(double)w/monitor.size.w;
			auto h = cast(int)(size.h*scale).lround;
			auto y = cast(int)(i*(h+border)+border).lround;
			draw.setColor("#262626");
			draw.rect(x,y,w,h);
			foreach(wi, c; ws.clients){
				draw.setColor("#444444");
				auto wx = x+cast(int)(c.pos.x*scale).lround;
				auto wy = y+cast(int)(c.pos.y*scale).lround;
				auto ww = cast(int)(c.size.w*scale).lround;
				auto wh = cast(int)(c.size.h*scale).lround;
				draw.rect(wx, wy, ww, wh);
				if(c == ws.active){
					draw.setColor(selbgcolor);
					draw.rect(wx,wy,ww,wh);
				}
				draw.clip([wx,wy],[ww,wh]);
				draw.setColor(selfgcolor);
				draw.text(c.name, [wx,wy]);
				draw.noclip;
			}
			if(ws == monitor.workspace){
				draw.setColor(normfgcolor);
				draw.rectOutline([x,y],[w,h]);
			}
			try{
				draw.setColor(normfgcolor);
				auto name = ("~/.dinu/".expandTilde ~ i.to!string).readText;
				name = name.replace("~".expandTilde, "~");
				draw.text(name, [x, y+h-bh]);
			}catch(Exception e){
			}
			draw.text(tags[i], [x+w,y+h-bh], 0.5);
		}
		draw.map(window, 0, 0, size.w, size.h);
	}

}