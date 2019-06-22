module composite.util;

import composite;

/+
double rip(double dist, double a, double b, double delta){
    // t(dist) = sqrt(dist+a)/b
    // dist = (t*b)^^2-a
    // jump = dist(t) - dist(t-delta)
    return (((sqrt(dist)/b+delta)*b)^^2 - dist).max(a*delta).min(dist);
}
+/
double rip(double dist, double a, double b, double delta){
    // t(dist) = cbrt(dist+a)/b
    // dist = (t*b)^^3-a
    // jump = dist(t) - dist(t-delta)
    b /= 4;
    return (((cbrt(dist)/b+delta)*b)^^3 - dist).max(a*delta).min(dist);
}

double rip(double current, double target, double a, double b, double delta){
    return current + rip((current-target).abs, a, b, delta)*(current < target ? 1 : -1);
}

void rip(ref double[2] current, double[2] target, double a, double b, double delta){
    double[2] dir = [target.x - current.x, target.y - current.y];
    auto dist = sqrt(dir.x^^2 + dir.y^^2);
    if(dist <= 0.0000001) // dividing by zero is not good
        return;
    double[2] normalized = [dir.x/dist, dir.y/dist];
    auto jump = rip(dist, a, b, delta);
    current.x += normalized.x*jump;
    current.y += normalized.y*jump;
}


bool inside(int[2] pos, int[2] rectPos, int[2] rectSize, int height){
    return
        pos.x > rectPos.x
        && pos.y > height - rectPos.y - rectSize.h
        && pos.x < rectPos.x + rectSize.w
        && pos.y < height - rectPos.y;
}


int[2] translate(T1, T2, T3)(T1[2] pos, T2 h, T3 h2=0){
    return [pos.x, h-h2-pos.y].to!(int[2]);
}


double animate(double start, double end, double state){
    return start + (end - start)*state;
}


double sinApproach(double a){
    return (sin((a-0.5)*PI)+1)/2;
}


double[N] calculate(size_t N)(Animation[N] animation){
    double[N] result;
    foreach(i; 0..N)
        result[i] = animation[i].calculate;
    return result;
}


void replace(size_t N, T)(Animation[N] animation, T[N] target){
    foreach(i; 0..N)
        animation[i].replace(target[i]);
}


struct Profile {

    private struct Perf {
        double time;
        string name;
        int level;
    }

    private struct PerfSection {
        string fullName;
        string name;
        size_t level;
        RotatingArray!(240, double) times;
    }

    private static Stack!string levels;
    private static PerfSection[string] sections;
    private static bool[string] ticked;

    static reset(){
        debug(Profile){
            foreach(ref b; ticked)
                b = false;
        }
    }

    private PerfSection* perf;

    double start;

    this(string name){
        debug(Profile){
            start = now;
            levels.push(name);
            auto fullName = levels.slice.join(".");
            if(fullName !in sections){
                sections[fullName] = PerfSection(fullName, name, levels.length);
            }
            perf = &sections[fullName];
        }
    }

    ~this(){
        debug(Profile){
            levels.pop;
            ticked[perf.fullName] = true;
            auto diff = now - start;
            perf.times ~= diff;
        }
    }

    static damagee(RootDamage damage){
        debug(Profile){
            damage.damage([0, 0], [400, manager.height]);
        }
    }

    static display(Backend backend){
        debug(Profile){
            foreach(name, ref section; sections){
                if(section.fullName !in ticked || !ticked[section.fullName]){
                    section.times ~= 0;
                }
            }
            //writeln(" ".replicate(level*4) ~ "%3.5f".format(diff) ~ ": " ~ name());
            int y = 50;
            backend.setFont("ProggyTinyTT", 12);
            backend.clip([0, 0], [400, manager.height]);
            backend.setColor([0, 0, 0, 0.4]);
            backend.rect([0, 0], [400, manager.height]);
            foreach(section; sections.keys.sort){
                auto perf = sections[section];
                double time;
                if(section == "sleep")
                    time = perf.times.first;
                else
                    time = perf.times.fold!max;
                bool zero = true;
                foreach(v; perf.times){
                    if(v > 0)
                        zero = false;
                }
                if(zero)
                    continue;
                /+
                if(time < 0.00005)
                    continue;
                +/
                if(section == "sleep"){
                    backend.setColor([1 - time*60, 1, 1 - time*60, time*60]);
                }else{
                    backend.setColor([1, 1 - time*60, 1 - time*60, time*60]);
                }
                backend.text([100, manager.height-y], "%s".format((time * 1000000).to!long), 1);
                backend.setColor([1, 1, 1]);
                backend.text([100 + 10, manager.height-y], "- ".repeat(perf.level-1).join ~ perf.name);
                y += backend.fontHeight;
            }
            backend.noclip;
        }
    }

}



struct Stack(T, size_t retain=50) {

    private T[] array;
    size_t length;

    void push(ref T value){
        if(length == array.length)
            array.length += retain;
        array[length] = value;
        length++;
    }

    ref T pop(){
        scope(exit) length--;
        return array[length];
    }

    auto slice(){
        return array[0..length];
    }

}



struct RotatingArray(size_t Size, T) {
    T[Size] elements = [0].replicate(Size);
    size_t counter;
    void opOpAssign(string op)(T value) if(op == "~"){
        elements[counter++] = value;
        if(counter >= Size)
            counter = 0;
    }
    T first(){
        return elements[counter];
    }
    int opApply(int delegate(T value) dg){
        int res = 0;
        foreach(i; counter..Size+counter){
            res = dg(elements[i >= Size ? i-Size : i]);
            if(res)
                break;
        }
        return res;
    }
    int opApply(int delegate(size_t idx, T value) dg){
        int res = 0;
        foreach(i; counter..Size+counter){
            res = dg(i-counter, elements[i >= Size ? i-Size : i]);
            if(res)
                break;
        }
        return res;
    }
    int size(){
        return Size.to!int;
    }
}


Picture colorPicture(bool argb, double a, double r, double g, double b){
    auto pixmap = XCreatePixmap(wm.displayHandle, root, 1, 1, argb ? 32 : 8);
    if(!pixmap)
        return None;
    XRenderPictureAttributes pa;
    pa.repeat = True;
    auto picture = XRenderCreatePicture(wm.displayHandle, pixmap, XRenderFindStandardFormat(wm.displayHandle, argb 	? PictStandardARGB32 : PictStandardA8), CPRepeat, &pa);
    if(!picture){
        XFreePixmap(wm.displayHandle, pixmap);
        return None;
    }
    XRenderColor c;
    c.alpha = (a * 0xffff).to!ushort;
    c.red =   (r * 0xffff).to!ushort;
    c.green = (g * 0xffff).to!ushort;
    c.blue =  (b * 0xffff).to!ushort;
    XRenderFillRectangle(wm.displayHandle, PictOpSrc, picture, &c, 0, 0, 1, 1);
    XFreePixmap(wm.displayHandle, pixmap);
    return picture;
}

