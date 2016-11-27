module flatman.layout.floating;

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

	void restack(){
		"floating.restack".log;
		foreach(i, client; clients){
			client.raise;
		}
	}

	override void show(){
		if(!hidden)
			return;
		foreach(c; clients)
			c.showSoft;
		hidden = false;
	}

	override void hide(){
		if(hidden)
			return;
		foreach(c; clients)
			c.hideSoft;
		hidden = true;
	}

	override void onDraw(){
		foreach(c; clients)
			if(c.frame)
				c.frame.onDraw;
	}

	void raise(Client client){
		children = children.without(client) ~ client;
		restack;
	}

	void moveResizeClient(Client client){
		if(client.isfullscreen){
			client.moveResize(client.monitor.pos, client.monitor.size);
		}else{
			client.moveResize(client.posFloating, client.sizeFloating);
			if(client.frame)
				client.frame.moveResize(client.pos.a-[0,cfg.tabsTitleHeight], [client.size.w,cfg.tabsTitleHeight]);
		}
	}

	alias add = Base.add;

	override void add(Client client){
		"floating.add %s fullscreen=%s".format(client, client.isfullscreen).log;
		add(client.to!Base);
		if(client.decorations)
			client.frame = new Frame(client, client.posFloating.a - [0,cfg.tabsTitleHeight], [client.sizeFloating.w,cfg.tabsTitleHeight]);
		if(client.isfullscreen){
			"Floating fullscreen??".log;
 			client.moveResize(client.monitor.pos, client.monitor.size);
		}else if(!client.posFloating.x && !client.posFloating.y || client.posFloating.x < 0 || client.posFloating.y < 0){
			client.moveResize([pos.x+size.w/2-client.sizeFloating.w/2, pos.y+size.h/2-client.sizeFloating.h/2], client.sizeFloating, true);
		}else
			client.moveResize(client.posFloating, client.sizeFloating);
		flatman.restack;
	}

	alias remove = Base.remove;

	override void remove(Client client){
		if(client.frame)
			client.frame.destroy;
		client.frame = null;
		super.remove(client);
	}
	alias active = Container.active;

	@property
	override void active(Client client){
		"floating.active %s".format(client).log;
		super.active = client;
		onDraw;
	}

	override Client[] clients(){
		return children.to!(Client[]);
	}

	void destroy(){
		foreach(c; children.to!(Client[])){
			if(c.frame)
				c.frame.destroy;
			c.unmanage(false);
		}
	}

	void focusDir(int dir){
		if(!children.length)
			return;
		auto newActive = clientActive+dir;
		if(newActive >= children.length)
			newActive = 0;
		else if(newActive < 0)
			newActive = children.length-1;
		children[newActive].to!Client.focus;
	}

}
