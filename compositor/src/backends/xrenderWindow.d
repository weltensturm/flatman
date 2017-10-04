module composite.backend.xrenderWindow;

import composite;


class XRenderWindowBackend: Backend {
    
    enum ALPHA_STEPS = 256;
    Picture[ALPHA_STEPS] alpha;

    ws.wm.Window window;

    this(ws.wm.Window window){
        this.window = window;
        draw = window.draw.to!XDraw;
        draw.setFont("Roboto", 10);
        initAlpha;
    }

    override void damage(RootDamage damage){
        damage.clip(draw.picture);
    }

    override void render(Picture picture, bool transparent, double alpha, int[2] offset, int[2] pos, int[2] size){
        auto alphaMask = alpha < 1 ? this.alpha[(alpha*ALPHA_STEPS).to!int] : None;
        XRenderComposite(
            wm.displayHandle,
            transparent || alpha < 1 ? PictOpOver : PictOpSrc,
            picture,
            alphaMask,
            draw.picture,
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
            draw.rect([0,0], draw.size);
        }
        draw.finishFrame;
    }

    override void destroy(){
        foreach(a; alpha)
            XRenderFreePicture(wm.displayHandle, a);
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
