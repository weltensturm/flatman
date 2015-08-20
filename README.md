# flatman
Flat window manager written in D

![Menu](https://hostr.co/file/w6svqLFIfrZA/Untitled2.png)
![Dock](https://hostr.co/file/e5sW4EXmFP4K/Untitled.png)

## features

* tiled window layout
* 10 virtual desktops
* virtual desktop dock
* integrates well with `weltensturm/dinu`
* EWMH support
* support for external bars/docks

## usage

* compile main and subprojects with `dub`
* configure in `config.ws` and `src/config.d`
* usage of `weltensturm/dinu` as launcher is recommended
* if `x11` causes problems, install `weltensturm/x11` and add it with `dub add-local <path-to-x11> <requested version>`

## upcoming

* full mouse support
* text file keybindings
* vertical layout
* tabbed windows
