module flatman.monitor;

import flatman;

__gshared:


class Monitor {

	int[2] pos;
	int[2] size;
	long[4] reserve;
	Bar bar;
	WorkspaceDock dock;

	Workspace[] workspaces;
	Client[] globals;

	int workspaceActive;

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		foreach(t; tags){
			workspaces ~= new Workspace(pos, size);
		}
		auto dockWidth = cast(int)(size[0]/cast(double)tags.length).lround;
		dock = new WorkspaceDock(pos.a+[size.w-dockWidth,0], [dockWidth, size.h], this);
	}

	Client active(){
		return workspace.active;
	}

	Workspace workspace(){
		return workspaces[workspaceActive];
	}

	void switchWorkspace(int pos){
		if(pos == workspaceActive)
			return;
		workspace.hide;
		workspaceActive = pos;
		if(monitorActive.workspaceActive < 0)
			workspaceActive = cast(int)workspaces.length-1;
		if(monitorActive.workspaceActive == workspaces.length)
			workspaceActive = 0;
		workspace.show;
		draw;
		updateCurrentDesktop;
		updateDesktopNames;
	}
	
	void nextWs(){
		switchWorkspace(workspaceActive+1);
		dock.show;
	}
	
	void prevWs(){
		switchWorkspace(workspaceActive-1);
		dock.show;
	}
	
	void moveDown(){
		auto win = active;
		if(win){
			remove(win);
			if(workspaceActive == workspaces.length-1)
				workspaces[0].addClient(win);
			else
				workspaces[workspaceActive+1].addClient(win);
		}
		switchWorkspace(workspaceActive+1);
		win.focus;
	}
	
	void moveUp(){
		auto win = active;
		if(win){
			remove(win);
			if(workspaceActive == 0)
				workspaces[workspaces.length-1].addClient(win);
			else
				workspaces[workspaceActive-1].addClient(win);
		}
		switchWorkspace(workspaceActive-1);
		win.focus;
	}

	void addGlobal(Client client){
		globals ~= client;
	}

	void add(Client client){
		workspace.addClient(client);
	}

	void move(Client client, int workspace){
		this.workspace.remove(client);
		workspaces[workspace].addClient(client);
	}

	void remove(Client client){
		foreach(ws; workspaces)
			ws.remove(client);
		globals = globals.without(client);
	}


	void draw(){
		workspace.onDraw;
		dock.onDraw;
	}

	void destroy(){
		dock.destroy;
		foreach(ws; workspaces)
			ws.destroy;
	}

	Client[] allClients(){
		Client[] res;
		foreach(ws; workspaces)
			res ~= ws.clients;
		return res ~ globals;
	}

	void resize(int[2] size){
		this.size = size;
		foreach(ws; workspaces){
			ws.move([cast(int)reserve[0], cast(int)reserve[2]]);
			ws.resize([cast(int)(size.w-reserve[1]-reserve[0]), cast(int)(size.h-reserve[2]-reserve[3])]);
		}
		auto dockWidth = cast(int)(size.w/cast(double)tags.length).lround;
		dock.update(pos.a+[size.w-dockWidth,0], [dockWidth, size.h]);
	}

	void reserveBorders(long[4] reserve){
		this.reserve = reserve;
		resize(size);
	}

}
