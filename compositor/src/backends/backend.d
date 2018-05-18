module composite.backend.backend;

import composite;


class Backend {

    DrawEmpty draw;
    alias draw this;

    void resize(int[2] size){
        draw.resize(size);
    }

    void render(Picture picture, bool transparent, double alpha, int[2] pos, int[2] size){
        render(picture, transparent, alpha, [0, 0], pos, size);
    }

    void render(Picture picture, bool transparent, double alpha, int[2] offset, int[2] pos, int[2] size){
    }

    void swap(){
    }

    void destroy(){
    }

    void damage(RootDamage){}

}