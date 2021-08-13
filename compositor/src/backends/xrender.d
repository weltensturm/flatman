module composite.backend.xrender;

import
    x11.extensions.Xrandr,
    composite.xpresent,
    composite,
    common.xerror;


class XRenderBackend: Backend {

    enum ALPHA_STEPS = 256;
    Picture[ALPHA_STEPS] alpha;

    XDraw xdraw;

    this(){
        //size = [DisplayWidth(wm.displayHandle, 0), DisplayHeight(wm.displayHandle, 0)];
        //resize(size);
        xdraw = new XDraw(wm.displayHandle, root);
        draw = xdraw;
        draw.setFont("Roboto", 10);
        initAlpha;
    }

    override void damage(CompositeMonitor monitor, RootDamage damage){
        xdraw.clip([monitor.pos.x, xdraw.size.h-monitor.size.h-monitor.pos.y], monitor.size);
        xdraw.clip(damage.all);
    }

    override void render(Picture picture, bool transparent, double alpha, int[2] offset, int[2] pos, int[2] size){
        auto alphaMask = alpha < 1 ? this.alpha[(alpha*ALPHA_STEPS).to!int] : None;
        X.RenderComposite(
            wm.displayHandle,
            (transparent || alpha < 1) ? PictOpOver : PictOpSrc,
            picture,
            alphaMask,
            xdraw.picture,
            offset.x,
            offset.y,
            0,
            0,
            pos.x,
            pos.y,
            size.w,
            size.h
        );
    }

    override void swap(){
        debug(Damage){
            draw.setColor([uniform(0,256)/256.0f, uniform(0,256)/256.0f, uniform(0,256)/256.0f, 0.2]);
            draw.rect([0,0], xdraw.size);
        }
        draw.finishFrame;
        draw.noclip;
    }


    // override void swap(CompositeMonitor monitor){
    //     debug(Damage){
    //         draw.setColor([uniform(0,256)/256.0f, uniform(0,256)/256.0f, uniform(0,256)/256.0f, 0.2]);
    //         draw.rect([0,0], xdraw.size);
    //     }
    //     draw.finishFrame;
    //     draw.noclip;
    //     draw.noclip;
    // }
    
    override void swap(ref CompositeMonitor monitor){
        debug(Damage){
            draw.setColor([uniform(0,256)/256.0f, uniform(0,256)/256.0f, uniform(0,256)/256.0f, 0.2]);
            draw.rect([0,0], xdraw.size);
        }
        XPresentPixmap(
            wm.displayHandle,
            root.to!uint,
            xdraw.drawable,
            monitor.crtc.to!uint,
            xdraw.clipStack.all,
            xdraw.clipStack.all,
            0, 0,
            monitor.crtc,
            None,
            None,
            0,
            0,
            1,
            0,
            null,
            0
        );
        monitor.presenting = true;
        draw.noclip;
        draw.noclip;
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

