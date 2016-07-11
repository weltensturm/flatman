module flatman.monitor;

import flatman;

__gshared:


Monitor dirtomon(int dir){
	return monitors[0];
}


void focusmon(int arg){
	Monitor m = dirtomon(arg);
	if(!m)
		return;
	if(m == monitor)
		return;
	monitor.active.unfocus(false); /* s/true/false/ fixes input focus issues
					in gedit and anjuta */
	monitor = m;
	//focus(null);
}


Monitor findMonitor(int[2] pos, int[2] size=[1,1]){
	Monitor result = monitor;
	int a, area = 0;
	foreach(monitor; monitors)
		if((a = intersectArea(pos.x, pos.y, size.w, size.h, monitor)) > area){
			area = a;
			result = monitor;
		}
	return result;
}


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

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		workspaces ~= new Workspace(pos, size);
		workspace.show;
		//auto dockWidth = cast(int)(size[0]/cast(double)tags.length).lround;
		//dock = new WorkspaceDock(pos.a+[size.w-dockWidth,0], [dockWidth, size.h], this);
		Inotify.watch("~/.flatman".expandTilde, (path, file, action){
			if(action != Inotify.Modify)
				return;
			if(workspace && file.endsWith("current")){
				workspace.updateContext("~/.flatman/current".expandTilde.readText);
			}
			if(file.endsWith("current") || file.endsWith(".context"))
				updateDesktopNames;
		});
	}

	void restack(){
		"monitor.restack".log;
		workspace.split.restack;
		foreach(w; globals)
			w.raise;
		workspace.floating.restack;
	}

	Client active(){
		if(focusGlobal)
			return globals[globalActive];
		else
			return workspace.active;
	}

	void setActive(Client client){
		"monitor.setActive %s".format(client).log;
		if(globals.canFind(client)){
			foreach(i, global; globals){
				if(global == client){
					globalActive = cast(int)i;
					"focus global".log;
				}
			}
		}else{
			foreach(i, ws; workspaces){
				if(ws.clients.canFind(client)){
					ws.active = client;
					switchWorkspace(cast(int)i);
					return;
				}
			}
		}
	}

	Workspace workspace(){
		return workspaces[workspaceActive];
	}

	void newWorkspace(long pos){
		"monitor.newWorkspace %s".format(pos).log;
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
		}
		workspaceActive = pos;
		if(monitor.workspaceActive < 0)
			workspaceActive = cast(int)workspaces.length-1;
		if(monitor.workspaceActive >= workspaces.length)
			workspaceActive = 0;
		"show workspace %s".format(workspaceActive).log;
		workspace.show;
		updateWorkspaces;
		updateCurrentDesktop;
		redraw = true;
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
		if(workspaceActive == workspaces.length-1){
			foreach(monitor; monitors)
				monitor.newWorkspace(workspaces.length);
		}
		auto win = active;
		if(win)
			win.setWorkspace(workspaceActive+1);
		foreach(monitor; monitors)
			switchWorkspace(workspaceActive+1);
		if(win)
			win.focus;
	}
	
	void moveUp(){
		if(workspaceActive == 0){
			foreach(monitor; monitors)
				monitor.newWorkspace(0);
		}
		auto win = active;
		if(win)
			win.setWorkspace(workspaceActive-1);
		foreach(monitor; monitors)
			monitor.switchWorkspace(workspaceActive-1);
		if(win)
			win.focus;
	}

	void add(Client client, long workspace=-1){
		if(workspace >= cast(long)workspaces.length || workspace < 0)
			client.global = true;
		"monitor.add %s workspace=%s".format(client, workspace).log;
		if(!client.global){
			if(workspace == -1)
				this.workspace.add(client);
			else{
				workspaces[workspace].add(client);
			}
		}else{
			globals ~= client;
			client.moveResize(client.posFloating, client.sizeFloating);
		}
	}

	void move(Client client, int workspace){
		"monitor.move %s workspace=%s".format(client, workspace).log;
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
		"monitor.remove %s".format(client).log;
		foreach(ws; workspaces){
			if(ws.clients.canFind(client))
				ws.remove(client);
		}
		globals = globals.without(client);
		XSync(dpy, false);
		strut(client, true);
	}

	void onDraw(){
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
		"monitor.resize %s".format(size).log;
		this.size = size;
		int[4] reserve;
		foreach(c; strutList){
			"monitor strut %s %s".format(c.client, c.strut).log;
			reserve[] += c.strut[];
		}
		foreach(ws; workspaces){
			ws.move(pos.a + [reserve[0].to!int, cast(int)reserve[2]]);
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
			"monitor add strut %s %s".format(client, client.getStrut).log;
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
