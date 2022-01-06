#!/bin/sh
set -e

# Support for SwiftLint installed via Homebrew on Apple Silicon
# https://github.com/realm/SwiftLint/issues/2992
if test -d "/opt/homebrew/bin/"; then
  PATH="/opt/homebrew/bin/:${PATH}"
fi

if which swiftlint >/dev/null; then
  swiftlint --config "${SRCROOT}/Scripts/swiftlint.yml"
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
