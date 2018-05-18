module dock.workspaceView;

import dock;

__gshared:


class WorkspaceView: Base {

	long id;
	WorkspaceDock dock;
	string name = "~";
	bool preview;
	bool empty;
	bool combined;
	ubyte[3] color;

	this(WorkspaceDock dock, long id, bool empty){
		this.dock = dock;
		this.id = id/2;
		this.empty = empty;
	}

	override void resize(int[2] size){
		super.resize(size);
	}

	void update(){
		foreach(c; children)
			remove(c);
		auto scale = (size.w-6) / cast(double)dock.rootSize.w;
		if(id in dock.workspaces && !empty)
			foreach_reverse(w; dock.workspaces[id]){
				auto wv = addNew!WindowView(w, cast(int)id);
				auto y = w.pos.y;
				auto sh = dock.rootSize.y;
				while(y > sh)
					y -= sh;
				while(y < 0)
					y += sh;
				wv.moveLocal([
					3+cast(int)((w.pos.x)*scale).lround,
					3+cast(int)((dock.rootSize.h-y-(w.size.h))*scale).lround
				]);
				wv.resize([
					cast(int)(w.size.w*scale).lround,
					cast(int)(w.size.h*scale).lround
				]);
			}
	}

	override Base dropTarget(int x, int y, Base draggable){
		if(typeid(draggable) is typeid(Ghost))
			return this;
		return super.dropTarget(x, y, draggable);
	}

	override void dropPreview(int x, int y, Base draggable, bool start){
		preview = start;
	}

	override void drop(int x, int y, Base draggable){
		auto ghost = cast(Ghost)draggable;
		if(ghost.window.workspaceProperty.get != id){
			writeln("requesting window move to ", id);
			new Property!(XA_CARDINAL, false)(ghost.window.windowHandle, "_NET_WM_DESKTOP").request([id, 2, empty ? 1 : 0]);
		}
		preview = false;
	}

	override void onMouseFocus(bool focus){
		preview = focus;
	}

	override void onDraw(){
		draw.clip(pos, size);
		/+
		if(id == dock.workspace && !empty)
			draw.setColor([0.867,0.514,0]);
		else if(preview)
			draw.setColor([1,1,1]);
		//else
		//	draw.setColor([color[0]/400.0, color[1]/400.0, color[2]/400.0]);

		if(id == dock.workspace && !empty || empty && preview)
			dock.draw.rect(pos, size);
		else if(!empty){
			draw.setColor([0.4,0.4,0.4]);
			dock.draw.rect(pos.a+[1,1], [size.w-2, size.h.max(2)-2]);
		}
		+/

		if(!empty)
			composite.render(dockWindow.root_picture, pos.a+[3,3], size.a-[6,6], (size.w-6)/cast(double)dock.rootSize.w);
		else if(preview){
			draw.setColor([1,1,1,0.5]);
			draw.rect(pos.a+[0,size.h/2], [size.w, 1]);
		}

		super.onDraw;

		if(empty && !combined && !preview){
			//composite.rect([pos.x+3, pos.y+3], [size.w-6, draw.fontHeight], [0,0,0,0.85]);
			int x = size.w/2 - dock.draw.width(name)/2;
			draw.setColor([0.7,0.7,0.7]);
			foreach(part; name.split("/")[0..$-1]){
				dock.draw.text(pos.a+[x,2], part ~ "/");
				x += dock.draw.width(part ~ "/");
			}
			draw.setColor([1,1,1]);
			dock.draw.text(pos.a+[x,2], name.split("/")[$-1]);
			//dock.draw.text(pos.a+[size.w/2,3], name, 0.5);
			//draw.setColor([color[0]/255.0, color[1]/255.0, color[2]/255.0]);
			//draw.rect(pos.a+[6,6], [4,draw.fontHeight]);
		}
		
		if(id != dock.workspace && !empty){
			draw.setColor([0,0,0,0.3]);
			draw.rect(pos, size);
		}
		
		draw.noclip;
	}

	override void onMouseButton(Mouse.button button, bool pressed, int x, int y){
		if(button == Mouse.buttonLeft && !pressed && !draggingChild){
			dock.workspaceProperty.request([id, CurrentTime, empty ? 1 : 0]);
		}
		super.onMouseButton(button, pressed, x, y);
	}

}

