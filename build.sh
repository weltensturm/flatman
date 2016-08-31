#!/bin/bash

parts=(wm compositor dock menu context volume-icon bar)

set -e

for part in "${parts[@]}"; do
	echo "Building $part"
	(cd "$part"; $(rm dub.selections.json || true); dub build > /dev/null)
done
