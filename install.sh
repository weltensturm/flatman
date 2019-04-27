#!/bin/bash

installdir=$1

parts=($(cat build.conf))

configs=(config.ws bar.ws menu composite.ws autostart)

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

cp -f res/flatman.desktop /usr/share/xsessions/
echo "Installing res/flatman.desktop"

cp -f terminal/flatman-terminal "$installdir/usr/bin/flatman-terminal"

chmod -R 755 "$installdir/etc/flatman/"*
chmod -R 755 "$installdir/usr/bin/flatman"*

