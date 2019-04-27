#!/bin/bash

parts=($(cat build.conf))

set -e

for part in "${parts[@]}"; do
	echo "Building $part"
	pushd "$part" > /dev/null
	rm dub.selections.json 2&>/dev/null || true
	dub -q build --build=release
	popd > /dev/null
done
