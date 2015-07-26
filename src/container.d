module flatman.container;

import flatman;

__gshared:


class Container: Base {

	long clientActive;
	
	Client active(){
		if(clientActive < children.length && clientActive >= 0)
			return cast(Client)children[clientActive];
		return null;
	}

	void setFocus(Base client){
		foreach(i, c; children){
			if(c == client){
				clientActive = i;
				return;
			}
		}
	}

	void focus(Base client){
		setFocus(client);
		if(active)
			active.focus;
	}

}
