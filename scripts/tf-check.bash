#!/bin/bash

set -euxo pipefail

# Update PATH in-case it's run from Xcode scripts.
PATH="$PATH:/usr/local/bin/:/opt/homebrew/bin/"

BASE_DIR="$(dirname "$0")/.."

cd "$BASE_DIR/infra"

mise x -- terraform fmt -check -recursive
mise x -- terraform init -backend=false -input=false
mise x -- terraform validate -no-color
mise x -- tflint --init
mise x -- tflint --no-color
