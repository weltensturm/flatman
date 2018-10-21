#!/bin/bash

set -euo pipefail

DC="${DC:-dmd}"

parts=($(cat build.conf))

for part in "${parts[@]}"; do
    dub test --build=unittest-cov --compiler="$DC" -- ~@notravis
    dub build --compiler="$DC"

    if [[ "$DC" == "dmd" ]]; then
        bundle exec cucumber --tags ~@wip --tags ~@notravis
    fi

done

