#!/bin/bash

set -eu

# Formats all Swift files

# Update PATH incase it's run from Xcode scripts.
PATH="$PATH:/usr/local/bin/:/opt/homebrew/bin/"

# This script is in `./scripts` directory so `./scripts/..` would be the same as `./`.
BASE_DIR=$(dirname "$0")/..

note() {
  printf -- "** %s\n" "$*" >&2
}

note "Starting the script at $(date)"

# Take an argument for BASE_DIR, incase this is run from Xcode scripts.
if [ "${1:-}" != "" ]; then
  note "Got BASE_DIR argument: $1"
  BASE_DIR=$1
fi

cd "$BASE_DIR"

note "Will run swift-format while BASE_DIR is $BASE_DIR"

# Format all Swift files, excluding the ones in .swiftformatignore
# Code grabbed from https://raw.githubusercontent.com/swiftlang/github-workflows/refs/heads/main/.github/workflows/scripts/check-swift-format.sh
tr '\n' '\0' <.swiftformatignore | xargs -0 -I% printf '":(exclude)%" ' | xargs git ls-files -z '*.swift' | xargs -0 swift format format --parallel --in-place
