#!/bin/bash

installdir=$1

parts=(wm compositor dock menu context volume-icon)

set -e

mkdir -p "$installdir/usr/bin/"
for part in "${parts[@]}"; do
	echo "Installing $part/flatman-$part"
	cp -f "$part/flatman-$part" "$installdir/usr/bin"
done

echo "Installing res/config.ws"
mkdir -p "$installdir/etc/flatman/"
cp -f res/config.ws "$installdir/etc/flatman/"

echo "Installing res/flatman.desktop"
mkdir -p "$installdir/usr/share/xsessions/"
cp -f res/flatman.desktop "$installdir/usr/share/xsessions/"
