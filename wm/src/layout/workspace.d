module flatman.layout.workspace;

import flatman;

__gshared:


class Workspace: Container {

	Split split;
	Floating floating;
	bool focusFloating;
	string context;

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		split = addNew!Split(pos, size);
		split.hide;
		floating = addNew!Floating(pos, size);
		floating.hide;
		["flatman-context", "-c", "/"].execute;
		["flatman-context", "-c", "~"].execute;
		if("~/.flatman/current".expandTilde.exists)
			context = "~/.flatman/current".expandTilde.readText;
	}

	void updateContext(string path){
		"%s.context = %s".format(this, path).log;
		context = path;
	}

	override void resize(int[2] size){
		with(Log("workspace.resize %s".format(size))){
			this.size = size;
			foreach(c; children)
				c.resize(size);
		}
	}

	alias add = Base.add;

	override void add(Client client){
		with(Log("%s.add %s floating=%s fullscreen=%s".format(this, client, client.isFloating, client.isfullscreen))){
			ewmh.updateWindowDesktop(client, monitor.workspaces.countUntil(this));
			if(client.isFloating && !client.isfullscreen){
				floating.add(client);
			}else{
				if(monitor.workspace == this && split.hidden)
					split.show;
				split.add(client);
			}
		}
	}

	void update(Client client){
		if((client.isFloating && !client.isfullscreen) != floating.clients.canFind(client)){
			remove(client);
			add(client);
			if((client.isFloating && !client.isfullscreen) && (client.size.w > size.w || client.size.h > size.h)){
				client.moveResize(pos.a + [20, 20], size.a - [40, 40]);
			}else if(client.isfullscreen)
				client.moveResize(pos, size);
		}else{
			split.resize(split.size);
		}
	}

	@property
	override Client active(){
		if(focusFloating)
			return floating.active;
		return split.active;
	}

	@property
	override void active(Client client){
		foreach(c; children.map!(to!Container).array){
			if(c.clients.canFind(client)){
				focusFloating = (c == floating);
				c.active = client;
			}
		}
	}

    Client clientDir(short direction){
		Client result;
		if(focusFloating)
			result = floating.clientDir(direction);
		else
			result = split.clientDir(direction);
		if(!result)
			result = split.clientDir(direction);
		if(!result)
			result = floating.clientDir(direction);
		return result;
    }

    Client clientContainerDir(short direction){
		return split.clientContainerDir(direction);
    }

	void focusDir(int dir){
		if(focusFloating)
			floating.focusDir(dir);
		else
			split.focusDir(dir);
	}

	void focusTabs(int dir){
		split.focusTabs(dir);
	}

	alias remove = Base.remove;

	override void remove(Client client){
		with(Log("%s.remove %s".format(this, client))){
			if(floating.clients.canFind(client))
				floating.remove(client);
			else if(split.clients.canFind(client))
				split.remove(client);
			else
				assert(0);
			if(!split.children)
				split.hide;
		}
	}

	override void show(){
		super.show;
		if(split.children.length)
			split.show;
		with(Log("%s.show context='%s'".format(this, context))){
			if(context.exists){
				"reset context='%s'".format(context.expandTilde.readText);
				["flatman-context", context.expandTilde.readText].execute;
			}
			floating.show;
		}
	}

	override void hide(){
		super.hide;
		split.hide;
		floating.hide;
	}

	override Client[] clients(){
		return split.clients ~ floating.clients;
	}

	void destroy(){
		floating.destroy;
		split.destroy;
	}

	override string toString(){
		return Log.YELLOW ~ "workspace(%s)".format(cast(void*)this) ~ Log.DEFAULT;
	}

}
