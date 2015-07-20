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
		move(pos);
		resize(size);
	}

	override void onShow(){
		foreach(c; children){
			c.show;
			updateClient(c);
		}
		focus(active);
	}

	override void onHide(){
		foreach(c; children)
			c.hide;
			//XMoveWindow(dpy, c.win, pos.x+size.w, 0);
	}

	void updateClient(Base client){
		client.move([size.w/2-client.size.w/2,pos.y+size.y-client.size.h]);
	}

	void addChild(Base client){
		super.add(client);
		updateClient(client);
	}

}
