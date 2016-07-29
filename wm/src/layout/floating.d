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

	Frame[] frames;

	this(int[2] pos, int[2] size){
		move(pos);
		resize(size);
	}

	void restack(){
		"floating.restack".log;
		foreach(i, client; clients){
			client.raise;
			XRaiseWindow(dpy, frames[i].window);
		}
	}

	override void show(){
		if(!hidden)
			return;
		foreach(c; clients){
			XMoveWindow(dpy, c.win, c.pos.x, c.pos.y);
			updateClient(c);
		}
        foreach(f; frames)
        	XMoveWindow(dpy, f.window, f.pos.x, f.pos.y);
		hidden = false;
	}

	override void hide(){
		if(hidden)
			return;
		foreach(c; clients)
            XMoveWindow(dpy, c.win, c.pos.x, -monitor.size.h+c.pos.y);
        foreach(f; frames)
        	XMoveWindow(dpy, f.window, f.pos.x, -monitor.size.h+f.pos.y);
		hidden = true;
	}

	override void onDraw(){
		foreach(frame; frames)
			frame.onDraw;
	}

	void updateClient(Base client){
		//XRaiseWindow(dpy, (cast(Client)client).win);
	}

	void raise(Client client){
		children = children.without(client) ~ client;
		restack;
	}

	void moveResizeClient(Client client){
		if(client.isfullscreen){
			client.moveResize(monitor.pos, monitor.size);
		}else{
			client.moveResize(client.posFloating, client.sizeFloating);
			foreach(frame; frames){
				if(frame.client == client){
					frame.moveResize(client.pos.a-[0,cfg.tabsTitleHeight], [client.size.w,cfg.tabsTitleHeight]);
				}
			}
		}
	}

	alias add = Base.add;

	override void add(Client client){
		"floating.add %s fullscreen=%s".format(client, client.isfullscreen).log;
		add(client.to!Base);
		client.frame = new Frame(client, client.posFloating.a - [0,cfg.tabsTitleHeight], [client.sizeFloating.w,cfg.tabsTitleHeight]);
		frames ~= client.frame;
		if(client.isfullscreen)
 			client.moveResize(monitor.pos, monitor.size);
		else if(!client.posFloating.x && !client.posFloating.y || client.posFloating.x < 0 || client.posFloating.y < 0){
			client.moveResize([pos.x+size.w/2-client.sizeFloating.w/2, pos.y+size.h/2-client.sizeFloating.h/2], client.sizeFloating, true);
		}else
			client.moveResize(client.posFloating, client.sizeFloating);
		flatman.restack;
	}

	alias remove = Base.remove;

	override void remove(Client client){
		foreach(frame; frames.filter!(a => a.client == client)){
			frames = frames.without(frame);
			frame.destroy;
			break;
		}
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
		foreach(f; frames)
			f.destroy;
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
