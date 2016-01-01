#!/bin/bash

parts=(wm compositor dock menu context volume-icon)

set -e

for part in "${parts[@]}"; do
	echo "Building $part"
	(cd "$part"; dub build)
done
