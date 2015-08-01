module flatman.workspaceDock;

import flatman;

__gshared:


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
		wa.event_mask = ButtonPressMask|ExposureMask|PointerMotionMask|LeaveWindowMask|KeyReleaseMask;
		window = XCreateWindow(
			dpy, root, pos.x, pos.y, size.w, size.h,
			0, DefaultDepth(dpy, screen), CopyFromParent,
			DefaultVisual(dpy, screen),
			CWOverrideRedirect|CWBackPixmap|CWEventMask, &wa
		);
		XDefineCursor(dpy, window, cursor[CurNormal].cursor);
		XMapWindow(dpy, window);
		XMoveWindow(dpy, window, monitor.size.w-1, 0);
	}

	void update(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		XMoveWindow(dpy, window, monitor.size.w-1, pos.y);
	}

	void resize(int[2] size){
		update(pos, size);
	}

	void show(){
		XRaiseWindow(dpy, window);
		XMoveWindow(dpy, window, pos.x, pos.y);
		//XGrabKeyboard(dpy, root, true, GrabModeSync, GrabModeSync, CurrentTime);
		XGrabKey(dpy, XKeysymToKeycode(dpy, XK_Alt_L), 0, root, true, GrabModeAsync, GrabModeAsync);
	}

	void hide(){
		update(pos, size);
		//XUngrabKeyboard(dpy, CurrentTime);
		XUngrabKey(dpy, XKeysymToKeycode(dpy, XK_Alt_L), 0, root);
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
							auto workspace = monitor.workspace;
							//workspace.focus(cast(int)workspace.activeWindow-cast(int)wi);
							//log((cast(int)workspace.activeWindow-cast(int)wi).to!string);
						}
					}
				}
			}
		}else if(ev.button == Mouse.wheelDown){
			monitor.nextWs;
		}else if(ev.button == Mouse.wheelUp){
			monitor.prevWs;
		}
	}

	void onDraw(){
		draw.setColor("#"~config["dock background"]);
		draw.rect(0,0,size.w,size.h);
		int border = 5;
		foreach(i, ws; monitor.workspaces){
			auto x = border;
			auto w = size.w-border*2;
			auto scale = cast(double)w/monitor.size.w;
			auto h = cast(int)(size.h*scale).lround;
			auto y = cast(int)(i*(h+border)+border).lround;
			draw.setColor("#"~config["dock workspace background"]);
			draw.rect(x,y,w,h);
			foreach(wi, c; ws.clients){
				draw.setColor("#"~config["dock window background normal"]);
				auto wx = x+cast(int)(c.pos.x*scale/2+1).lround*2;
				auto wy = y+cast(int)(c.pos.y*scale/2-1).lround*2;
				auto ww = cast(int)(c.size.w*scale/2-0.5).lround*2;
				auto wh = cast(int)(c.size.h*scale/2-0.5).lround*2;
				draw.rect(wx, wy, ww, wh);
				if(c == ws.active){
					draw.setColor("#"~config["dock window background active"]);
					draw.rect(wx,wy,ww,wh);
				}else if(c.isUrgent){
					draw.setColor("#"~config["dock window background urgent"]);
					draw.rect(wx,wy,ww,wh);
				}
				draw.clip([wx,wy],[ww,wh]);
				draw.setColor("#"~config["dock window text"]);
				draw.text(c.name, [wx,wy]);
				draw.noclip;
			}
			draw.setColor("#"~config["dock workspace title"]);
			if(ws == monitor.workspace){
				draw.rectOutline([x,y],[w,h]);
			}
			draw.clip([x+bh/5,y+h-bh], [w-bh/5,bh]);
			try{
				auto name = ("~/.dinu/".expandTilde ~ i.to!string).readText;
				name = name.replace("~".expandTilde, "~");
				draw.text(name, [x+w, y+h-bh], 1.5);
			}catch{}
			draw.text(tags[i], [x+w,y+h-bh], 0.5);
			draw.noclip;
		}
		draw.map(window, 0, 0, size.w, size.h);
	}

}
