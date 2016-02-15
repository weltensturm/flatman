# flatman
Tiling window manager written in D

![Main](https://hostr.co/file/3LzpRDDPdQcr/flatman-3.png)
![Dock](https://hostr.co/file/e5sW4EXmFP4K/Untitled.png)

## features

* tiled and tabbed window layout
* variable workspace count
* workspace dock
* combined app launcher and file manager
* integrates well with `weltensturm/dinu`
* EWMH support
* support for external bars/docks
* compositing

Currently only horizontal layouts are supported. To create multiple tab stacks, move a window all the way to the left/right.

## usage

* compile with `./build.sh`, install with `sudo ./install.sh`
* configure in `~/.config/flatman/config.ws`, see `/etc/flatman/config.ws` for default configuration
* usage of `weltensturm/dinu` as launcher is recommended

## upcoming

* full mouse support
* vertical layout
