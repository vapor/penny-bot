#!/bin/bash

set -eu

executable=$1
targetExec=".build/lambda/${executable}"

echo "Cleanup ..."
rm -rf "${targetExec}"

echo "Package exe ..."
mkdir -p "$targetExec"
cp -v ".build/release/${executable}" "${targetExec}/"
pushd ${targetExec}
ln -s "${executable}" "bootstrap"
zip --symlinks ../${executable}.zip * */*
popd

libs=`ldd .build/release/${executable} | grep swift | awk '{print $3}'`
