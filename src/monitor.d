module flatman.monitor;

import flatman;

class Monitor {

	int[2] pos;
	int[2] size;
	Bar bar;
	WorkspaceDock dock;

	Workspace[] workspaces;
	int workspaceActive;

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		foreach(t; tags){
			//split ~= new Split([pos.x, pos.y+bh], [size[0], size[1]-bh]);
			//floating ~= new Floating([pos.x, pos.y+bh], [size[0], size[1]-bh]);
			workspaces ~= new Workspace([pos.x, pos.y+bh], [size.w, size.h-bh]);
		}
		bar = new Bar(pos, [size.w,bh], this);
		dock = new WorkspaceDock([pos.x,pos.y+bh], [size[0]/cast(int)tags.length, size[1]-bh], this);
	}

	Client active(){
		return workspace.active;
	}

	Workspace workspace(){
		return workspaces[workspaceActive];
	}

	void switchWorkspace(int pos){
		workspace.deactivate;
		workspaceActive = pos;
		if(monitorActive.workspaceActive < 0)
			workspaceActive = cast(int)workspaces.length-1;
		if(monitorActive.workspaceActive == workspaces.length)
			workspaceActive = 0;
		workspace.activate;
		dock.show;
		draw;
	}
	
	void nextWs(){
		switchWorkspace(workspaceActive+1);
	}
	
	void prevWs(){
		switchWorkspace(workspaceActive-1);
	}
	
	void moveDown(){
		auto win = active;
		if(win){
			remove(win);
			if(workspaceActive == workspaces.length-1)
				workspaces[0].add(win);
			else
				workspaces[workspaceActive+1].add(win);
		}
		switchWorkspace(workspaceActive+1);
		win.focus;
	}
	
	void moveUp(){
		auto win = active;
		if(win){
			remove(win);
			if(workspaceActive == 0)
				workspaces[workspaces.length-1].add(win);
			else
				workspaces[workspaceActive-1].add(win);
		}
		switchWorkspace(workspaceActive-1);
		win.focus;
	}

	void add(Client client){
		workspace.add(client);
	}

	void move(Client client, int workspace){
		this.workspace.remove(client);
		workspaces[workspace].add(client);
	}

	void remove(Client client){
		foreach(ws; workspaces)
			ws.remove(client);
	}


	void draw(){
		workspace.onDraw;
		dock.onDraw;
		bar.onDraw;
	}

	Client[] allClients(){
		Client[] res;
		foreach(ws; workspaces)
			res ~= ws.clients;
		return res;
	}

	void resize(int[2] size){
		this.size = size;
		foreach(ws; workspaces)
			ws.resize([size.w, size.h-bh]);
		dock.resize([size.w/cast(int)tags.length, size.h-bh]);
	}

}

void cleanup(Monitor mon){
	monitors = monitors.without(mon);
}

void restack(Monitor m){
	m.draw;
	XSync(dpy, false);
	XEvent ev;
	while(XCheckMaskEvent(dpy, EnterWindowMask, &ev)){}
}
