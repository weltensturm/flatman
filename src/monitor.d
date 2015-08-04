module flatman.monitor;

import flatman;

__gshared:


class Monitor {

	int[2] pos;
	int[2] size;
	Client[] strutClients;
	Bar bar;

	Workspace[] workspaces;
	Client[] globals;

	int workspaceActive;

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		foreach(t; tags){
			workspaces ~= new Workspace(pos, size);
		}
		//auto dockWidth = cast(int)(size[0]/cast(double)tags.length).lround;
		//dock = new WorkspaceDock(pos.a+[size.w-dockWidth,0], [dockWidth, size.h], this);
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
		if(monitor.workspaceActive < 0)
			workspaceActive = cast(int)workspaces.length-1;
		if(monitor.workspaceActive >= workspaces.length)
			workspaceActive = 0;
		workspace.show;
		draw;
		updateCurrentDesktop;
		updateDesktopNames;
		//environment["FLATMAN_WORKSPACE"] = workspaceActive.to!string;
	}
	
	void nextWs(){
		switchWorkspace(workspaceActive+1);
	}
	
	void nextWsFilled(){
		foreach(i; workspaceActive+1..workspaces.length){
			if(workspaces[i].clients.length){
				switchWorkspace(cast(int)i);
				return;
			}
		}
	}

	void prevWs(){
		switchWorkspace(workspaceActive-1);
	}
	
	void prevWsFilled(){
		foreach_reverse(i; 0..workspaceActive){
			if(workspaces[i].clients.length){
				switchWorkspace(i);
				return;
			}
		}
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
		XSync(dpy, false);
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
		XSync(dpy, false);
		win.focus;
	}

	void add(Client client, long workspace=-1){
		if(workspace >= cast(long)workspaces.length || workspace < 0)
			client.global = true;
		"monitor adding %s to workspace %s global: %s".format(client.name, workspace, client.global).log;
		if(!client.global){
			if(workspace == -1)
				this.workspace.addClient(client);
			else
				workspaces[workspace].addClient(client);
		}else{
			globals ~= client;
			client.moveResize(client.posOld, client.sizeOld);
		}
		if(!client.isVisible){
			"monitor hiding %s".format(client.name).log;
			client.hide;
		}
	}

	void move(Client client, int workspace){
		this.workspace.remove(client);
		workspaces[workspace].addClient(client);
	}

	void remove(Client client){
		foreach(ws; workspaces){
			if(ws.clients.canFind(client))
				ws.remove(client);
		}
		globals = globals.without(client);
		if(strutClients.canFind(client)){
			strutClients = strutClients.without(client);
			resize(size);
		}
	}


	void draw(){
		workspace.onDraw;
	}

	void destroy(){
		foreach(ws; workspaces)
			ws.destroy;
	}

	Client[] clients(){
		return workspaces
				.without(workspace)
				.map!"a.clients"
				.reduce!"a ~ b"
			~ workspace.clients
			~ globals;
	}

	void resize(int[2] size){
		this.size = size;
		foreach(ws; workspaces){
			long[4] reserve;
			foreach(c; strutClients)
				reserve[] += c.getStrut[];
			ws.move([cast(int)reserve[0], cast(int)reserve[2]]);
			ws.resize([cast(int)(size.w-reserve[1]-reserve[0]), cast(int)(size.h-reserve[2]-reserve[3])]);
		}
		updateWorkarea;
	}

	void strut(Client client, bool remove=false){
		strutClients = strutClients.without(client);
		if(!remove)
			strutClients ~= client;
		resize(size);
	}

}
