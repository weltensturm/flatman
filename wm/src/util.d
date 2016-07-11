module flatman.util;


import flatman;


auto intersectArea(T, M)(T x, T y, T w, T h, M m){
	return (max(0, min(x+w,m.pos.x+m.size.w) - max(x,m.pos.x))
    	* max(0, min(y+h,m.pos.y+m.size.h) - max(y,m.pos.y)));
}
