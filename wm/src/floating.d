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

	override void show(){
		if(!hidden)
			return;
		foreach(c; clients){
			XMoveWindow(dpy, c.win, c.pos.x, c.pos.y);
			updateClient(c);
		}
		hidden = false;
	}

	override void hide(){
		if(hidden)
			return;
		foreach(c; clients)
            XMoveWindow(dpy, c.win, c.pos.x, -monitor.size.h+c.pos.y);
		hidden = true;
	}

	void updateClient(Base client){
		XRaiseWindow(dpy, (cast(Client)client).win);
	}

	alias add = Base.add;

	override void add(Client client){
		"floating adding %s".format(client.name).log;
		add(client.to!Base);
		if(!client.isfullscreen && !client.isfixed && (!client.pos.x && !client.pos.y || client.pos.x < 0 || client.pos.y < 0)){
			client.moveResize([pos.x+size.w/2-client.size.w/2, pos.y+size.h/2-client.size.h/2], client.size, true);
		}else
			client.configure;
	}

	override Client[] clients(){
		return children.to!(Client[]);
	}

	void destroy(){
		foreach(c; children.to!(Client[]))
			c.unmanage(false);
	}

	void focusDir(int dir){
		auto newActive = clientActive+dir;
		if(newActive >= children.length)
			newActive = 0;
		else if(newActive < 0)
			newActive = children.length-1;
		children[newActive].to!Client.focus;
	}

}
