module flatman.workspace;

import flatman;


class Workspace {

	int[2] pos;
	int[2] size;

	Container[] containers;
	Split split;
	Floating floating;
	bool focusFloating;

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
		split = new Split(pos, size);
		containers ~= split;
		floating = new Floating(pos, size);
		containers ~= floating;
	}

	void resize(int[2] size){
		this.size = size;
		foreach(c; containers)
			c.resize(size);
	}

	void add(Client client){
		if(client.isFloating){
			floating.add(client);
		}else{
			split.add(client);
		}
	}

	void focus(Client client){
		foreach(c; containers){
			if(c.clients.canFind(client)){
				c.focus(client);
				focusFloating = (c == floating);
			}
		}
	}

	void setFocus(Client client){
		foreach(c; containers){
			if(c.clients.canFind(client)){
				c.setFocus(client);
				focusFloating = (c == floating);
			}
		}	
	}

	void remove(Client client){
		foreach(c; containers)
			c.remove(client);
	}

	void activate(){
		foreach(c; containers)
			c.activate;
	}

	void deactivate(){
		foreach(c; containers)
			c.deactivate;
	}

	Client active(){
		if(focusFloating)
			return floating.active;
		return split.active;
	}

	Client[] clients(){
		return split.clients ~ floating.clients;
	}

	void onDraw(){
		foreach(c; containers)
			c.onDraw;
	}

}
