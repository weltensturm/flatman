module composite.backend.xrenderMulti;

import
    ws.bindings.xlib,
    common.log,
    composite,
    composite.backend.xrenderMultiDraw,
    common.xerror;


static foreach(p; Parameters!XPresentPixmap){
    pragma(msg, p.sizeof.to!string ~ " " ~ p.stringof);
}


class XRenderMultiBackend: Backend {

    enum ALPHA_STEPS = 256;
    Picture[ALPHA_STEPS] alpha;

    XRenderMultiDraw[] xdraw;

    this(){}

    override void resize(int[2]){
        with(Log("CONFIGURE BACKEND")){

            auto crtcs = manager.monitors.map!(a => a.crtc).array;
            auto crtcsCurrent = xdraw.map!(a => a.crtc).array;

            foreach(a; xdraw.filter!(a => !crtcs.canFind(a.crtc))){
                Log.info("remove CRTC " ~ a.crtc.to!string);
                a.destroy();
            }
            xdraw = xdraw.filter!(a => crtcs.canFind(a.crtc)).array;

            foreach(ref monitor; manager.monitors.filter!(a => !crtcsCurrent.canFind(a.crtc))){
                if(monitor.fence)
                    XSyncDestroyFence(wm.displayHandle, monitor.fence);
                auto n = new XRenderMultiDraw(wm.displayHandle, manager.overlayWindow);
                monitor.fence = X.SyncCreateFence(wm.displayHandle, n.drawable.pixmap.to!uint, true);
                Log.info("created fence %s".format(monitor.fence));
                n.crtc = monitor.crtc;
                xdraw ~= n;
                Log.info("add CRTC %s %s %s".format(monitor.crtc, monitor.pos, monitor.size));
            }

            foreach(ref monitor; manager.monitors){
                foreach(draw; xdraw){
                    if(monitor.crtc == draw.crtc){
                        draw.pos = [-monitor.pos.x, -monitor.pos.y];
                        draw.resize(monitor.size);
                    }
                }
            }
            
        }
    }

    override void damage(CompositeMonitor monitor, RootDamage damage){
        auto draw = xdraw.find!(a => a.crtc == monitor.crtc)[0];
        with(Profile("clip monitor")){
            draw.clip(monitor.pos, monitor.size);
        }

        XFixesDestroyRegion(wm.displayHandle, draw.mask);
        draw.mask = XFixesCreateRegion(wm.displayHandle, null, 0);
        XFixesCopyRegion(wm.displayHandle, draw.mask, damage.all);

        with(Profile("clip draw")){
            draw.clip(draw.mask);
        }
    }

    override DrawEmpty target(CompositeMonitor monitor){
        if(!xdraw.length)
            return null;
        return xdraw.find!(a => a.crtc == monitor.crtc)[0];
    }

    override void swap(ref CompositeMonitor monitor){
        if(!xdraw.length)
            return;
        auto draw = xdraw.find!(a => a.crtc == monitor.crtc)[0];
        debug(Damage){
            draw.setColor([uniform(0,256)/256.0f, uniform(0,256)/256.0f, uniform(0,256)/256.0f, 0.2]);
            draw.rect(monitor.pos, monitor.size);
        }
        draw.noclip;
        draw.noclip;
        XPresentPixmap(
            wm.displayHandle,
            manager.overlayWindow,
            draw.drawable,
            monitor.crtc.to!uint,
            draw.mask,
            draw.mask,
            monitor.pos.x, monitor.pos.y,
            monitor.crtc,
            None,
            monitor.fence,
            PresentOptionCopy,
            0,
            1,
            0,
            null,
            0
        );
        monitor.backbufferReady = false;
    }

    override void destroy(){
        foreach(a; alpha)
            X.RenderFreePicture(wm.displayHandle, a);
    }

    void initAlpha(){
        foreach(i; 0..ALPHA_STEPS){
            if(i < ALPHA_STEPS-1)
                alpha[i] = colorPicture(false, i/cast(float)(ALPHA_STEPS-1), 0, 0, 0);
            else
                alpha[i] = None;
        }
    }

}



void xrr_update(){
    auto xrr = XRRGetScreenResources(wm.displayHandle, root);
    foreach(i; 0..xrr.ncrtc){
        auto info = XRRGetCrtcInfo(wm.displayHandle, xrr, xrr.crtcs[i]);
        writeln(*info);
        writeln(xrr.modes[info.mode]);
        auto mode = &xrr.modes[info.mode];
    }
    XRRFreeScreenResources(xrr);
}


auto xrr_info(){
    struct CrctInfo {
        RRCrtc crtc;
        int[2] pos;
        int[2] size;
    }
    CrctInfo[] list;
    auto xrr = XRRGetScreenResources(wm.displayHandle, root);
    foreach(i; 0..xrr.ncrtc){
        auto info = XRRGetCrtcInfo(wm.displayHandle, xrr, xrr.crtcs[i]);
        list ~= CrctInfo(xrr.crtcs[i], [info.x, info.y], [info.width, info.height]);
    }
    XRRFreeScreenResources(xrr);
    return list;
}

