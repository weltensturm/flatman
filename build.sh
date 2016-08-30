#!/bin/bash

parts=(wm compositor dock menu context volume-icon)

set -e

for part in "${parts[@]}"; do
	echo "Building $part"
	(cd "$part"; $(rm dub.selections.json 2&>/dev/null || true); dub build > /dev/null)
done
