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

	void setFocus(int dir){
		if(clients.length){
			clientActive += dir;
			if(clientActive > clients.length-1){
				if(dir > 0)
					clientActive = cast(int)clients.length-1;
				else
					clientActive = 0;
			}
		}else
			clientActive = -1;
	}

	void add(Client client){
		clients ~= client;
	}

	void remove(Client client){
		auto idx = clients.countUntil(client);
		if(idx < 0)
			return;
		clients = clients[0..idx] ~ clients[idx+1..$];
		focus(-1);
	}

	void setFocus(Client client){
		setFocus(cast(int)clients.countUntil(client));
	}

	void focus(Client client){
		focus(cast(int)clients.countUntil(client));
	}

	void focus(int dir){
		setFocus(dir);
		if(clients.length){
			clients[clientActive].focus;
		}
	}

	Client active(){
		if(clientActive < 0 || clientActive >= clients.length)
			return null;
		return clients[clientActive];
	}

	void onDraw(){}

}