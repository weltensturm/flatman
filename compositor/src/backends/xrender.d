module composite.backend.xrender;

import composite;


class XRenderBackend: Backend {

    int[2] size;

    enum ALPHA_STEPS = 256;
    Picture[ALPHA_STEPS] alpha;

    this(){
        size = [DisplayWidth(wm.displayHandle, 0), DisplayHeight(wm.displayHandle, 0)];
        resize(size);
        draw = new XDraw(wm.displayHandle, root);
        draw.setFont("Roboto", 10);
        initAlpha;
        checkXerror;
    }

    override void render(Picture picture, bool transparent, double alpha, int[2] offset, int[2] pos, int[2] size){
        auto alphaMask = alpha < 1 ? this.alpha[(alpha*ALPHA_STEPS).to!int] : None;
        X.RenderComposite(
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

    override void damage(RootDamage damage){
        damage.clip(draw.picture);
    }

    override void resize(int[2] size){
        this.size = size;
        if(draw)
            draw.resize(size);
    }

    override void swap(){
        debug(Damage){
            draw.setColor([uniform(0,256)/256.0f, uniform(0,256)/256.0f, uniform(0,256)/256.0f, 0.2]);
            draw.rect([0,0], size);
        }
        draw.finishFrame;
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


