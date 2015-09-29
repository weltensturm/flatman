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

	bool peekTitles;

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		foreach(t; tags){
			workspaces ~= new Workspace(pos, size);
		}
		workspace.show;
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
		"hide workspace %s".format(workspaceActive).log;
		workspace.hide;
		workspaceActive = pos;
		if(monitor.workspaceActive < 0)
			workspaceActive = cast(int)workspaces.length-1;
		if(monitor.workspaceActive >= workspaces.length)
			workspaceActive = 0;
		"show workspace %s".format(workspaceActive).log;
		workspace.show;
		draw;
		updateCurrentDesktop;
		updateDesktopNames;
		//environment["FLATMAN_WORKSPACE"] = workspaceActive.to!string;
	}

	void moveWorkspace(int pos){
		if(flatman.active)
			flatman.active.setWorkspace(pos);
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
		if(workspaceActive == workspaces.length-1)
			return;
		auto win = active;
		if(win)
			win.setWorkspace(workspaceActive+1);
		switchWorkspace(workspaceActive+1);
		if(win)
			win.focus;
	}
	
	void moveUp(){
		if(workspaceActive == 0)
			return;
		auto win = active;
		if(win)
			win.setWorkspace(workspaceActive-1);
		switchWorkspace(workspaceActive-1);
		if(win)
			win.focus;
	}

	void add(Client client, long workspace=-1){
		if(workspace >= cast(long)workspaces.length || workspace < 0)
			client.global = true;
		"monitor adding %s to workspace %s global: %s".format(client.name, workspace, client.global).log;
		if(!client.global){
			if(workspace == -1)
				this.workspace.add(client);
			else
				workspaces[workspace].add(client);
		}else{
			globals ~= client;
			client.moveResize(client.posFloating, client.sizeFloating);
		}
		if(client.isVisible)
			client.show;
		else
			client.hide;
	}

	void move(Client client, int workspace){
		this.workspace.remove(client);
		workspaces[workspace].add(client);
	}

	void remove(Client client){
		"removing client %s".format(client.name).log;
		foreach(ws; workspaces){
			if(ws.clients.canFind(client))
				ws.remove(client);
		}
		globals = globals.without(client);
		XSync(dpy, false);
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

	Client[] clientsVisible(){
		return workspace.clients ~ globals;
	}

	void resize(int[2] size){
		this.size = size;
		foreach(ws; workspaces){
			long[4] reserve;
			foreach(c; strutClients){
				auto s = c.getStrut;
				"monitor using strut %s %s".format(c.name, s).log;
				reserve[] += s[];
			}
			ws.move([cast(int)reserve[0], cast(int)reserve[2]]);
			ws.resize([cast(int)(size.w-reserve[1]-reserve[0]), cast(int)(size.h-reserve[2]-reserve[3])]);
		}
	}

	void strut(Client client, bool remove=false){
		XSync(dpy, false);
		if(strutClients.canFind(client)){
			if(remove){
				"monitor remove strut %s".format(client).log;
				strutClients = strutClients.without(client);
				resize(size);
			}
		}else if(!remove && client.getStrut[0..4].any){
			"monitor add strut %s %s".format(client.name, client.getStrut).log;
			strutClients ~= client;
			resize(size);
		}
	}

}
