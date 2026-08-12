#!/usr/bin/env bash

set -Eeuxo pipefail

# Update PATH in-case it's run from Xcode scripts.
PATH="$PATH:/usr/local/bin/:/opt/homebrew/bin/"

BASE_DIR="$(dirname "$0")/.."

cd "$BASE_DIR/infra"

readonly TFLINT_CONFIG="$PWD/.tflint.hcl"

mise x -- terraform fmt -check -recursive
mise x -- tflint --init

for dir in . bootstrap; do
  mise x -- terraform -chdir="$dir" init -backend=false -input=false
  mise x -- terraform -chdir="$dir" validate -no-color
  mise x -- tflint --no-color --chdir="$dir" --config="$TFLINT_CONFIG"
done
