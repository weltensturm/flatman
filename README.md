# flatman
Flat window manager written in D

![Terminals](https://hostr.co/file/970/OdqUN9HebvpN/flatman-1.png)
![Dock](https://hostr.co/file/970/femO2OeQhX3S/flatman-2.png)

## features

* side-by-side tiled window layout
* 10 virtual desktops
* virtual desktop dock
* integrates well with `weltensturm/dinu`
* partial EWMH support

## usage

* compile with `dub`
* configure in `src/config.d`
* usage of `weltensturm/dinu` as launcher is recommended
* if `x11` causes problems, install `weltensturm/x11` and add it with `dub add-local <path-to-x11> <requested version>`

## upcoming

* full EWMH support
* support for external docks
* full mouse support
* separation of bar, dock and window manager
* text file configuration
* tabbed windows
