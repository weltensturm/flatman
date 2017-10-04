module composite.shadow;

import composite;


class Shadow {


    Picture shadowT;
    Picture shadowB;
    Picture shadowL;
    Picture shadowR;
    Picture shadowTl;
    Picture shadowTr;
    Picture shadowBl;
    Picture shadowBr;

    this(){

        shadowT = shadow(0, -1, 30);
        shadowB = shadow(0, 1, 30);
        shadowL = shadow(-1, 0, 30);
        shadowR = shadow(1, 0, 30);
        shadowTl = shadow(-1, -1, 30);
        shadowTr = shadow(1, -1, 30);
        shadowBl = shadow(-1, 1, 30);
        shadowBr = shadow(1, 1, 30);

    }

    Picture shadow(int x, int y, int width){
        auto id = width*100 + x*10 + y;
        auto pixmap = XCreatePixmap(wm.displayHandle, root, x ? width : 1, y ? width : 1, 32);
        XRenderPictureAttributes pa;
        pa.repeat = true;
        auto picture = XRenderCreatePicture(wm.displayHandle, pixmap, XRenderFindStandardFormat(wm.displayHandle, PictStandardARGB32), CPRepeat, &pa);
        XRenderColor c;
        c.red =   0;
        c.green = 0;
        c.blue =  0;
        if(x && y){
            foreach(x1; 0..width){
                foreach(y1; 0..width){
                    double[2] dir = [(-x).max(0)*width-x1, (-y).max(0)*width-y1];
                    auto len = asqrt(dir[0]*dir[0] + dir[1]*dir[1]).min(width);
                    c.alpha = ((1-len/width).pow(3)/6*0xffff).to!ushort;
                    XRenderFillRectangle(wm.displayHandle, PictOpSrc, picture, &c, x1, y1, 1, 1);
                }
            }
        }else{
            foreach(i; 0..width){
                c.alpha = ((i.to!double/width).pow(3)/6 * 0xffff).to!ushort;
                XRenderFillRectangle(wm.displayHandle, PictOpSrc, picture, &c, x ? (x > 0 ? width-i: i) : 0, y ? (y > 0 ? width-i : i) : 0, 1, 1);
            }
        }
        XFreePixmap(wm.displayHandle, pixmap);
        return picture;
    }

    void drawShadow(Backend backend, int[2] pos, int[2] size){
        foreach(x; [-1, 0, 1]){
            /+
            if(x < 0 && pos.x<=0 || x > 0 && pos.x+size.w>=width)
                continue;
            +/
            foreach(y; [-1, 0, 1]){
                /+
                if(y < 0 && pos.y<=0 || y > 0 && pos.y+size.h>=height)
                    continue;
                +/
                if(x == 0 && y == 0)
                    continue;
                Picture s;
                final switch(10*x+y){
                    case 10*0 + -1:
                        s = shadowT;
                        break;
                    case 10*0 + 1:
                        s = shadowB;
                        break;
                    case 10*-1 + 0:
                        s = shadowL;
                        break;
                    case 10*1 + 0:
                        s = shadowR;
                        break;
                    case 10*-1 + -1:
                        s = shadowTl;
                        break;
                    case 10*1 + -1:
                        s = shadowTr;
                        break;
                    case 10*-1 + 1:
                        s = shadowBl;
                        break;
                    case 10*1 + 1:
                        s = shadowBr;
                        break;
                }
                backend.render(
                    s,
                    false,
                    None,
                    [0, 0],
                    [pos.x + (x > 0 ? size.w-1 : 30*x),
                     pos.y + (y > 0 ? size.h-1 : 30*y)],
                    [x == 0 ? size.w : 30,
                     y == 0 ? size.h : 30]
                );
            }
        }
    }

}