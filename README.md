# flatman
Flat window manager written in D

![Main](https://hostr.co/file/3LzpRDDPdQcr/flatman-3.png)
![Dock](https://hostr.co/file/e5sW4EXmFP4K/Untitled.png)

## features

* tiled and tabbed window layout
* 10 virtual desktops
* virtual desktop dock
* integrates well with `weltensturm/dinu`
* EWMH support
* support for external bars/docks

Currently only horizontal layouts are supported. To create multiple tab stacks, move a window all the way to the left/right.

## usage

* compile main and subprojects with `dub`
* configure in `config.ws`, read order: `$installdir/config.ws`, `/etc/flatman`, `~/.config/flatman/config.ws`
* usage of `weltensturm/dinu` as launcher is recommended
* if `x11` causes problems, install `weltensturm/x11` and add it with `dub add-local <path-to-x11> <requested version>`
* `~/.autostart.sh` is run on startup, add bar/dock and wallpaper (feh) there

## upcoming

* full mouse support
* vertical layout
* compositing
