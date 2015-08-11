module flatman.workspace;

import flatman;

__gshared:


class Workspace: Base {

	Split split;
	Floating floating;
	bool focusFloating;

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

	void addClient(Client client){
		"adding %s isFloating %s".format(client.name, client.isFloating).log;
		updateWindowDesktop(client, monitor.workspaces.countUntil(this));
		if(client.isFloating || client.isfullscreen){
			floating.add(client);
		}else{
			writeln(split.hidden);
			split.show;
			split.add(client);
		}
	}

	void focus(Client client){
		foreach(c; children){
			if(c.children.canFind(client)){
				(cast(Container)c).focus(client);
				focusFloating = (c == floating);
			}
		}
	}

	void setFocus(Client client){
		foreach(c; children){
			if(c.children.canFind(client)){
				(cast(Container)c).setFocus(client);
				focusFloating = (c == floating);
			}
		}
	}

	override void remove(Base client){
		auto refocus = client == active;
		client.hide;
		foreach(c; children)
			c.remove(client);
		if(!split.children)
			split.hide;
		if(refocus)
			focus(active);
	}

	override void show(){
		super.show;
		if(split.children.length)
			split.show;
		floating.show;
		focus(active);
	}

	override void hide(){
		super.hide;
		split.hide;
		floating.hide;
	}

	Client active(){
		if(focusFloating)
			return floating.active;
		return split.active;
	}

	Client[] clients(){
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
