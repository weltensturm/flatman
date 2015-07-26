module flatman.floating;

import flatman;

__gshared:


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
		foreach(c; hiddenChildren){
			c.show;
			updateClient(c);
		}
	}

	override void onHide(){
		foreach(c; children)
			c.hide;
			//XMoveWindow(dpy, c.win, pos.x+size.w, 0);
	}

	void updateClient(Base client){
		XRaiseWindow(dpy, (cast(Client)client).win);
	}

	void addChild(Base client){
		super.add(client);
		updateClient(client);
	}

	void destroy(){
		foreach(c; children)
			unmanage(cast(Client)c, false);
	}

}
