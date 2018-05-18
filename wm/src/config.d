module flatman.config;

import flatman;

__gshared:


struct ConfigColor {

	float[3] color;
	alias color this;

	this(string text){
		color = [
			text[0..2].to!int(16)/255.0,
			text[2..4].to!int(16)/255.0,
			text[4..6].to!int(16)/255.0
		];
	}

}

struct ConfigInt4 {

	int[4] value;
	alias value this;

	this(string text){
		value = text.split.to!(int[4]);
	}

}


__gshared const Rule[] rules = [
	{ "Gimp",     "",       "",       0,            true,        -1 },
	{ "Firefox",  "",       "",       1 << 8,       false,       -1 },
];


struct NestedConfig {

	string mod;
	string[string] keys;
	string[] autostart;

	bool workspaceWrap;

	struct Split {
		int paddingElem;
		ConfigColor background;
	}
	Split split;

	struct Tabs {

		int width;
		ConfigInt4 padding;

		struct Title {
			int height;
			string font;
			int fontSize;
			int show;

			ConfigColor normal;
			ConfigColor active;
			ConfigColor urgent;
			ConfigColor hover;
			ConfigColor fullscreen;
		}
		Title title;

		struct Border {
			int height;
			ConfigColor normal;
			ConfigColor active;
			ConfigColor fullscreen;
		}
		Border border;

		struct Background {
			ConfigColor normal;
			ConfigColor fullscreen;
			ConfigColor hover;
			ConfigColor active;
			ConfigColor urgent;
		}
		Background background;
	}
	Tabs tabs;

}

NestedConfig config;