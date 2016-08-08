#/bin/sh
#
# Outputs the compilation time of all methods.
# To get the 20 slowest methods, run ./slow_methods.sh | head -20
set -e

PROJECT=GRDB.xcodeproj
TARGET=GRDBiOS

OTHER_SWIFT_FLAGS='-Xfrontend -debug-time-function-bodies' xcodebuild -project $PROJECT -target $TARGET 2>&1 clean build | grep '^[0-9][0-9.]*.*\t' | sort -nr
