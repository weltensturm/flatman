module flatman.monitor;

import flatman;

__gshared:


struct StrutInfo {
	Client client;
	int[4] strut;
}


class Monitor {

	int[2] pos;
	int[2] size;
	StrutInfo[] strutList;

	Workspace[] workspaces;
	Client[] globals;

	int workspaceActive;
	int globalActive;
	bool focusGlobal;

	bool peekTitles;

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		workspaces ~= new Workspace(pos, size);
		workspace.show;
		//auto dockWidth = cast(int)(size[0]/cast(double)tags.length).lround;
		//dock = new WorkspaceDock(pos.a+[size.w-dockWidth,0], [dockWidth, size.h], this);
		auto watch = inotify.addWatch("~/.flatman".expandTilde, false);
		watch.change ~= (path, file){
			if(workspace && file.endsWith("current")){
				workspace.updateContext("~/.flatman/current".expandTilde.readText);
			}
			if(file.endsWith("current") || file.endsWith(".context"))
				updateDesktopNames;
		};
	}

	Client active(){
		if(focusGlobal)
			return globals[globalActive];
		else
			return workspace.active;
	}

	void setActive(Client client){
		if(globals.canFind(client)){
			foreach(i, global; globals){
				if(global == client)
					globalActive = cast(int)i;
			}
			writeln("focus global");
		}else{
			foreach(i, ws; workspaces){
				if(ws.clients.canFind(client)){
					ws.active = client;
					workspaceActive = cast(int)i;
					return;
				}
			}
		}
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
		updateWorkspaces;
		resize(size);
	}

	void switchWorkspace(int pos){
		if(pos == workspaceActive)
			return;
		"hide workspace %s".format(workspaceActive).log;
		workspace.hide;
		if(workspace.clients.length == 0 && workspaces.length > 1){
			workspace.destroy;
			workspaces = workspaces.without(workspace);
			if(pos > workspaceActive)
				pos--;
			updateDesktopCount;
			updateWorkspaces;
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
			updateWorkspaces();
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
		strut(client, true);
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
		int[4] reserve;
		foreach(c; strutList){
			"monitor using strut %s %s".format(c.client.name, c.strut).log;
			reserve[] += c.strut[];
		}
		foreach(ws; workspaces){
			ws.move([reserve[0].to!int, cast(int)reserve[2]]);
			ws.resize([(size.w-reserve[1]-reserve[0]).to!int, (size.h-reserve[2]-reserve[3]).to!int]);
		}
	}

	void strut(Client client, bool remove=false){
		XSync(dpy, false);
		auto found = strutList.any!(a => a.client == client);
		if(found){
			"monitor remove strut %s".format(client).log;
			strutList = strutList.filter!(a => a.client != client).array;
		}

		if(!remove && client.getStrut[0..4].any){
			"monitor add strut %s %s".format(client.name, client.getStrut).log;
			if(!found){
				auto data = client.getStrut[0..4];
				foreach(ref d; data){
					if(d < 0 || d > 200)
						d = 0;
				}
				strutList ~= StrutInfo(client, data.to!(int[4]));
			}
		}
		resize(size);
	}

}
