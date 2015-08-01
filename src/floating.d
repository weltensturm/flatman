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
	}

	void updateClient(Base client){
		XRaiseWindow(dpy, (cast(Client)client).win);
	}

	override Base add(Base c){
		auto client = cast(Client)c;
		super.add(client);
		if(!client.isfullscreen && !client.isfixed && !client.pos.x && !client.pos.y)
			client.moveResize([pos.x/2-client.size.w/2, size.h-client.size.h], client.size);
		return client;
	}

	void destroy(){
		foreach(c; children)
			unmanage(cast(Client)c, false);
	}

}
