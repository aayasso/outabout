#!/usr/bin/env bash
# Runs add_widget_target.rb against CocoaPods' vendored xcodeproj gem.
#
# The system Ruby has no xcodeproj and macOS will not let you install one into
# it. CocoaPods ships its own copy, so we borrow that rather than asking anyone
# to manage a Ruby toolchain for a script that runs about twice.
set -euo pipefail

GEM_DIR=$(ls -d /opt/homebrew/Cellar/cocoapods/*/libexec 2>/dev/null | tail -1)
if [[ -z "${GEM_DIR}" ]]; then
  echo "Could not find CocoaPods' gem directory. Is cocoapods installed?" >&2
  exit 1
fi

GEM_HOME="${GEM_DIR}" GEM_PATH="${GEM_DIR}" ruby "$(dirname "$0")/add_widget_target.rb" "$@"
