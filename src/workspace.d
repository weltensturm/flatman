module flatman.workspace;

import flatman;

__gshared:


class Workspace: Base {

	Split split;
	Floating floating;
	Client[] fullscreen;
	bool focusFloating;

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		split = addNew!Split(pos, size);
		floating = addNew!Floating(pos, size);
	}

	override void resize(int[2] size){
		this.size = size;
		foreach(c; children ~ hiddenChildren)
			c.resize(size);
		foreach(c; fullscreen)
			c.moveResize(pos, size);
	}

	void addClient(Client client){
		updateWindowDesktop(client, monitorActive.workspaces.countUntil(this));
		if(client.isfullscreen){
			fullscreen ~= client;
			client.moveResize(pos, size);
		}else if(client.isFloating){
			floating.add(client);
		}else{
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
		foreach(c; children ~ hiddenChildren)
			c.remove(client);
		if(refocus)
			focus(active);
	}

	override void show(){
		super.show;
		split.show;
		floating.show;
		focus(active);
	}

	override void hide(){
		foreach(c; children)
			c.hide;
		super.hide;
	}

	Client active(){
		if(focusFloating)
			return floating.active;
		return split.active;
	}

	Client[] clients(){
		Client[] clients;
		foreach(c; split.hiddenChildren ~ split.children)
			clients ~= cast(Client)c;
		clients ~= fullscreen;
		foreach(c; floating.hiddenChildren ~ floating.children)
			clients ~= cast(Client)c;
		return clients;
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
