#!/bin/bash

installdir=$1

parts=(wm compositor dock menu context volume-icon battery-icon volume-notify backlight-notify bar)

configs=(config.ws bar.ws menu)

paths=(usr/bin etc/flatman usr/share/xsessions usr/share/applications)

set -e

for part in "${paths[@]}"; do
	mkdir -p "$installdir/$part"
done

for part in "${parts[@]}"; do
	echo "Installing $part/flatman-$part"
	cp -f "$part/flatman-$part" "$installdir/usr/bin"
done

for part in "${configs[@]}"; do
	echo "Installing res/$part"
	cp -f res/$part "$installdir/etc/flatman/"
done

echo "Installing res/flatman.desktop"
cp -f res/flatman.desktop "$installdir/usr/share/xsessions/"

echo "Installing flatman config"
cp -f res/flatman-wm-system.desktop "$installdir/usr/share/applications/"
cp -f res/flatman-wm-user.desktop "$installdir/usr/share/applications/"

chmod -R 755 "$installdir/etc/flatman/"*
chmod -R 755 "$installdir/usr/bin/flatman"*

