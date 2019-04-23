module composite.overview.overview;

import
    composite,
    composite.overview.window,
    composite.overview.dock;

import std.range;



bool nodraw(CompositeClient client){
    return client.properties.overviewHide.value
           || (client.destroyed && client.animation.fade.calculate < 0.00001);
}


class Overview {

    CompositeManager manager;
    OverviewWindow window;
    bool doOverview = false;
	double state = 0;
    bool cleanup;
    bool resetPos;
    CompositeClient[] zoomList;
    double lastDamage = 0;
	bool doLayout;

	Dock dock;

    Properties!(
        "workspaceNames", "_NET_DESKTOP_NAMES", XA_STRING, false,
        "workspace", "_NET_CURRENT_DESKTOP", XA_CARDINAL, false,
        "workspaceCount", "_NET_NUMBER_OF_DESKTOPS", XA_CARDINAL, false,
        "overview", "_FLATMAN_OVERVIEW", XA_CARDINAL, false,
		"windowActive", "_NET_ACTIVE_WINDOW", XA_WINDOW, false,
        "workspaceSort", "_FLATMAN_WORKSPACE_HISTORY", XA_CARDINAL, true
    ) properties;

    string[] workspaceNames;

    Monitor[] monitors;

    this(CompositeManager manager){
		dock = new Dock(this);
        this.manager = manager;
        properties.window(.root);
        wm.on(.root, [
            PropertyNotify: (XEvent* e) => properties.update(&e.xproperty)
        ]);
		wm.on([
			PropertyNotify: (XEvent* e){
				if([Atoms._FLATMAN_TAB, Atoms._FLATMAN_TABS].canFind(e.xproperty.atom)){
					doLayout = true;
				}
			},
			ConfigureNotify: (XEvent* e){ doLayout = true; }
		]);
        properties.workspaceNames ~= (string names){ workspaceNames = names.split("\0"); };
        properties.update;
        properties.overview ~= (long activate){
            if(activate)
                start(true);
            else
                stop(true);
        };
        window = new OverviewWindow(this);
        wm.add(window);
		properties.windowActive ~= (l){};
    }

    bool visible(){
        return state >= 0.0000001;
    }

    void start(bool now=false){

        enum GRAB_MASK =
            ButtonPressMask | ButtonReleaseMask | PointerMotionMask
            | FocusChangeMask | EnterWindowMask | LeaveWindowMask;

        if(now){
            resetPos = true;
			prefill;
            doOverview = true;
            window.show;
            window.active = true;
            window.move([0, 0]);
            window.resize([manager.width, manager.height]);
            //XSetInputFocus(wm.displayHandle, window.windowHandle, RevertToPointerRoot, CurrentTime);
            // TODO: reenable and fix input not returning to active window

            XGrabPointer(
                    wm.displayHandle,
                    window.windowHandle,
                    True,
                    GRAB_MASK,
                    GrabModeAsync,
                    GrabModeAsync,
                    None,
                    None,
                    CurrentTime
            );
            XGrabButton(wm.displayHandle, AnyButton, AnyModifier, window.windowHandle, False,
                        ButtonPressMask | ButtonReleaseMask, GrabModeAsync, GrabModeAsync, None, None);

            cleanup = true;
            zoomList = [];
            foreach(c; manager.clients ~ manager.destroyed){
                if(!c.hidden)
                    zoomList ~= c;
            }
        }else{
            properties.overview.request([2, 1, CurrentTime]);
        }
    }

    void stop(bool now=false){
        if(now){
            doOverview = false;
            //window.hide;
            XUngrabButton(wm.displayHandle, AnyButton, AnyModifier, window.windowHandle);
            XUngrabPointer(wm.displayHandle, CurrentTime);
            //XSetInputFocus(wm.displayHandle, .root, RevertToPointerRoot, CurrentTime);
            zoomList = [];
            foreach(c; manager.clients ~ manager.destroyed){
                if(!c.hidden)
                    zoomList ~= c;
            }
        }else{
            properties.overview.request([2, 0, CurrentTime]);
        }
    }

    class Monitor {
        int[2] pos;
        int[2] size;
        size_t index;
        Workspace[] workspaces;
        this(int[2] pos, int[2] size, size_t index){
            this.pos = pos;
            this.size = size;
            this.index = index;
        }
    }

    class Workspace {
        int[2] pos;
        int[2] size;
        string name;
        int[] separators;
        WinInfo[] windows;
    }

    class WinInfo {
        int[2] targetPos;
        int[2] targetSize;
        double targetAlpha = 1;
        double alpha = 1;
        OverviewAnimation animation;
        CompositeClient window;
        this(CompositeClient window){
            this.window = window;
        }
    }

    /+
    private void prefill(){
        auto allMonitors = manager.screens
            .byPair
            .map!(a => new Monitor([a.value.x, a.value.y], [a.value.w, a.value.h], a.key));
        monitors = monitors.filter!(a => allMonitors.canFind!"a.pos == b.pos"(a)).array;
        monitors ~= allMonitors.filter!(a => !monitors.canFind!"a.pos == b.pos"(a)).array;

        foreach(monitor; monitors){
            auto count = properties.workspaceCount.value;
            while(monitor.workspaces.length < count)
                monitor.workspaces ~= new Workspace;
            while(monitor.workspaces.length >= count)
                monitor.workspaces = monitor.workspaces[0..$-1];
        }

        foreach(m; monitors){
            foreach(ws; m.workspaces){
                ws.windows = [];
            }
        }

        foreach(client; manager.clients ~ manager.destroyed){
            if(client.a.override_redirect && client.properties.overviewHide.value != 1)
                continue;
            if(client.hidden && client.floating)
                continue;
            foreach(m; monitors){
                if(m.index != manager.screens.findScreen(client.pos, client.size))
                    continue;
                foreach(i, ws; m.workspaces){
                    if(i != client.properties.workspace.value)
                        continue;
                    auto w = new WinInfo(client);
                    w.animation = new OverviewAnimation(client.pos, client.size);
                    ws.windows ~= w;
                }
            }
        }
        struct Group {
            int width;
            int[2] pos;
            int[2] size;
            WinInfo[] windows;
        }
        auto strut = [0.5/7.5, 0.5/7.5, 1.0/40, 1.0/7.5];

        auto layoutGroup(ref Group group){
            //ws.separators ~= group.size.w;

            auto sorted = group.windows;
            sorted.sort!((a, b) => a.window.properties.tab.value < b.window.properties.tab.value);
            auto split = sorted.countUntil!(a => !a.window.hidden);
            if(split >= sorted.length || split < 0)
                split = 0;

            foreach(i, w; sorted[split..$]){
                if(w.window is null || w.window.animation.size.w == 0)
                    continue;
                auto targetWidth = w.window.size.w/(i/2.0+1.5);
                auto aspect = w.window.animation.size.h/w.window.animation.size.w;
                int[2] size = [targetWidth.to!int, (targetWidth*aspect).to!int];
                int[2] pos = [(group.pos.x + group.size.w/2 - size.w/2).to!int,
                              ((group.pos.y + group.size.h/2)/sqrt(i+1.0) - group.size.h/6).to!int];
                w.targetPos = pos;
                w.targetSize = size;
                w.targetAlpha = 1;
                dock.calc(w);
                if(resetPos){
                    w.window.overviewAnimation.pos = w.targetPos.to!(double[]);
                    w.window.overviewAnimation.size = w.targetSize.to!(double[]);
                }
            }
            foreach(i, w; sorted[0..split]){
                w.targetPos = [group.pos.x, group.pos.y + group.size.h];
                w.targetSize = [group.size.w, group.size.h];
                w.targetAlpha = 0;
            }
        }

        auto layoutWorkspace(ref Workspace workspace){
            Group[long] groups;
            long unscaledWidth;
            foreach(w; workspace.windows){
                if(nodraw(w.window))
                    continue;
                auto tabs = w.window.properties.tabs.value.max(0);
                if(tabs == 0 && (w.window.hidden || !w.window.picture))
                    continue;
                if(tabs !in groups){
                    auto width = tabs > 0 ? w.window.size.w : (workspace.size.w/5).to!int;
                    groups[tabs] = Group(width);
                    unscaledWidth += width;
                }
                groups[tabs].windows ~= w;
            }
            auto containerScale = (unscaledWidth.to!double / workspace.size.w);
            int offsetX = workspace.pos.x;
            import std.typecons;
            foreach(groupIndex, group; sort(groups.keys).map!(a => tuple(a, groups[a]))){
                auto width = (group.width/containerScale).floor;
                group.pos = [offsetX, workspace.pos.y];
                group.size = [width.to!int, (workspace.size.h).to!int];
                layoutGroup(group);
                offsetX += group.size.w;// width.to!int;
            }
            //if(ws.separators.length)
            //    ws.separators = ws.separators[0..$-1];
        }

        auto layoutMonitor(ref Monitor monitor){
            auto mstrut = [strut[0]*monitor.size.w, strut[1]*monitor.size.w,
                           strut[2]*monitor.size.h, strut[3]*monitor.size.h];
            auto size = [monitor.size.w - mstrut[0] - mstrut[1],
                          monitor.size.h - mstrut[2] - mstrut[3]];
            auto pos = [monitor.pos.x + mstrut[0],
                         monitor.pos.y + mstrut[2]];
            foreach(ref ws; monitor.workspaces){
                ws.pos = pos.to!(int[2]);
                ws.size = size.to!(int[2]);
                layoutWorkspace(ws);
            }
        }

        foreach(ref monitor; monitors){
            layoutMonitor(monitor);
        }
        resetPos = false;
    }
    +/

    private void prefill(){

        auto allMonitors = manager.screens
            .byPair
            .map!(a => new Monitor([a.value.x, a.value.y], [a.value.w, a.value.h], a.key));
        monitors = monitors.filter!(a => allMonitors.canFind!"a.pos == b.pos"(a)).array;
        monitors ~= allMonitors.filter!(a => !monitors.canFind!"a.pos == b.pos"(a)).array;

        foreach(monitor; monitors){
            auto count = properties.workspaceCount.value;
            while(monitor.workspaces.length < count)
                monitor.workspaces ~= new Workspace;
            while(monitor.workspaces.length > count)
                monitor.workspaces = monitor.workspaces[0..$-1];
        }

        foreach(m; monitors){
            foreach(ws; m.workspaces){
                ws.windows = [];
            }
        }

        foreach(client; manager.clients ~ manager.destroyed){
            if(client.a.override_redirect && client.properties.overviewHide.value != 1)
                continue;
            if(client.hidden && client.floating)
                continue;
            foreach(m; monitors){
                if(m.index != manager.screens.findScreen(client.pos, client.size))
                    continue;
                foreach(i, ws; m.workspaces){
                    if(i != client.properties.workspace.value)
                        continue;
                    auto w = new WinInfo(client);
                    w.animation = new OverviewAnimation(client.pos, client.size);
                    ws.windows ~= w;
                }
            }
        }
        struct Group {
            int width;
            WinInfo[] windows;
        }
        auto strut = [0.5/7.5, 0.5/7.5, 1.0/40, 1.0/7.5];
        foreach(ref monitor; monitors){
            auto mstrut = [strut[0]*monitor.size.w, strut[1]*monitor.size.w, strut[2]*monitor.size.h, strut[3]*monitor.size.h];
            auto msize = [monitor.size.w - mstrut[0] - mstrut[1],
                          monitor.size.h - mstrut[2] - mstrut[3]];
            auto mpos = [monitor.pos.x + mstrut[0],
                         monitor.pos.y + mstrut[2]];
            foreach(ref ws; monitor.workspaces){
                Group[long] groups;
                long unscaledWidth;
                foreach(w; ws.windows){
                    if(nodraw(w.window))
                        continue;
                    auto tabs = w.window.properties.tabs.value.max(0);
                    if(tabs == 0 && (w.window.hidden || !w.window.picture))
                        continue;
                    if(tabs !in groups){
                        auto width = tabs > 0 ? w.window.size.w.to!int : (msize.w/5).to!int;
                        groups[tabs] = Group(width);
                        unscaledWidth += width;
                    }
                    groups[tabs].windows ~= w;
                }
                auto containerScale = (unscaledWidth.to!double / msize.w);
                import std.typecons;
                int offsetX;
                foreach(k, v; sort(groups.keys).map!(a => tuple(a, groups[a]))){
                    auto width = (v.width/containerScale).floor;
                    ws.separators ~= offsetX+width.min(monitor.size.w).to!int;
                    auto count = v.windows.length.to!double;
                    auto columns = k == 0 && groups.length > 1 ? 1 : sqrt(count).ceil.lround.to!double;
                    auto padding = [msize.w/40.0, msize.h/40];
                    foreach(w; v.windows){
                        if(w.window.animation.size.w == 0)
                            continue;
                        auto cellWidth = ((width-padding.w).max(1)/columns-padding.w).max(1).min(monitor.size.w);
                        auto targetWidth = cellWidth.min(w.window.size.w);
                        auto cellHeight = (w.window.animation.size.h*cellWidth/w.window.animation.size.w).to!int;
                        auto scale = w.window.animation.size.h/w.window.animation.size.w;
                        int[2] size = [
                            targetWidth.to!int,
                            (targetWidth*scale).to!int
                        ];
                        auto maxY = ((count/columns).ceil)*(size.h+padding.h)-padding.h;
                        auto offsetY = msize.h/2-maxY/2;
                        int[2] pos = [
                            (mpos.x
                                + offsetX
                                + (padding.w + (w.window.properties.tab % columns)*(cellWidth+padding.w))
                                ).to!int,
                            (mpos.y
                                + (w.window.properties.tab / columns).floor*(cellHeight+padding.h)
                                + offsetY
                                ).to!int
                        ];
                        w.targetPos = pos;
                        w.targetSize = size;
                        dock.calc(w);
                        if(resetPos){
                            w.window.overviewAnimation.pos = w.targetPos.to!(double[]);
                            w.window.overviewAnimation.size = w.targetSize.to!(double[]);
                        }
                    }
                    offsetX += width.to!int;
                }
                if(ws.separators.length)
                    ws.separators = ws.separators[0..$-1];
            }
        }
        resetPos = false;
    }

    void tick(){
        if(!doOverview && !visible && window.active){
            window.hide;
            window.active = false;
        }
        if(!visible){
            return;
        }
		if(doLayout){
			prefill;
			doLayout = false;
		}
        foreach(m; monitors){
			foreach(ws; m.workspaces){
				foreach(w; ws.windows){
					w.window.overviewAnimation.approach(w.targetPos, w.targetSize);
                    w.alpha = w.alpha.rip(w.targetAlpha, 1, 5, manager.frameTimer.dur/60.0*config.animationSpeed);
				}
			}
		}
    }

    void find(CompositeClient client, void delegate(Monitor, Workspace) dg, void delegate() notfound=null){
        foreach(m; monitors)
            foreach(wsi, ws; m.workspaces)
                foreach(w; ws.windows)
                    if(w.window == client){
                        dg(m, ws);
                        return;
                    }
        if(notfound)
            notfound();
    }

    bool find(CompositeClient client, ref WinInfo win){
        foreach(m; monitors)
            foreach(wsi, ws; m.workspaces)
                foreach(w; ws.windows)
                    if(w.window == client){
						win = w;
                        return true;
					}
        return false;
    }

	void calcWindow(CompositeClient client, ref int[2] pos, ref double[2] offset, ref int[2] size,
                    ref double scale, ref double alpha, ref double ghostAlpha){
        if(!visible)
            return;
		WinInfo w;
        if(find(client, w)){
            double zoom;
            if(!client.destroyed){
				auto active = properties.windowActive.value == client.windowHandle ? 1 : 1-state.sigmoid*0.25;
                if(state < 0.99999 && zoomList.canFind(client) && client.properties.workspace.value == manager.properties.workspace.value){
                    zoom = state.sigmoid;
                    alpha = 0.75 + alpha*0.25;
                }else{
                    zoom = 1;
                    alpha = state.sigmoid * (client.hidden ? 0.9 : 1);
                }
                if(client.properties.workspace.value < 0 || client.properties.overviewHide.value == 1){
                    alpha = (1-zoom*2).max(0)^^2;
                    return;
                }
                alpha *= w.alpha;
            }else{
                zoom = 1;
            }
            //alpha = alpha * (1 - (w.window.properties.workspace.value.to!int-manager.properties.workspace.value).abs.min(1).max(0));
            scale = animate(scale, (client.overviewAnimation.size.w/size.w.to!double).min(client.overviewAnimation.size.h.to!double/size.h), zoom);
            pos = [
                animate(pos.x, client.overviewAnimation.pos.x, zoom).lround.to!int,
                animate(pos.y, client.overviewAnimation.pos.y, zoom).lround.to!int
            ];
            size = [
                animate(size.w, client.overviewAnimation.size.w, zoom).lround.to!int,
                animate(size.h, client.overviewAnimation.size.h, zoom).lround.to!int
            ];
        }else{
            //alpha = animate(alpha, 0, state.sigmoid);
        }
	}

    long damageWorkspace;

    void damage(RootDamage damage){
        if(state > 0 && state < 1 || cleanup){
            damage.damage([0,0], [manager.width, manager.height]);
            if(state > 0 && state < 1)
                cleanup = true;
            else
                cleanup = false;
            return;
        }
        if(!visible)
            return;
        dock.damage(damage);
        auto workspace = manager.properties.workspace.value;
        if(lastDamage > now-0.5 && workspace == damageWorkspace){
            return;
        }
        damageWorkspace = workspace;
        lastDamage = now;
		/+
        foreach(ref m; monitors){
            int max;
            foreach(i, frt; frameTimes){
                auto height = (frt*1000).lround.to!int;
                if(max < height)
                    max = height;
            }
            auto fps30 = (1.0/30*1000).lround.to!int;
            damage.damage(
                [m.pos.x+m.size.w/2-5,
                 m.size.h - 10 - 2*fps30],
                [100,
                 2*fps30]
            );


            auto state = state.sinApproach;
            auto y = manager.height - m.pos.y - m.size.h;
            auto maxDockHeight = m.size.h - 50.0 - 20*m.workspaces.length;
            auto scale = (1/7.5).min(maxDockHeight/m.workspaces.length/m.size.h);
            auto ssize = [m.size.w*scale, m.size.h*scale];
            auto height = (ssize.h+20)*m.workspaces.length;
            auto width = (m.size.w*scale*state).lround.to!int;
            damage.damage(
                [m.pos.x + m.size.w - (m.size.w*scale*state).lround.to!int - 10,
                 (m.size.h/2-height/2 - 10).lround.to!int],
                [width + 10,
                 height.lround.to!int]
            );
        }
		+/
    }

	void drawPre(Backend backend, CompositeClient client, int[2] pos, double[2] offset, int[2] size, double scale, double alpha){
        if(!visible || client.a.override_redirect || !client.title.length || nodraw(client))
            return;
        with(Profile("overview draw pre")){
            /+ TODO: proper gui damage system
            if(client.windowHandle == manager.properties.activeWin.value){
                backend.setColor([0, 0.2, 0.7, state.sinApproach*alpha]);
                backend.rect([pos.x-10, manager.height-pos.y+10-size.h-20], [size.w+20, size.h+20]);
            }
            +/
			if(client.properties.workspace.value != manager.properties.workspace.value)
				return;
            double flop = client.hidden ? 1*alpha : state.sinApproach*alpha;
            int textHider;
            if(!client.hidden){
                textHider = -((1-state) * 30).lround.to!int;
            }
            backend.clip([pos.x, manager.height-pos.y], [size.w, 20]);
            backend.setColor([0, 0, 0, 0.5*state.sinApproach*(client.hidden ? 0.5 : 1)]);
            backend.rect([pos.x, manager.height-pos.y], [size.w, 20]);
            backend.setColor([flop,flop,flop,flop]);
            backend.text([pos.x+size.w/2, manager.height-pos.y+textHider+2], 20, client.title, 0.5);
            backend.noclip;
        }
	}

	void drawPost(Backend backend, CompositeClient client, int[2] pos, double[2] offset, int[2] size, double scale, double alpha){
        if(!visible || client.a.override_redirect || nodraw(client))
            return;
        with(Profile("overview")){
            double flop = state.sinApproach*alpha;
            WinInfo w;
            if(find(client, w)){
                flop *= w.alpha;
            }
            if(client.hidden){
                backend.setColor([0,0,0,0.3*flop]);
                backend.rect([pos.x, manager.height-pos.y-size.h], size);
            }
        }
	}

    void draw(Backend backend, CompositeClient c){

        drawPre(backend, c, c.animPos, c.animOffset, c.animSize, c.animScale, c.animAlpha);
    
        if(c.picture){
            auto w1 = c.animSize.w/c.size.w.to!double;
            auto h1 = c.animSize.h/c.size.h.to!double;
            c.picture.scale([w1, h1]);
        }

        double transition = 1;

        if(c.ghost && c.animation.size != c.size){
            transition = ((c.animSize.w - c.ghost.size.w.to!double)/(c.size.x - c.ghost.size.w.to!double)
                          .min((c.animSize.h - c.ghost.size.h.to!double)/(c.size.h - c.ghost.size.h.to!double))
                          ).min(1).max(0);
            auto w = c.animSize.w.to!double/c.ghost.size.w;
            auto h = c.animSize.h.to!double/c.ghost.size.h;
            c.ghost.scale([w, h]);
            backend.render(c.ghost, c.ghost.hasAlpha, (1-transition)*c.animAlpha, c.animOffset.to!(int[2]), c.animPos, c.animSize);
        }

        if(c.picture){
            backend.render(c.picture, c.picture.hasAlpha, c.animAlpha*transition, c.animOffset.to!(int[2]), c.animPos, c.animSize);
        }

        drawPost(backend, c, c.animPos, c.animOffset, c.animSize, c.animScale, c.animAlpha);
    }

    void draw(Backend backend, CompositeClient[] windows){

        foreach(w; windows){
            if(w.properties.workspace.value == properties.workspace.value)
                draw(backend, w);
        }

		dock.draw(backend, state, monitors, workspaceNames);

        foreach(w; windows)
            if(w.properties.workspace.value != properties.workspace.value)
                draw(backend, w);

		/+

        foreach(ref m; monitors){
            with(Profile("Frt")){

                backend.setColor([0.5, 0.5, 0.5, 0.75]);
                backend.text([m.pos.x+m.size.w/2, manager.height - m.size.h - m.pos.y+30], frameTimes.fold!max.to!string, 0);
                /+
                backend.setColor([0.5, 0.5, 0.5, 0.75]);

                if(window && window.windowHit){
                    backend.text([m.pos.x+m.size.w/2, manager.height - m.size.h - m.pos.y+30], window.windowHit.windowHandle.to!string, 0.5);
                }

                foreach(i, frt; frameTimes){
                    auto height = (frt*1000).lround.to!int;
                    backend.rect([m.pos.x+m.size.w/2-frameTimes.size/2+i.to!int, manager.height - m.size.h - m.pos.y + 10], [1, height]);
                }
                auto fps60 = (1.0/60*1000).lround.to!int;
                auto fps30 = (1.0/30*1000).lround.to!int;
                backend.setColor([1, 0.5, 0.5, 0.75]);
                backend.rect([m.pos.x+m.size.w/2-frameTimes.size/2, manager.height - m.size.h - m.pos.y + 10 + fps60], [frameTimes.size, 1]);
                backend.setColor([1, 0, 0, 0.75]);
                backend.rect([m.pos.x+m.size.w/2-frameTimes.size/2, manager.height - m.size.h - m.pos.y + 10 + fps30], [frameTimes.size, 1]);
                +/
            }
            foreach(wsi, ws; m.workspaces){
                if(wsi != manager.properties.workspace.value)
                    continue;
                auto y = manager.height - m.size.h - m.pos.y;
                with(Profile("Sep")){
                    foreach(sep; ws.separators){
                        /+
                        backend.setColor([0.5,0.5,0.5,0.3*state^^2]);
                        backend.rect([sep-1+m.pos.x, y + m.size.h/20-1], [4, m.size.h-m.size.h/10+2]);
                        backend.setColor([0,0,0,0.3*state^^2]);
                        backend.rect([sep+m.pos.x, y + m.size.h/20], [2, m.size.h-m.size.h/10]);
                        +/
                    }
                }
            }
        }
		+/
    }

}


double sigmoid(double time){
    return 1/(1 + E^^(6 - time*12));
}

