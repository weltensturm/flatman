module composite.overview;

import composite;


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

    Properties!(
        "workspaceNames", "_NET_DESKTOP_NAMES", XA_STRING, false,
        "workspace", "_NET_CURRENT_DESKTOP", XA_CARDINAL, false,
        "workspaceCount", "_NET_NUMBER_OF_DESKTOPS", XA_CARDINAL, false,
        "overview", "_FLATMAN_OVERVIEW", XA_CARDINAL, false
    ) properties;

    string[] workspaceNames;

    Monitor[] monitors;

    this(CompositeManager manager){
        this.manager = manager;
        properties.window(.root);
        wm.on(.root, [
            PropertyNotify: (XEvent* e) => properties.update(&e.xproperty)
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
    }

    void start(bool now=false){
        if(now){
            resetPos = true;
            doOverview = true;
            window.show;
            window.move([0, 0]);
            window.resize([manager.width, manager.height]);
            XSetInputFocus(wm.displayHandle, window.windowHandle, RevertToPointerRoot, CurrentTime);

            XGrabPointer(
                    wm.displayHandle,
                    window.windowHandle,
                    False,
                    ButtonPressMask | ButtonReleaseMask | PointerMotionMask,
                    GrabModeAsync,
                    GrabModeAsync,
                    None,
                    None,
                    CurrentTime
            );
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
            window.hide;
            XUngrabPointer(wm.displayHandle, CurrentTime);
            zoomList = [];
            foreach(c; manager.clients ~ manager.destroyed){
                if(!c.hidden)
                    zoomList ~= c;
            }
        }else{
            properties.overview.request([2, 0, CurrentTime]);
        }
    }

    class WinInfo {
        CompositeClient window;
        this(CompositeClient window){
            this.window = window;
        }
    }

    class Monitor {
        int[2] pos;
        int[2] size;
        Workspace[] workspaces;
        this(int[2] pos, int[2] size){
            this.pos = pos;
            this.size = size;
        }
    }

    class Workspace {
        string name;
        int[] separators;
        WinInfo[] windows;
    }

    private void prefill(){
        monitors = [];
        foreach(screenI, screen; manager.screens){
            auto m = new Monitor([screen.x, screen.y], [screen.w, screen.h]);
            monitors ~= m;
            foreach(i; 0..properties.workspaceCount.value){
                auto ws = new Workspace;
                m.workspaces ~= ws;
                foreach(client; manager.clients ~ manager.destroyed){
                	if(client.a.override_redirect && client.properties.overviewHide.value != 1)
                		continue;
                    if(client.hidden && client.floating)
                        continue;
                    if(client.properties.workspace.value == i && screenI == manager.screens.findScreen(client.pos, client.size)){
                        ws.windows ~= new WinInfo(client);
                    }
                }
            }
        }
    }

    void calc(double[4] strut){
        prefill;
        struct Group {
            int width;
            WinInfo[] windows;
        }
        foreach(ref monitor; monitors){
        	auto mstrut = [strut[0]*monitor.size.w, strut[1]*monitor.size.w, strut[2]*monitor.size.h, strut[3]*monitor.size.h];
        	auto msize = [monitor.size.w - mstrut[0] - mstrut[1],
        				  monitor.size.h - mstrut[2] - mstrut[2]];
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
                        auto width = tabs > 0 ? w.window.properties.width.value.to!int : (msize.w/5).to!int;
                        groups[tabs] = Group(width);
                        unscaledWidth += width;
                    }
                    groups[tabs].windows ~= w;
                }
                auto containerScale = unscaledWidth.to!double / msize.w;
                import std.typecons;
                int offsetX;
                foreach(k, v; sort(groups.keys).map!(a => tuple(a, groups[a]))){
                    auto width = (v.width/containerScale).floor;
                    ws.separators ~= offsetX+width.min(monitor.size.w).to!int;
                    auto count = v.windows.length.to!double;
                    auto columns = k == 0 && groups.length > 1 ? 1 : sqrt(count).ceil.lround.to!double;
            		auto padding = [msize.w/40.0, msize.h/40];
                    foreach(w; v.windows){
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
                            	//+ (w.window.properties.workspace.value.to!int-manager.workspaceAnimation)*monitor.size.h
                                + (w.window.properties.workspace.value.to!int-manager.properties.workspace.value)*monitor.size.h
                            	+ offsetY
                            	).to!int
                        ];
                        if(resetPos){
                            w.window.overviewAnimation.pos = pos.to!(double[]);
                            w.window.overviewAnimation.size = size.to!(double[]);
                        }else
                            w.window.overviewAnimation.approach(pos, size);
                    }
                    offsetX += width.to!int;
                }
                if(ws.separators.length)
                    ws.separators = ws.separators[0..$-1];
            }
        }
        resetPos = false;
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

    bool has(CompositeClient client){
        foreach(m; monitors)
            foreach(wsi, ws; m.workspaces)
                foreach(w; ws.windows)
                    if(w.window == client)
                        return true;
        return false;
    }

	void calcWindow(CompositeClient client, ref int[2] pos, ref double[2] offset, ref int[2] size, ref double scale, ref double alpha){
        if(state < 0.000001)
            return;
        if(has(client)){
            auto tabWidth = 0;
            double zoom;
            if(!client.destroyed){
                if(zoomList.canFind(client)){
                    zoom = state.sinApproach;
                    alpha = 0.75 + alpha*0.25;
                }else{
                    zoom = 1;
                    alpha = (0.75 + alpha*0.25)*state.sinApproach;
                }
                if(client.properties.workspace.value < 0 || client.properties.overviewHide.value == 1){
                    alpha = (1-zoom)^^2;
                    return;
                }
            }else{
                zoom = 1;
            }
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
            //alpha = animate(alpha, 0, state.sinApproach);
        }
	}

	void predraw(Backend backend){
	}

    void damage(RootDamage damage){
        if(state > 0 && state < 1 || cleanup){
            damage.damage([0,0], [manager.width, manager.height]);
            if(state > 0 && state < 1)
                cleanup = true;
            else
                cleanup = false;
            return;
        }
        if(state < 0.000001)
            return;
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
    }

	void drawPre(Backend backend, CompositeClient client, int[2] pos, double[2] offset, int[2] size, double scale, double alpha){
        if(state < 0.000001 || client.a.override_redirect || !client.title.length || nodraw(client))
            return;
        with(Profile("Overview " ~ client.to!string)){
            double flop = client.hidden ? 1*alpha : state.sinApproach*alpha;
            int textHider;
            if(!client.hidden){
                textHider = -((1-state) * 30).lround.to!int;
            }
            backend.setColor([flop,flop,flop,flop]);
            backend.clip([pos.x, manager.height-pos.y], [size.w, 20]);
            backend.text([pos.x+size.w/2, manager.height-pos.y+textHider], 20, client.title, 0.5);
            backend.noclip;
        }
	}

	void drawPost(Backend backend, CompositeClient client, int[2] pos, double[2] offset, int[2] size, double scale, double alpha){
        if(state < 0.000001 || client.a.override_redirect || nodraw(client))
            return;
        with(Profile("Overview " ~ client.to!string)){
            double flop = client.hidden ? (1-alpha)*state.sinApproach : state.sinApproach*alpha;
            if(client.hidden){
                backend.setColor([0,0,0,0.3*flop]);
                backend.rect([pos.x, manager.height-pos.y-size.h], size);
            }
        }
	}

    void draw(Backend backend){
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
                with(Profile("Sep")){
                    foreach(sep; ws.separators){
                        backend.setColor([0.5,0.5,0.5,0.3*state^^2]);
                        backend.rect([sep-1+m.pos.x, m.size.h/20-1+m.pos.y], [4, m.size.h-m.size.h/10+2]);
                        backend.setColor([0,0,0,0.3*state^^2]);
                        backend.rect([sep+m.pos.x, m.size.h/20+m.pos.y], [2, m.size.h-m.size.h/10]);
                    }
                }
            }
        }
    }

    void drawDock(Backend backend){
        auto state = state.sinApproach;
        foreach(m; monitors){
            auto y = manager.height - m.pos.y - m.size.h;
            backend.clip([m.pos.x, y], m.size);
            auto maxDockHeight = m.size.h - 50.0 - 20*m.workspaces.length;
            auto scale = (1/7.5).min(maxDockHeight/m.workspaces.length/m.size.h);
            auto ssize = [m.size.w*scale, m.size.h*scale];
            auto height = (ssize.h+20)*m.workspaces.length;
            foreach(i, ws; m.workspaces){

                with(Profile("Dock workspace:" ~ i.to!string)){
                    auto wsp = [
                        m.pos.x + m.size.w-scale*m.size.w*state,
                        m.pos.y + m.size.h/2-height/2 + (ssize.h+20)*i + 10
                    ].to!(int[2]);

                    if(i == manager.properties.workspace.value){
                        backend.setColor([1,1,1,0.7*state]);
                        backend.rect([wsp.x-8, wsp.y-4].translate(m.size.h + (manager.height - m.size.h), ssize.h), [4, ssize.h.to!int+10]);
                    }
                    auto wsname = i >= 0 && i < workspaceNames.length ? workspaceNames[i] : "";
                    auto textp = wsp.translate(m.size.h+2 + (manager.height - m.size.h));
                    //textp.x += ssize.x.to!int - backend.width(wsname) - 10;
                    textp.x += 5;
                    backend.setColor([0,0,0,0.5*state]);
                    backend.rect([wsp.x, textp.y-2-ssize.h.to!int], [ssize.w.to!int, ssize.h.to!int+20-2]);

                    foreach(w; ws.windows){
                        with(Profile("Dock " ~ w.window.to!string)){
                            auto c = w.window;
                            if(!c.picture || c.hidden)
                                continue;
                            c.updateScale(scale);
                            backend.render(
                                c.picture,
                                state < 1 || c.hasAlpha,
                                state,
                                [(c.pos.x*scale+wsp.x - m.pos.x*scale).to!int,
                                (c.pos.y*scale+wsp.y - m.pos.y*scale).to!int],
                                [(c.size.w*scale).to!int,
                                (c.size.h*scale).to!int]
                            );
                        }
                    }

                    if(i != manager.properties.workspace.value){
                        backend.setColor([0,0,0,0.3*state]);
                        backend.rect(wsp.translate(m.size.h + (manager.height - m.size.h), ssize.h), ssize.to!(int[2]));
                    }

                    auto last = wsname.split("/").length-1;
                    backend.setColor([1,1,1,state]);
                    foreach_reverse(ti, part; wsname.split("/")){
                        if(ti < last)
                            backend.setColor([0.5,0.5,0.5,state]);
                        textp.x += backend.text(textp, part);
                        if(ti != 0)
                            textp.x += backend.text(textp, "/");
                    }
                }
            }
            backend.noclip;
        }
    }

}
