module flatman.layout.monitor;

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


class Monitor {

	int id;
	int[2] pos;
	int[2] size;

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
		with(Log("monitor.restack")){
			workspace.split.restack;
			foreach(w; globals)
				w.raise;
			workspace.floating.restack;
		}
	}

	Client active(){
		if(focusGlobal)
			return globals[globalActive];
		else
			return workspace.active;
	}

	void setActive(Client client){
		with(Log("monitor.setActive %s".format(client))){
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
	}

	Workspace workspace(){
		return workspaces[workspaceActive];
	}

	void add(Client client, long workspace=-1){
		client.monitor = this;
		if(workspace < 0)
			client.global = true;
		with(Log("monitor.add %s workspace=%s".format(client, workspace))){
			if(!client.global){
				if(workspace == -1)
					this.workspace.add(client);
				else{
					workspaces[workspace.max(0).min(workspaces.length-1)].add(client);
				}
			}else{
				globals ~= client;
				//client.moveResize(client.posFloating, client.sizeFloating);
			}
		}
	}

	void move(Client client, int workspace){
		with(Log("monitor.move %s workspace=%s".format(client, workspace))){
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
	}

	void remove(Client client){
		with(Log("monitor.remove %s".format(client))){
			foreach(ws; workspaces){
				if(ws.clients.canFind(client))
					ws.remove(client);
			}
			globals = globals.without(client);
			XSync(dpy, false);
			resize(size);
		}
	}

	void update(Client client){
		foreach(ws; workspaces){
			if(ws.clients.canFind(client))
				workspace.update(client);
		}
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
		with(Log("monitor.resize %s".format(size))){
			this.size = size;
			int[4] reserve;
			foreach(c; clients){
				if(!c.strut)
					continue;
				auto strutNormalized = [
						(c.pos.x - pos.x + c.size.w/2.0)/size.w,
						(c.pos.y - pos.y + c.size.h/2.0)/size.h
				];
				"strut normalized %s %s".format(c, strutNormalized).log;
				reserve[0] += strutNormalized.y < 1-strutNormalized.x && strutNormalized.y > strutNormalized.x ? c.size.w : 0;
				reserve[1] += strutNormalized.y > 1-strutNormalized.x && strutNormalized.y < strutNormalized.x ? c.size.w : 0;
				reserve[2] += strutNormalized.y < strutNormalized.x && strutNormalized.y < 1-strutNormalized.x ? c.size.h : 0;
				reserve[3] += strutNormalized.y > strutNormalized.x && strutNormalized.y > 1-strutNormalized.x ? c.size.h : 0;
			}
			foreach(ref r; reserve){
				if(r > size.w || r > size.h)
					r = 0;
			}
			"monitor strut %s".format(reserve).log;
			foreach(ws; workspaces){
				ws.move(pos.a + [reserve[0].to!int, cast(int)reserve[2]]);
				ws.resize([(size.w-reserve[1]-reserve[0]).to!int, (size.h-reserve[2]-reserve[3]).to!int]);
			}
		}
	}

	override string toString(){
		return "Monitor %s".format(id);
	}

}
