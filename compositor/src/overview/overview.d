module composite.overview.overview;

import
    std.range,

    common.event,
    common.log,

    composite,
    composite.events,
    composite.overview.window,
    composite.overview.dock;


bool nodraw(CompositeClient client){
    return client.properties.overviewHide.value
           || (client.destroyed && client.animation.fade.calculate < 0.00001);
}


class Overview {

    CompositeManager manager;
    OverviewWindow window;
    ActiveContainerIndicator activeContainer;
    bool doOverview = false;
	double state = 0;
    bool cleanup;
    bool resetPos;
    CompositeClient[] zoomList;
    double lastDamage = 0;
	bool doLayout;
    bool canSwitchWorkspace = true;

	Dock dock;

    Properties!(
        "workspaceNames", "_NET_DESKTOP_NAMES", XA_STRING, false,
        "workspace", "_NET_CURRENT_DESKTOP", XA_CARDINAL, false,
        "workspaces", "_NET_NUMBER_OF_DESKTOPS", XA_CARDINAL, false,
        "workspaceCount", "_NET_NUMBER_OF_DESKTOPS", XA_CARDINAL, false,
        "overview", "_FLATMAN_OVERVIEW", XA_CARDINAL, false,
		"windowActive", "_NET_ACTIVE_WINDOW", XA_WINDOW, false,
        "workspaceSort", "_FLATMAN_WORKSPACE_HISTORY", XA_CARDINAL, true,
        "workspaceEmpty", "_FLATMAN_WORKSPACE_EMPTY", XA_CARDINAL, true
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
				if([Atoms._FLATMAN_TAB, Atoms._FLATMAN_TABS, Atoms._NET_ACTIVE_WINDOW,
                        Atoms._FLATMAN_WORKSPACE_HISTORY, Atoms._FLATMAN_WORKSPACE_EMPTY,
                        Atoms._NET_NUMBER_OF_DESKTOPS].canFind(e.xproperty.atom)){
					doLayout = true;
				}
			},
			ConfigureNotify: (XEvent* e){ doLayout = true; },
            DestroyNotify: (XEvent* e){ doLayout = true; }
		]);
        properties.workspaceNames ~= (string names){ workspaceNames = names.split("\0"); };
        properties.update;
        properties.workspace ~= (long){
            canSwitchWorkspace = true;
        };
        properties.overview ~= (long activate){
            if(activate)
                start(true);
            else
                stop(true);
        };
        window = new OverviewWindow(this);
        wm.add(window);
		properties.windowActive ~= (l){};
        activeContainer = new ActiveContainerIndicator;
    }

    bool visible(){
        return state >= 0.0000001;
    }

    void start(bool now=false){

        enum GRAB_MASK =
            ButtonPressMask | ButtonReleaseMask | PointerMotionMask
            | FocusChangeMask | EnterWindowMask | LeaveWindowMask;

        if(now){
            with(Log("overview.start")){
                resetPos = true;
                prefill;
                doOverview = true;
                window.show;
                window.active = true;
                window.move([0, 0]);
                window.resize([manager.width, manager.height]);
                XSync(wm.displayHandle, False);
                XSetInputFocus(wm.displayHandle, window.windowHandle, RevertToPointerRoot, CurrentTime);
                XRaiseWindow(wm.displayHandle, window.windowHandle);

                cleanup = true;
                zoomList = [];
                foreach(c; manager.clients ~ manager.destroyed){
                    if(!c.hidden)
                        zoomList ~= c;
                }
            }
        }else{
            properties.overview.request([2, 1, CurrentTime]);
        }
    }

    void stop(bool now=false){
        if(now){
            with(Log("overview.stop")){
                doOverview = false;
                zoomList = [];
                foreach(c; manager.clients ~ manager.destroyed){
                    if(!c.hidden)
                        zoomList ~= c;
                }
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

    private void prefill2(){
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
                    w.animation = client.overviewAnimation; //new OverviewAnimation(client.pos, client.size); // TODO: keep windows around so we don't have to use a "global" window attribute
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
                if(w.window is null || w.window.animation.rect.size.w == 0)
                    continue;
                auto targetWidth = w.window.size.w/(i/4.0+1.5);
                auto aspect = w.window.size.h.to!double/w.window.size.w;
                int[2] size = [targetWidth.to!int, (targetWidth*aspect).to!int];
                int[2] pos = [(group.pos.x + group.size.w/2 - size.w/2).to!int,
                              (group.pos.y - group.size.h/6*(sqrt(i.to!double*1.5) - sqrt(sorted.length.to!double))).to!int];
                w.targetPos = pos;
                w.targetSize = size;
                w.targetAlpha = 1;
                dock.calc(w);
                if(resetPos){
                    w.animation.pos.replace(w.targetPos);
                    w.animation.size.replace(w.targetSize);
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

    private void prefill(){

        auto allMonitors = manager.screens
            .byPair
            .map!(a => new Monitor([a.value.x, a.value.y], [a.value.w, a.value.h], a.key));
        monitors = monitors.filter!(a => allMonitors.canFind!"a.pos == b.pos"(a)).array;
        monitors ~= allMonitors.filter!(a => !monitors.canFind!"a.pos == b.pos"(a)).array;

        activeContainer.targetPos = [-10, -10];
        activeContainer.targetSize = [manager.width+20, manager.height+20];

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
            if(client.a.override_redirect)
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
                    w.animation = client.overviewAnimation; //new OverviewAnimation(client.pos, client.size); // TODO: keep windows around so we don't have to use a "global" window attribute
                    ws.windows ~= w;
                }
            }
        }
        struct Group {
            int width;
            WinInfo[] windows;
        }
        auto strut = [0.5/20, 0.5/20, 1.0/30, 1.0/7.5];
        foreach(ref monitor; monitors){
            auto mstrut = [strut[0]*monitor.size.w, strut[1]*monitor.size.w, strut[2]*monitor.size.h, strut[3]*monitor.size.h];
            auto msize = [monitor.size.w - mstrut[0] - mstrut[1],
                          monitor.size.h - mstrut[2] - mstrut[3]];
            auto mpos = [monitor.pos.x + mstrut[0],
                         monitor.pos.y + mstrut[2]];
            foreach(ref ws; monitor.workspaces){
                Group[long] groups;
                foreach(w; ws.windows){
                    if(nodraw(w.window))
                        continue;
                    auto tabs = w.window.properties.tabs.value.max(0);
                    if(tabs == 0 && (w.window.hidden || !w.window.picture))
                        continue;
                    if(tabs !in groups){
                        groups[tabs] = Group();
                    }
                    groups[tabs].windows ~= w;
                }

                long unscaledWidth;
                foreach(ref group; groups){
                    long sum = 0;
                    foreach(window; group.windows){
                        sum += window.window.size.w.to!int;
                    }
                    group.width = sum/group.windows.length.to!long;
                    unscaledWidth += group.width;
                }
                auto containerScale = (unscaledWidth.to!double / msize.w);

                auto splitPadding = [msize.w/40.0, msize.h/80.0 + 30];
                import std.typecons: tuple;
                int offsetX;
                foreach(k, v; sort(groups.keys).map!(a => tuple(a, groups[a]))){
                    
                    int[2] smallestWindow = [int.max, int.max];
                    foreach(window; v.windows){
                        if(window.window.size.w < smallestWindow.w)
                            smallestWindow.w = window.window.size.w;
                        if(window.window.size.h < smallestWindow.h)
                            smallestWindow.h = window.window.size.h;
                    }

                    auto width = (v.width/containerScale).floor - splitPadding.w;
                    auto height = msize.h - splitPadding.h;
                    ws.separators ~= offsetX+width.min(monitor.size.w).to!int;
                    auto count = v.windows.length.to!double;
                    auto columns = sqrt(count).ceil.lround.to!double;
                    auto rows = (v.windows.length / columns).ceil;

                    auto padding = [10, 25];//[msize.w/40.0, msize.h/40];

                    auto scale = ((smallestWindow.w*columns)/(width - padding.w*(1 + columns)))
                                .max((smallestWindow.h*rows)/(height - padding.h*(1 + rows)));
                    
                    auto cellWidth = smallestWindow.w/scale;
                    auto cellHeight = smallestWindow.h/scale;
                    
                    foreach(i, w; v.windows){
                        if(w.window.size.w == 0)
                            continue;
                        auto maxY = ((count/columns).ceil)*(cellHeight+padding.h)-padding.h;
                        auto offsetY = msize.h/2-maxY/2;
                        if(w.window.windowHandle == properties.windowActive.value){
                            auto splitPos = [
                                (offsetX + mpos.x + splitPadding.w/2 + padding.w).to!int,
                                (manager.height - height - (mpos.y + splitPadding.h/2)).to!int
                            ];
                            activeContainer.targetSize = [
                                ((cellWidth + padding.w)*columns + padding.w).lround.to!int,
                                ((cellHeight + padding.h)*rows + padding.w).lround.to!int
                            ];
                            activeContainer.targetPos = [
                                (mpos.x
                                    + offsetX
                                    + splitPadding.w/2 + padding.w
                                    + (width - activeContainer.targetSize.w)/2
                                ).lround.to!int,
                                (
                                    manager.height - activeContainer.targetSize.h - (mpos.y + offsetY - 4)
                                    + splitPadding.h/2
                                ).lround.to!int
                            ];
                        }
                        auto index = k == 0 ? i : w.window.properties.tab;
                        auto cell = [
                            (mpos.x
                                + offsetX
                                + (width - (cellWidth + padding.w)*columns)/2 + padding.w/2
                                + (splitPadding.w/2 + padding.w + (index % columns)*(cellWidth+padding.w))
                                ).lround.to!int,
                            (mpos.y
                                + offsetY
                                + (index / columns).floor*(cellHeight+padding.h)
                                ).lround.to!int
                        ];
                        auto ratio = 
                                (cellWidth.min(w.window.size.w)/w.window.size.w.to!double)
                                .min(cellHeight.min(w.window.size.h)/w.window.size.h.to!double);
                        w.targetSize = [
                            (w.window.size.w*ratio).lround.to!int,
                            (w.window.size.h*ratio).lround.to!int
                        ];
                        w.targetPos = [
                            cell.x + cellWidth.lround.to!int/2 - w.targetSize.w/2,
                            cell.y + cellHeight.lround.to!int/2 - w.targetSize.h/2
                        ];
                        dock.calc(w);
                        if(resetPos){
                            w.animation.pos.replace(w.targetPos);
                            w.animation.size.replace(w.targetSize);
                        }
                    }
                    offsetX += width.lround.to!int + splitPadding.w.lround.to!int;
                }
                if(ws.separators.length)
                    ws.separators = ws.separators[0..$-1];
            }
        }

        if(resetPos){
            activeContainer.animation.pos.replace(activeContainer.targetPos);
            activeContainer.animation.size.replace(activeContainer.targetSize);
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
					w.animation.approach(w.targetPos, w.targetSize);
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
                    alpha = state.sigmoid * (client.hidden ? 0.99 : 1);
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
            scale = animate(scale, (w.animation.size.w.calculate/size.w)
                                    .min(w.animation.size.h.calculate/size.h), zoom);
            pos = [
                animate(pos.x, w.animation.pos.x.calculate, zoom).lround.to!int,
                animate(pos.y, w.animation.pos.y.calculate, zoom).lround.to!int
            ];
            size = [
                animate(size.w, w.animation.size.w.calculate, zoom).lround.to!int,
                animate(size.h, w.animation.size.h.calculate, zoom).lround.to!int
            ];
        }else{
            if(client.properties.overviewHide.value == 1){
                alpha = alpha*(1-state.sigmoid);
            }
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
        activeContainer.damage(damage);
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


            auto state = state.sigmoid;
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
                backend.setColor([0, 0.2, 0.7, state.sigmoid*alpha]);
                backend.rect([pos.x-10, manager.height-pos.y+10-size.h-20], [size.w+20, size.h+20]);
            }
            +/
			if(client.properties.workspace.value != manager.properties.workspace.value)
				return;
            double flop = client.hidden ? 1*alpha : state.sigmoid*alpha;
            int textHider;
            //if(!client.hidden){
                textHider = -((1-state).sigmoid * 30).lround.to!int;
            //}
            backend.clip([pos.x, manager.height-pos.y], [size.w, 20]);
            /+
            backend.setColor([0, 0, 0, 0.5*state.sigmoid*(client.hidden ? 0.5 : 1)]);
            backend.rect([pos.x, manager.height-pos.y], [size.w, 20]);
            +/
            backend.setColor([flop,flop,flop,flop]);
            backend.text([pos.x+size.w/2, manager.height-pos.y+textHider+2], 20, client.title, 0.5);
            backend.noclip;
        }
	}

	void drawPost(Backend backend, CompositeClient client, int[2] pos, double[2] offset, int[2] size, double scale, double alpha){
        if(!visible || client.a.override_redirect || nodraw(client))
            return;
        with(Profile("overview")){
            double flop = state.sigmoid*alpha;
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

    void draw(Backend backend, CompositeClient[] windows){

        /+
        foreach(w; windows){
            if(w.properties.workspace.value == properties.workspace.value){
                drawPre(backend, w, w.animPos, w.animOffset, w.animSize, w.animScale, w.animAlpha);
                .draw(backend, w);
                drawPost(backend, w, w.animPos, w.animOffset, w.animSize, w.animScale, w.animAlpha);
            }
        }
        +/

        activeContainer.draw(backend);
		dock.draw(backend, state, monitors, workspaceNames);

        foreach(w; windows){
            //if(w.properties.workspace.value != properties.workspace.value){
                drawPre(backend, w, w.animPos, w.animOffset, w.animSize, w.animScale, w.animAlpha);
                .draw(backend, w);
                drawPost(backend, w, w.animPos, w.animOffset, w.animSize, w.animScale, w.animAlpha);
            //}
        }

        /+
        foreach(ref m; monitors){
            foreach(wsi, ws; m.workspaces){
                if(wsi != manager.properties.workspace.value)
                    continue;
                auto y = manager.height - m.size.h - m.pos.y;
                with(Profile("Sep")){
                    foreach(sep; ws.separators){
                        backend.setColor([0.5,0.5,0.5,0.3*state^^2]);
                        backend.rect([sep-1+m.pos.x, y + m.size.h/20-1], [4, m.size.h-m.size.h/10+2]);
                        backend.setColor([0,0,0,0.3*state^^2]);
                        backend.rect([sep+m.pos.x, y + m.size.h/20], [2, m.size.h-m.size.h/10]);
                    }
                }
            }
        }
        +/

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
                        backend.setColor([0.5,0.5,0.5,0.3*state^^2]);
                        backend.rect([sep-1+m.pos.x, y + m.size.h/20-1], [4, m.size.h-m.size.h/10+2]);
                        backend.setColor([0,0,0,0.3*state^^2]);
                        backend.rect([sep+m.pos.x, y + m.size.h/20], [2, m.size.h-m.size.h/10]);
                    }
                }
            }
        }
		+/
    }

    void onMouseButton(Mouse.button button, bool pressed, int x, int y){

        if(pressed && (button == Mouse.wheelDown || button == Mouse.wheelUp)){

            if(true){
                auto current = properties.workspaceSort.value.countUntil(properties.workspace.value);
                auto next = current + (button == Mouse.wheelDown ? 1 : -1);
                if(next < 0)
                    next = properties.workspaceSort.value.length-1;
                else if(next >= properties.workspaceSort.value.length)
                    next = 0;
                if(canSwitchWorkspace && next >= 0 && next < properties.workspaceSort.value.length){
                    canSwitchWorkspace = false;
                    properties.workspace.request([properties.workspaceSort[next], CurrentTime]);
                }
            }else{
                auto selectedWorkspace = properties.workspace.value + (button == Mouse.wheelDown ? 1 : -1);
                if(canSwitchWorkspace && selectedWorkspace >= 0 && selectedWorkspace < properties.workspaces.value){
                    canSwitchWorkspace = false;
                    properties.workspace.request([selectedWorkspace, CurrentTime]);
                }
            }
        }

        dock.onMouseButton(button, pressed, x, y);
    }

    void onMouseMove(int x, int y){
        dock.onMouseMove(x, y);
    }

}


class ActiveContainerIndicator: Widget {

    int[2] targetPos;
    int[2] targetSize;

    OverviewAnimation animation;

    double state;

    this(){
        animation = new OverviewAnimation(pos, size);
        Events ~= this;
    }

    ~this(){
        Events.forget(this);
    }

    @OverviewState
    void onState(double state){
        if(state == this.state)
            return;
        this.state = state;
        damage;
    }

    @Tick
    void onTick(){
        animation.approach(targetPos, targetSize);
        move(animation.pos.calculate);
        resize(animation.size.calculate);
    }

    void draw(Backend backend){
        enum border = 4;
        backend.setColor([1, 1, 1, state]);
        backend.rect([pos.x, pos.y], [border, size.h]);
        backend.rect([pos.x+size.w-border, pos.y], [border, size.h]);
        backend.rect([pos.x+border, pos.y], [size.w-border*2, border]);
        backend.rect([pos.x+border, pos.y+size.h-border], [size.w-border*2, border]);
    }

}


double sigmoid(double time){
    return 1/(1 + E^^(6 - time*12));
}

