module composite.backend.opengl;

import composite;


class OpenGLBackend: Backend {

    int[2] size;

    GlContext context;

    this(){
        size = [DisplayWidth(wm.displayHandle, 0), DisplayHeight(wm.displayHandle, 0)];
        resize(size);
        //context = new GlContext(root);
        //draw = new GlDraw;
        draw.setFont("Roboto", 10);
        initAlpha;
        checkXerror;
    }

    override void render(Picture picture, bool transparent, double alpha, int[2] offset, int[2] pos, int[2] size){
    }

    override void damage(RootDamage damage){
    }

    override void resize(int[2] size){
    }

    override void swap(){
    }

    override void destroy(){
    }

    void initAlpha(){
    }

}

