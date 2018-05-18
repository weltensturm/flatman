module menu.config;

import menu;


struct Config {

    float[3] background = [0.1, 0.1, 0.1];
    float[3] border = [0.2, 0.2, 0.2];
    string font = "DejaVu Sans";
    int fontSize = 10;
    
    struct ButtonTab {
        string font = "DejaVu Sans";
        int fontSize = 10;
        int height = 22;
    }
    ButtonTab buttonTab;

    struct ButtonTree {
        string font = "DejaVu Sans";
        int fontSize = 9;
        int height = 18;
    }
    ButtonTree buttonTree;

}


Config config;

