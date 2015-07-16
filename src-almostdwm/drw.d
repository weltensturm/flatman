module dwm.drw;

import
	std.string,
	std.algorithm,
	std.conv,
	x11.X,
	x11.Xlib,
	fontconfig,
	xft;

enum DRW_FONT_CACHE_SIZE = 32;

auto BETWEEN(T)(T x, T min, T max){
	return x > min && x < max;
}

struct Clr {
	ulong pix;
	XftColor rgb;
}

struct Cur {
	Cursor cursor;
}

struct Fnt {
	Display* dpy;
	int ascent;
	int descent;
	uint h;
	XftFont* xfont;
	FcPattern* pattern;
}

struct ClrScheme {
	Clr* fg;
	Clr* bg;
	Clr* border;
}

struct Drw {
	uint w, h;
	Display* dpy;
	int screen;
	Window root;
	Drawable drawable;
	GC gc;
	ClrScheme* scheme;
	size_t fontcount;
	Fnt*[DRW_FONT_CACHE_SIZE] fonts;
}

struct Extnts {
	uint w;
	uint h;
}


enum UTF_INVALID = 0xFFFD;
enum UTF_SIZ = 4;

static const ubyte[UTF_SIZ + 1] utfbyte = [0x80,    0, 0xC0, 0xE0, 0xF0];
static const ubyte[UTF_SIZ + 1] utfmask = [0xC0, 0x80, 0xE0, 0xF0, 0xF8];
static const long[UTF_SIZ + 1] utfmin = [       0,    0,  0x80,  0x800,  0x10000];
static const long[UTF_SIZ + 1] utfmax = [0x10FFFF, 0x7F, 0x7FF, 0xFFFF, 0x10FFFF];

static long
utf8decodebyte(const char c, size_t *i) {
	for(*i = 0; *i < (UTF_SIZ + 1); ++(*i))
		if((cast(ubyte)c & utfmask[*i]) == utfbyte[*i])
			return cast(ubyte)c & ~utfmask[*i];
	return 0;
}

static size_t
utf8validate(long *u, size_t i) {
	if(!BETWEEN(*u, utfmin[i], utfmax[i]) || BETWEEN(*u, 0xD800, 0xDFFF))
		*u = UTF_INVALID;
	for(i = 1; *u > utfmax[i]; ++i){}
	return i;
}

static size_t
utf8decode(const char *c, long *u, size_t clen) {
	size_t i, j, len, type;
	long udecoded;

	*u = UTF_INVALID;
	if(!clen)
		return 0;
	udecoded = utf8decodebyte(c[0], &len);
	if(!BETWEEN(len, 1, UTF_SIZ))
		return 1;
	for(i = 1, j = 1; i < clen && j < len; ++i, ++j) {
		udecoded = (udecoded << 6) | utf8decodebyte(c[i], &type);
		if(type != 0)
			return j;
	}
	if(j < len)
		return 0;
	*u = udecoded;
	utf8validate(u, len);
	return len;
}

Drw* drw_create(Display *dpy, int screen, Window root, uint w, uint h) {
	auto drw = new Drw;
	drw.dpy = dpy;
	drw.screen = screen;
	drw.root = root;
	drw.w = w;
	drw.h = h;
	drw.drawable = XCreatePixmap(dpy, root, w, h, DefaultDepth(dpy, screen));
	drw.gc = XCreateGC(dpy, root, 0, null);
	drw.fontcount = 0;
	XSetLineAttributes(dpy, drw.gc, 1, LineSolid, CapButt, JoinMiter);
	return drw;
}

void
drw_resize(Drw *drw, uint w, uint h) {
	if(!drw)
		return;
	drw.w = w;
	drw.h = h;
	if(drw.drawable != 0)
		XFreePixmap(drw.dpy, drw.drawable);
	drw.drawable = XCreatePixmap(drw.dpy, drw.root, w, h, DefaultDepth(drw.dpy, drw.screen));
}

void drw_free(Drw* drw) {
	size_t i;
	for (i = 0; i < drw.fontcount; i++) {
		drw_font_free(drw.fonts[i]);
	}
	XFreePixmap(drw.dpy, drw.drawable);
	XFreeGC(drw.dpy, drw.gc);
}

/* This function is an implementation detail. Library users should use
 * drw_font_create instead.
 */
static Fnt* drw_font_xcreate(Drw *drw, string fontname, FcPattern *fontpattern){
	if(!(fontname || fontpattern))
		throw new Exception("No font specified.");
	auto font = new Fnt;
	if(fontname){
		/* Using the pattern found at font.xfont.pattern does not yield same
		 * the same substitution results as using the pattern returned by
		 * FcNameParse; using the latter results in the desired fallback
		 * behaviour whereas the former just results in
		 * missing-character-rectangles being drawn, at least with some fonts.
		 */
		font.xfont = XftFontOpenName(drw.dpy, drw.screen, fontname.toStringz);
		font.pattern = FcNameParse(cast(FcChar8*)fontname);
		if (!font.xfont || !font.pattern){
			if(font.xfont){
				XftFontClose(drw.dpy, font.xfont);
				font.xfont = null;
			}
			throw new Exception("Cannot load font " ~ fontname);
		}
	}else if(fontpattern){
		font.xfont = XftFontOpenPattern(drw.dpy, fontpattern);
		if(!font.xfont){
			throw new Exception("Error, cannot load font pattern");
		} else {
			font.pattern = null;
		}
	}

	font.ascent = font.xfont.ascent;
	font.descent = font.xfont.descent;
	font.h = font.ascent + font.descent;
	font.dpy = drw.dpy;
	return font;
}

Fnt* drw_font_create(Drw* drw, string fontname) {
	return drw_font_xcreate(drw, fontname, null);
}

void drw_load_fonts(Drw* drw, string[] fonts, size_t fontcount) {
	size_t i;
	Fnt* font = drw_font_xcreate(drw, fonts[i], null);
	for (i = 0; i < fontcount; i++) {
		if(drw.fontcount >= DRW_FONT_CACHE_SIZE) {
			throw new Exception("Font cache exhausted.");
		}else if(font){
			drw.fonts[drw.fontcount++] = font;
		}
	}
}

void
drw_font_free(Fnt *font) {
	if(!font)
		return;
	if(font.pattern)
		FcPatternDestroy(font.pattern);
	XftFontClose(font.dpy, font.xfont);
}

Clr* drw_clr_create(Drw* drw, string clrname){
	Colormap cmap;
	Visual *vis;

	if(!drw)
		return null;
	auto clr = new Clr;
	if(!clr)
		return null;
	cmap = DefaultColormap(drw.dpy, drw.screen);
	vis = DefaultVisual(drw.dpy, drw.screen);
	if(!XftColorAllocName(drw.dpy, vis, cmap, clrname.toStringz, &clr.rgb))
		throw new Exception("Cannot allocate color " ~ clrname);
	clr.pix = clr.rgb.pixel;
	return clr;
}

void drw_clr_free(Clr* clr){
	assert(0, "not needed");
}

void drw_setscheme(Drw *drw, ClrScheme *scheme){
	if(drw && scheme)
		drw.scheme = scheme;
}

void
drw_rect(Drw *drw, int x, int y, uint w, uint h, int filled, int empty, int invert) {
	int dx;

	if(!drw || !drw.fontcount || !drw.scheme)
		return;
	XSetForeground(drw.dpy, drw.gc, invert ? drw.scheme.bg.pix : drw.scheme.fg.pix);
	dx = (drw.fonts[0].ascent + drw.fonts[0].descent + 2) / 4;
	if(filled)
		XFillRectangle(drw.dpy, drw.drawable, drw.gc, x+1, y+1, dx+1, dx+1);
	else if(empty)
		XDrawRectangle(drw.dpy, drw.drawable, drw.gc, x+1, y+1, dx, dx);
}

int drw_text(Drw *drw, int x, int y, uint w, uint h, const(char)* text, int invert) {
	char[1024] buf;
	int tx, ty, th;
	Extnts tex;
	Colormap cmap;
	Visual *vis;
	XftDraw *d;
	Fnt* curfont, nextfont;
	uint i, len;
	int utf8strlen, utf8charlen, render;
	long utf8codepoint = 0;
	const(char)* utf8str;
	FcCharSet *fccharset;
	FcPattern *fcpattern;
	XftResult result;
	int charexists = 0;
	render = x || y || w || h;
	if(!render){
		w = ~w;
	}

	if (!drw || !drw.scheme) {
		return 0;
	} else if (render) {
		XSetForeground(drw.dpy, drw.gc, invert ? drw.scheme.fg.pix : drw.scheme.bg.pix);
		XFillRectangle(drw.dpy, drw.drawable, drw.gc, x, y, w, h);
	}

	if (!text || !drw.fontcount) {
		return 0;
	} else if (render) {
		cmap = DefaultColormap(drw.dpy, drw.screen);
		vis = DefaultVisual(drw.dpy, drw.screen);
		d = XftDrawCreate(drw.dpy, drw.drawable, vis, cmap);
	}

	curfont = drw.fonts[0];
	while(true){
		utf8strlen = 0;
		utf8str = text;
		nextfont = null;
		while (*text) {
			utf8charlen = cast(int)utf8decode(text, &utf8codepoint, UTF_SIZ);
			for (i = 0; i < drw.fontcount; i++) {
				charexists = charexists || XftCharExists(drw.dpy, drw.fonts[i].xfont, utf8codepoint);
				if (charexists) {
					if (drw.fonts[i] == curfont) {
						utf8strlen += utf8charlen;
						text += utf8charlen;
					} else {
						nextfont = drw.fonts[i];
					}
					break;
				}
			}

			if (!charexists || (nextfont && nextfont != curfont)) {
				break;
			} else {
				charexists = 0;
			}
		}

		if (utf8strlen) {
			drw_font_getexts(curfont, utf8str, utf8strlen, &tex);
			/* shorten text if necessary */
			for(len = min(utf8strlen, buf.sizeof - 1); len && (tex.w > w - drw.fonts[0].h || w < drw.fonts[0].h); len--)
				drw_font_getexts(curfont, utf8str, len, &tex);

			if (len) {
				buf[0..len] = to!string(utf8str);
				buf[len] = '\0';
				if(len < utf8strlen)
					for(i = len; i && i > len - 3; buf[--i] = '.'){}

				if (render) {
					th = curfont.ascent + curfont.descent;
					ty = y + (h / 2) - (th / 2) + curfont.ascent;
					tx = x + (h / 2);
					XftDrawStringUtf8(d, invert ? &drw.scheme.bg.rgb : &drw.scheme.fg.rgb, curfont.xfont, tx, ty, cast(XftChar8*)buf, len);
				}

				x += tex.w;
				w -= tex.w;
			}
		}

		if (!*text) {
			break;
		} else if (nextfont) {
			charexists = 0;
			curfont = nextfont;
		} else {
			/* Regardless of whether or not a fallback font is found, the
			 * character must be drawn.
			 */
			charexists = 1;

			if (drw.fontcount >= DRW_FONT_CACHE_SIZE) {
				continue;
			}

			fccharset = FcCharSetCreate();
			FcCharSetAddChar(fccharset, utf8codepoint);

			if (!drw.fonts[0].pattern) {
				/* Refer to the comment in drw_font_xcreate for more
				 * information.
				 */
				throw new Exception("The first font in the cache must be loaded from a font string.");
			}

			fcpattern = FcPatternDuplicate(drw.fonts[0].pattern);
			FcPatternAddCharSet(fcpattern, FC_CHARSET, fccharset);
			FcPatternAddBool(fcpattern, FC_SCALABLE, True);

			FcConfigSubstitute(null, fcpattern, FcMatchKind.FcMatchPattern);
			FcDefaultSubstitute(fcpattern);
			FcPattern* match = XftFontMatch(drw.dpy, drw.screen, fcpattern, &result);

			FcCharSetDestroy(fccharset);
			FcPatternDestroy(fcpattern);

			if (match) {
				curfont = drw_font_xcreate(drw, null, match);
				if (curfont && XftCharExists(drw.dpy, curfont.xfont, utf8codepoint)) {
					drw.fonts[drw.fontcount++] = curfont;
				} else {
					if (curfont) {
						drw_font_free(curfont);
					}
					curfont = drw.fonts[0];
				}
			}
		}
	}

	if (render) {
		XftDrawDestroy(d);
	}

	return x;
}

void drw_map(Drw *drw, Window win, int x, int y, uint w, uint h) {
	if(!drw)
		return;
	XCopyArea(drw.dpy, drw.drawable, win, drw.gc, x, y, w, h, x, y);
	XSync(drw.dpy, False);
}


void drw_font_getexts(Fnt *font, const char *text, uint len, Extnts *tex) {
	XGlyphInfo ext;

	if(!font || !text)
		return;
	XftTextExtentsUtf8(font.dpy, font.xfont, cast(XftChar8*)text, len, &ext);
	tex.h = font.h;
	tex.w = ext.xOff;
}

uint drw_font_getexts_width(Fnt *font, const char *text, uint len) {
	Extnts tex;

	if(!font)
		return -1;
	drw_font_getexts(font, text, len, &tex);
	return tex.w;
}

Cur* drw_cur_create(Drw *drw, int shape) {
	auto cur = new Cur;
	if(!drw || !cur)
		return null;
	cur.cursor = XCreateFontCursor(drw.dpy, shape);
	return cur;
}

void drw_cur_free(Drw *drw, Cur *cursor){
	if(!drw || !cursor)
		return;
	XFreeCursor(drw.dpy, cursor.cursor);
}