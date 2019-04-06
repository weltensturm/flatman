#!/bin/bash

set -euo pipefail

dub -q fetch covered

DC="${DC:-dmd}"

parts=($(cat build.conf))

for part in "${parts[@]}"; do
    pushd $part > /dev/null
    echo $part
    rm dub.selections.json || true
    dub -q test --build=unittest-cov --compiler="$DC"
    find . -name "-home*.lst" -exec rm {} \;
    dub -q run covered -- -a
    find . -name "*.lst" -exec rm {} \;
    popd > /dev/null
done

