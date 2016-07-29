module flatman.util;


import flatman;


auto intersectArea(T, M)(T x, T y, T w, T h, M m){
	return (max(0, min(x+w,m.pos.x+m.size.w) - max(x,m.pos.x))
    	* max(0, min(y+h,m.pos.y+m.size.h) - max(y,m.pos.y)));
}

T cleanMask(T)(T mask){
	return mask & ~(numlockmask|LockMask) & (ShiftMask|ControlMask|Mod1Mask|Mod2Mask|Mod3Mask|Mod4Mask|Mod5Mask);
}

auto width(T)(T x){
	return x.size.w + 2 * x.bw;
}

auto height(T)(T x){
	return x.size.h + 2 * x.bw;
}
