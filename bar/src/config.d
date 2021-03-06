module bar.config;


import bar;


struct ConfigColor {

	float[4] color;
	alias color this;

	this(string text){
		color[0..3] = [
			text[0..2].to!int(16)/255.0,
			text[2..4].to!int(16)/255.0,
			text[4..6].to!int(16)/255.0
		];
		if(text.length > 6){
			color[3] = text[6..8].to!int(16)/255.0;
		}else{
			color[3] = 1;
		}
	}

}


struct Config {

	struct Theme {
		ConfigColor foreground;
		ConfigColor foregroundMain;
		ConfigColor background;

		ConfigColor border;

		ConfigColor titleTextNormal;
		ConfigColor titleTextActive;
		ConfigColor titleTextHidden;

		ConfigColor separatorColor;
		int separatorWidth;
		int padding;
	}
	Theme theme;

	struct Bar {
		int screen = 0;
		string aligned = "top";
		bool systray = false;
	}
	Bar[string] bars;

}


Config config;
