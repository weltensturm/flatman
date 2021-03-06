#!/bin/bash

parts=($(cat build.conf))

set -e

for part in "${parts[@]}"; do
	echo "Building $part"
	(cd "$part"; $(rm dub.selections.json 2&>/dev/null || true); dub build > /dev/null)
done
