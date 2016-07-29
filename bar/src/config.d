module bar.config;


import bar;


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


struct Config {

	ConfigColor foreground;
	ConfigColor background;

	ConfigColor border;

    ConfigColor titleTextNormal;
    ConfigColor titleTextActive;
    ConfigColor titleTextHidden;

    ConfigColor separatorColor;
    int separatorWidth;
}


Config config;
