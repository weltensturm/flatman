module flatman.workspace;

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
	}

	override void resize(int[2] size){
		this.size = size;
		foreach(c; children)
			c.resize(size);
	}

	alias add = Base.add;

	override void add(Client client){
		"adding %s isFloating %s".format(client.name, client.isFloating).log;
		updateWindowDesktop(client, monitor.workspaces.countUntil(this));
		if(client.isFloating && !client.isfullscreen){
			floating.add(client);
		}else{
			if(monitor.workspace == this)
				split.show;
			split.add(client);
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
		"workspace removing %s".format(client.name).log;
		auto refocus = client == active;
		//client.hide;
		foreach(c; children)
			c.to!Container.remove(client);
		if(!split.children)
			split.hide;
	}

	override void show(){
		super.show;
		if(split.children.length)
			split.show;
		if(context.exists)
			std.file.write("~/.flatman/current", context);
		floating.show;
		focus(active);
	}

	override void hide(){
		super.hide;
		split.hide;
		floating.hide;
	}

	override Client[] clients(){
		return split.clients ~ floating.clients;
	}

	override void onDraw(){
		foreach(c; children)
			c.onDraw;
	}

	void destroy(){
		floating.destroy;
		split.destroy;
	}

}
