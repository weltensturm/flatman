module flatman.container;

import flatman;


class Container: Base {

	int clientActive;
	
	Client active(){
		if(clientActive < children.length && clientActive >= 0)
			return cast(Client)children[clientActive];
		return null;
	}

	void setFocus(Base client){
		int i;
		foreach(c; children){
			if(c == client){
				clientActive = i;
				return;
			}
			i++;
		}
	}

	void focus(Base client){
		setFocus(client);
		if(active)
			active.focus;
	}

}
