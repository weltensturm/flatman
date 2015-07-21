module flatman.workspace;

import flatman;


class Workspace: Base {

	Split split;
	Floating floating;
	bool focusFloating;

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		split = addNew!Split(pos, size);
		floating = addNew!Floating(pos, size);
	}

	override void resize(int[2] size){
		this.size = size;
		foreach(c; children)
			c.resize(size);
	}

	void addClient(Client client){
		updateWindowDesktop(client, monitorActive.workspaces.countUntil(this));
		if(client.isFloating){
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
		foreach(c; children)
			c.remove(client);
	}

	void activate(){
		foreach(c; hiddenChildren)
			c.show;
	}

	void deactivate(){
		foreach(c; children)
			c.hide;
	}

	Client active(){
		if(focusFloating)
			return floating.active;
		return split.active;
	}

	Client[] clients(){
		Client[] clients;
		foreach(container; children ~ hiddenChildren)
			foreach(c; container.children ~ container.hiddenChildren)
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
