module flatman.layout.container;

import flatman;

__gshared:


class Container: Base {

	long clientActive;

	@property
	Client active(){
		if(clientActive < children.length && clientActive >= 0)
			return children[clientActive].to!Client;
		return null;
	}

	@property
	void active(Client client){
		foreach(i, c; children)
			if(c == client){
				clientActive = i;
			}
	}

	alias add = Base.add;

	abstract void add(Client client);

	alias remove = Base.remove;

	void remove(Client client){
		bool decrease = children.countUntil(client) <= clientActive;
		if(clientActive >= children.length)
			clientActive = children.length-1;
		else if(decrease)
			clientActive = (clientActive-1).max(0);
		super.remove(client);
	}

	override void show(){
		hidden = true;
	}

	override void hide(){
		hidden = false;
	}

	Client[] clients(){
		Client[] clients;
		foreach(c; children.without(active))
			clients ~= cast(Client)c;
		if(active)
			clients ~= active;
		return clients;
	}

}
