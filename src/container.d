module flatman.container;


import flatman;


class Container {

	int[2] pos;
	int[2] size;

	Client[] clients;

	int clientActive = -1;

	this(int[2] pos, int[2] size){
		this.pos = pos;
		this.size = size;
	}

	void resize(int[2] size){
		this.size = size;
	}

	void move(int[2] pos){
		this.pos = pos;
	}

	void activate(){}

	void deactivate(){}

	void add(Client client){
		clients ~= client;
		focus(client);
	}

	void remove(Client client){
		auto idx = clients.countUntil(client);
		if(idx < 0)
			return;
		clients = clients[0..idx] ~ clients[idx+1..$];
		focus(null);
	}

	void setFocus(Client client){
		foreach(i,c; clients){
			if(c == client){
				clientActive = cast(int)i;
				return;
			}
		}
		clientActive = -1;
	}

	void focus(Client client){
		setFocus(client);
		if(active)
			active.focus;
	}

	Client active(){
		if(clientActive < 0 || clientActive >= clients.length)
			return null;
		return clients[clientActive];
	}

	void onDraw(){}

}