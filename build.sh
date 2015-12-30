#!/bin/bash

parts=(wm compositor dock menu context volume-icon)

for part in "${parts[@]}"; do
	echo "Building $part"
	(cd "$part"; dub build)
done
