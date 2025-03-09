module flatman.layout.split;

import
    flatman,
	flatman.simpleWindow,
	drag = flatman.dragging,
    ws.bindings.xlib,
    common.xevents;


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


void swap(T)(ref T[] array, size_t i1, size_t i2){
    T copy = array[i1];
    array[i1] = array[i2];
    array[i2] = copy;
}


class Separator: Base {

    WindowHandle window;
    XDraw _draw;
    int[2] cursor;

    override DrawEmpty draw(){
        return _draw;
    }

    Split split;
    size_t index;

    this(Split split, size_t index){
        this.split = split;
        this.index = index;
        size = [10,10];

        XVisualInfo* visual;
        visual = new XVisualInfo;
        if(!XMatchVisualInfo(dpy, DefaultScreen(dpy), 32, TrueColor, visual))
            writeln("XMatchVisualInfo failed");

        XSetWindowAttributes wa;
        wa.override_redirect = true;
        wa.background_pixmap = None;
		wa.border_pixmap = None;
		wa.border_pixel = 0;
		wa.bit_gravity = NorthWestGravity;
		wa.colormap = XCreateColormap(dpy, flatman.root, visual.visual, AllocNone);

        window = XCreateWindow(
                dpy,
                flatman.root,
                pos.x, pos.y,
                size.w, size.h,
                0,
                visual.depth,
                CopyFromParent,
                visual.visual,
				CWOverrideRedirect | CWBorderPixel | CWBitGravity | CWColormap | CWBackPixmap,
                &wa
        );

        _draw = new XDraw(dpy, window);
        XSelectInput(dpy, window, ExposureMask | EnterWindowMask | LeaveWindowMask | ButtonPressMask);
        window.replace(Atoms._FLATMAN_OVERVIEW_HIDE, 1L);
        hide;
        Events[window] ~= this;

        auto cursor = XCreateFontCursor(dpy, split.horizontal ? XC_sb_h_double_arrow : XC_sb_v_double_arrow);
        XDefineCursor(dpy, window, cursor);

    }

    @WindowMouseButton
    void mouse(bool pressed, Mouse.button button){
        if(button == Mouse.buttonLeft && pressed){
            .drag.drag(button, (int[2] cursor){
                int diff;
                if(split.horizontal)
                    diff = pos.x - cursor.x + size.w/2;
                else
                    diff = pos.y - cursor.y + size.h/2;
                if(!diff)
                    return;
                split.sizes[index] -= diff;
                split.sizes[index+1] += diff;
                split.rebuild;
            });

        }
    }

    override void show(){
        //replace!long(window, Atoms._NET_WM_DESKTOP, monitor.workspaceActive);
        if(size.w > 0 && size.h > 0){
            "separator.show".log;
            hidden = false;
            //XMoveWindow(dpy, window, pos.x, pos.y);
            XMapWindow(dpy, window);
        }else
            hide;
    }

    override void hide(){
        "separator.hide".log;
        hidden = true;
        //XMoveWindow(dpy, window, pos.x, pos.y-monitor.size.h);
        XUnmapWindow(dpy, window);
    }

    void destroy(){
        draw.destroy;
        XDestroyWindow(dpy, window);
        Events.forget(this);
    }

    void moveResize(int[2] pos, int[2] size){
        "separator.moveResize %s %s".format(pos, size).log;
        XMoveResizeWindow(dpy, window, pos.x, pos.y, size.w.max(1), size.h.max(1));
    }

    @WindowMove
    void moved(int[2] pos){
        this.pos = pos;
    }

    @WindowResize
    void resized(int[2] size){
        this.size = size;
        draw.resize(size);
        drawWindow;
    }

    @WindowExpose
    void drawWindow(){
        /+
        draw.setColor(config.split.background);
        draw.rect([0,0], size);
        draw.finishFrame;
        +/
        draw.clear;
        //draw.setColor(split.horizontal ? [0, 0, 0, 0.9] : [1, 1, 1, 0.9]);
        if(config.split.separatorSize){
            int width = config.split.separatorSize;
            draw.setColor([0, 0, 0, 0.9]);
            if(split.horizontal)
                draw.rect([size.w/2-width/2, 0], [width, size.h]);
            else
                draw.rect([0, size.h/2-width/2], [size.w, width]);
        }
        draw.finishFrame;
    }

}


class Split: Container {

    bool horizontal;

    long[] sizes;

    Separator[] separators;
    SimpleWindow background;

    bool lock;

    this(int[2] pos, int[2] size, bool horizontal=true){
        hidden = true;
        this.horizontal = horizontal;
        background = new SimpleWindow;
        background.color = (horizontal ? [0, 0, 0, 0.9]: [1, 1, 1, 0.9]);

        move(pos);
        resize(size);
    }

    override WindowHandle[] stack(){
        if(clientActive < 0 || clientActive >= children.length)
            return [];
        WindowHandle[] stack;
        stack ~= children[clientActive].to!Container.stack;
        foreach(offset; 1..clientActive.max(children.length-1-clientActive)+1){
            if(clientActive-offset.to!long >= 0)
                stack ~= children[clientActive-offset].to!Container.stack;
            if(clientActive+offset < children.length)
                stack ~= children[clientActive+offset].to!Container.stack;
        }
        return stack ~ separators.map!(a => a.window).array ~ background.window;
    }

    override void destroy(){
        foreach(c; children)
            c.to!Container.destroy;
        foreach(s; separators)
            s.destroy;
        background.destroy;
    }

    void sizeInc(){
        sizes[clientActive] += 50;
        rebuild;
    }

    void sizeDec(){
        sizes[clientActive] -= 50;
        rebuild;
    }

    override void show(){
        if(!hidden)
            return;
        with(Log("split.show")){
            hidden = false;
            if(!children.length)
                return;
            foreach(c; children ~ separators.to!(Base[]) ~ background)
                c.show;
            rebuild;
        }
    }

    override void hide(){
        if(hidden)
            return;
        with(Log("split.hide")){
            hidden = true;
            foreach(c; children ~ separators.to!(Base[]) ~ background)
                c.hide;
        }
    }

    alias add = Base.add;

    override void add(Client client){
        add(client, long.max);
    }

    void addRelative(Client c, int[2] pos){
        add(c, clientActive + (horizontal ? pos.x : pos.y));
    }

    override void add(Client c, int[2] pos){
        add(c, horizontal ? pos.x : pos.y);
    }

    void add(Client client, long position=long.max){
        if(position == long.max)
            position = clientActive;
        with(Log("split.add %s pos=%s".format(client, position))){
            Container container;
            if(position >= 0 && position < children.length){
                container = children[position].to!Container;
            }else{
                container = new Tabs;
                container.parent = this;
                auto size = horizontal ? client.size.w : client.size.h;
                if(position >= 0 && position < children.length.to!long){
                    children = children[0..position+1] ~ container ~ children[position+1..$];
                    sizes = sizes[0..position+1] ~ size ~ sizes[position+1..$];
                }else{
                    if(position < 0){
                        children = container ~ children;
                        sizes = size ~ sizes;
                    }else{
                        children ~= container;
                        sizes ~= size;
                    }
                }
                if(children.length > 1)
                    separators ~= new Separator(this, separators.length);
                if(!hidden){
                    container.show;
                    if(separators.length)
                        separators[$-1].show;
                }
            }
            rebuild;
            container.add(client);
            rebuild; // TODO: nicify
            foreach(child; children.to!(Container[]))
                child.updateHints;
        }
    }

    void add(Container container, long position=long.max){
        if(position == long.max)
            position = clientActive;
        with(Log("split.add %s pos=%s".format(container, position))){
            container.parent = this;
            auto size = horizontal ? container.size.w : container.size.h;
            if(position >= 0 && position < children.length.to!long){
                children = children[0..position+1] ~ container ~ children[position+1..$];
                sizes = sizes[0..position+1] ~ size ~ sizes[position+1..$];
            }else{
                if(position < 0){
                    children = container ~ children;
                    sizes = size ~ sizes;
                }else{
                    children ~= container;
                    sizes ~= size;
                }
            }
            if(children.length > 1)
                separators ~= new Separator(this, separators.length);
            if(!hidden){
                container.show;
                if(separators.length)
                    separators[$-1].show;
            }
            //foreach(child; children.to!(Container[]))
            //    child.updateHints;
            rebuild;
        }
    }

    override void moveClient(int[2] dir){
        auto shift = horizontal ? dir.x : dir.y;
        auto activeContainer = clientActive >= 0 && clientActive < children.length
                               ? cast(Container)children[clientActive]
                               : null;
        
        if(!shift){
            auto split = cast(Split)activeContainer;
            if(split && split.horizontal != horizontal
               || activeContainer.clients.length == 1){
                with(Log("split.moveClient parent" ~ dir.to!string)){
                    (cast(Container)parent).moveClient(dir);
                }
            }else{
                with(Log("split.moveClient into new" ~ dir.to!string)){
                    auto newContainer = new Split(activeContainer.pos, activeContainer.size, !horizontal);
                    newContainer.parent = this;
                    auto client = active;
                    activeContainer.remove(client);
                    activeContainer.parent = null;
                    children[clientActive] = newContainer;
                    newContainer.add(activeContainer);
                    newContainer.addRelative(client, dir);
                    newContainer.show;
                    client.focus;
                }
            }
        }else if(clientActive+shift >= 0 && clientActive+shift < children.length){
            with(Log("split.moveClient" ~ dir.to!string)){
                auto target = cast(Container)children[clientActive+shift];
                auto client = active;
                remove(client);
                target.add(client, [-dir.x, -dir.y]);
                if(children.length == 1){
                    (cast(Container)parent).tryMerge;
                }
                client.focus;
            }
        }else{
            if(activeContainer.clients.length > 1){
                with(Log("split.moveClient edge" ~ dir.to!string)){
                    auto client = active;
                    remove(client);
                    addRelative(client, dir);
                    client.focus;
                }
            }else{
                with(Log("split.moveClient parent" ~ dir.to!string)){
                    (cast(Container)parent).moveClient(dir);
                }
            }
        }
    }

    /+
    override void moveClient(int dir){
        lock = true;
        if(clientActive >= 0 && clientActive < children.length){
            auto tabs = children[clientActive].to!Tabs;
            Tabs tabsNext;
            if(clientActive+dir >= 0 && clientActive+dir < children.length)
                tabsNext = children[clientActive+dir].to!Tabs;
            if(config.tabs.sortBy != config.tabs.sortBy.history && (dir < 0 && tabs.prev || dir > 0 && tabs.next)){
                if(dir < 0)
                    tabs.moveLeft;
                else
                    tabs.moveRight;
            }else if(tabsNext){
                Client client = tabs.active;
                remove(client);
                tabsNext.add(client);
                client.focus;
            }else{
                Client client = tabs.active;
                remove(client);
                add(client, clientActive+dir);
                client.focus;
            }
        }
        lock = false;
        rebuild;
    }
    +/

    override void remove(Base base){
        Base.remove(base);
        rebuild;
    }

    override void remove(Client client){
        with(Log("split.remove %s".format(client))){
            foreach(i, container; children.to!(Container[])){
                if(container.clients.canFind(client)){
                    container.remove(client);
                    if(!container.children.length){
                        container.destroy;
                        Log("split.removeContainer " ~ i.to!string);
                        remove(container);
                        sizes = sizes[0..i] ~ sizes[i+1..$];
                        if(separators.length){
                            separators[$-1].destroy;
                            separators = separators[0..$-1];
                        }
                        if(clientActive >= children.length)
                            clientActive = cast(int)children.length-1;
                        // foreach(child; children.to!(Tabs[]))
                            // child.updateHints;
                        rebuild;
                        return;
                    }
                }
            }
        }
    }

    override void tryMerge(){
        auto activeContainer = clientActive >= 0 && clientActive < children.length
                               ? cast(Container)children[clientActive]
                               : null;
        while(activeContainer.children.length == 1){
            with(Log("split.flatten")){
                activeContainer.parent = null;
                children[clientActive] = activeContainer.children[activeContainer.clientActive];
                children[clientActive].parent = this;
                activeContainer.children = [];
                activeContainer.destroy;
                activeContainer = cast(Container)children[clientActive];
                rebuild;
            }
        }
    }

    override Client[] clients(){
        Client[] res;
        foreach(c; children)
            res ~= (cast(Container)c).clients;
        return res;
    }

    override void move(int[2] pos){
        super.move(pos);
        rebuild;
    }

    override void resize(int[2] size){
        with(Log("split.resize %s".format(size))){
            super.resize(size);
            //if(_draw)
            //	draw.resize(size);
            rebuild;
        }
    }

    void normalize(){
        auto padding = config.split.padding;
        auto spacing = config.split.spacing;
        long max = (horizontal ? size.w : size.h)
                   - spacing*(children.length-1)
                   - padding*2;
        max = max.max(400);
        foreach(ref s; sizes)
            s = s.min(max).max(10);
        double cur = sizes.sum;
        foreach(ref s; sizes)
            s = (s*max/cur).lround;
        /+
        foreach(i, ref s; sizes){
            auto minw = cast(long)(cast(Client)children[i]).minw;
            if(minw > 10 && minw < max && s < minw)
                s = minw;
        }
        +/
        cur = sizes.sum;
        foreach(ref s; sizes){
            auto old = s;
            s = (s*max/cur).lround;
        }
        "split.normalize %s".format(sizes).log;
    }

    void rebuild(){
        if(lock)
            return;
        background.moveResize(pos, size);
        auto padding = config.split.padding;
        with(Log("split.rebuild")){
            normalize;
            int offset = padding;
            auto spacing = config.split.spacing;
            foreach(i, c; children){
                c.move(pos.a + (horizontal
                                ? [offset, padding].a
                                : [padding, offset].a));
                c.resize(horizontal
                         ? [cast(int)sizes[i], size.h-padding*2]
                         : [size.w-padding*2, cast(int)sizes[i]]);
                offset += cast(int)sizes[i]+spacing;
                if(i != children.length-1){
                    if(horizontal)
                        separators[i].moveResize(c.pos.a+[c.size.w,0], [spacing, c.size.h]);
                    else
                        separators[i].moveResize(c.pos.a+[0,c.size.h], [c.size.w, spacing]);
                }
            }
        }
    }

    override Client clientDir(int[2] direction){
        auto shift = horizontal ? direction.x : direction.y;
        if(shift && clientActive+shift >= 0 && clientActive+shift < children.length){
            return children[clientActive+shift].to!Container.active;
        }else{
            return (cast(Container)parent).clientDir(direction);
        }
    }

    Client clientContainerDir(string direction){
        auto target = clientActive + (direction == "right" ? 1 : -1);
        if(target < 0 || target >= children.length)
            return null;
        return children[target].to!Container.active;
    }

    @property
    override Client active(){
        if(clientActive >= 0 && clientActive < children.length)
            return children[clientActive].to!Container.active;
        return null;
    }

    @property
    override void active(Client client){
        foreach(i, c; children.map!(a=>a.to!Container).array){
            if(c.clients.canFind(client)){
                clientActive = cast(int)i;
                c.active = client;
            }
        }
    }

}
