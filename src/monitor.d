module flatman.monitor;

import flatman;

__gshared:


class Monitor {

	int[2] pos;
	int[2] size;
	Client[] strutClients;

	Workspace[] workspaces;
	Client[] globals;

	int workspaceActive;

	bool peekTitles;

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		workspaces ~= new Workspace(pos, size);
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

	void newWorkspace(long pos){
		"create new workspace at %s".format(pos).writeln;
		auto ws = new Workspace(this.pos, size);
		if(pos <= 0)
			workspaces = ws ~ workspaces;
		else if(pos > workspaces.length-1)
			workspaces ~= ws;
		else
			workspaces.insertInPlace(pos, ws);
		if(workspaceActive >= pos)
			workspaceActive++;
		updateDesktopCount;
		foreach(i, w; workspaces)
			foreach(c; w.clients)
				updateWindowDesktop(c, i);
	}

	void switchWorkspace(int pos){
		if(pos == workspaceActive)
			return;
		"hide workspace %s".format(workspaceActive).log;
		workspace.hide;
		if(workspace.clients.length == 0 && workspaces.length > 1){
			workspaces = workspaces.without(workspace);
			if(pos > workspaceActive)
				pos--;
			updateDesktopCount;
		}
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

	void moveLeft(){
		workspace.split.moveClient(-1);
	}

	void moveRight(){
		workspace.split.moveClient(1);
	}

	void moveDown(){
		if(workspaceActive == workspaces.length-1)
			newWorkspace(workspaces.length);
		auto win = active;
		if(win)
			win.setWorkspace(workspaceActive+1);
		switchWorkspace(workspaceActive+1);
		if(win)
			win.focus;
	}
	
	void moveUp(){
		if(workspaceActive == 0)
			newWorkspace(0);
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
		auto l = workspaces.length;
		auto pos = workspaces.countUntil!(a => a.clients.canFind(client));
		this.workspace.remove(client);
		if(l < workspaces.length-1){
			if(workspace < pos)
				workspace--;
			foreach(i, w; workspaces)
				foreach(c; w.clients)
					updateWindowDesktop(c, i);
		}
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
		Client[] c;
		if(workspaces.length > 1)
			c = workspaces
				.without(workspace)
				.map!"a.clients"
				.reduce!"a ~ b";
		return c ~ workspace.clients ~ globals;
	}

	Client[] clientsVisible(){
		return (workspace.clients ~ globals).filter!(a=>a.isVisible).array;
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
