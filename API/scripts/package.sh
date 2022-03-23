#!/bin/bash

set -eu

executable=$1

target=".build/lambda/$executable"

echo "$target"
echo "$executable"
rm -rf "$target"
mkdir -p "$target"
cp ".build/release/$executable" "$target/"
cp --help
# add the target deps based on ldd
ldd ".build/release/$executable" | grep swift | awk '{print $3}' | xargs cp -Lv -t "$target"
cd "$target"
ln -s "$executable" "bootstrap"
zip --symlinks lambda.zip *
