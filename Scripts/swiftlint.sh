#!/bin/sh
set -e

# Support for SwiftLint installed via Homebrew on Apple Silicon
# https://github.com/realm/SwiftLint/issues/2992
if test -d "/opt/homebrew/bin/"; then
  PATH="/opt/homebrew/bin/:${PATH}"
fi

if which swiftlint >/dev/null; then
  # Ignore swiftlint error, because GRBD has no dependency on any Swiftlint version.
  # See https://github.com/groue/GRDB.swift/issues/1327
  swiftlint --config "${SRCROOT}/Scripts/swiftlint.yml" || true
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
