module flatman.floating;

import flatman;


long find(T)(T[] array, T what){
	long i;
	foreach(e; array){
		if(e == what)
			return i;
		i++;
	}
	return -1;
}


class Floating: Container {

	this(int[2] pos, int[2] size){
		super(pos, size);
	}

	override void activate(){
		foreach(c; clients){
			updateClient(c);
		}
		focus(0);
	}

	override void deactivate(){
		foreach(c; clients)
			XMoveWindow(dpy, c.win, pos.x+size.w, 0);
	}

	void updateClient(Client client){
		client.resize([size.w/2-client.size.w/2,pos.y+size.y-client.size.h],client.size,false);
	}

	override void add(Client client){
		super.add(client);
		updateClient(client);
	}

}
