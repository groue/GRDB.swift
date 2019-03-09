#!/bin/sh

set -eux
set -o pipefail

src_dir="$SRCROOT/SQLCipher/src/"
src_build_dir="$SRCROOT/SQLCipher/src_build/"
cd "${src_build_dir}"

# Ensure we always run configure/make as if we were compiling for macOS (as parts of the
# configure/make process require building & running an executable)
#
# The generated sqlite3.c will be built for the correct platform by Xcode via the
# 'sqlitecustom' target
SDK_PLATFORM_NAME="macosx"
MACOSX_VERSION_MIN="$(sw_vers -productVersion | cut -d '.' -f 1,2)"

SDKROOT="$(xcrun --sdk $SDK_PLATFORM_NAME --show-sdk-path)"
CC="$(xcrun --sdk $SDK_PLATFORM_NAME -f clang)"
CXX="$(xcrun --sdk $SDK_PLATFORM_NAME -f clang++)"
CFLAGS="-arch x86_64 -isysroot $SDKROOT -mmacosx-version-min=$MACOSX_VERSION_MIN ${OTHER_CFLAGS:-}"
CXXFLAGS=$CFLAGS
export CC CXX CFLAGS CXXFLAGS

# Comes from `prepare_command` in https://github.com/sqlcipher/sqlcipher/blob/master/SQLCipher.podspec.json

"${src_dir}/configure" --enable-tempstore=yes --with-crypto-lib=commoncrypto CFLAGS="-DSQLITE_HAS_CODEC -DSQLITE_TEMP_STORE=2 -DSQLITE_SOUNDEX -DSQLITE_THREADSAFE -DSQLITE_ENABLE_RTREE -DSQLITE_ENABLE_STAT3 -DSQLITE_ENABLE_STAT4 -DSQLITE_ENABLE_COLUMN_METADATA -DSQLITE_ENABLE_MEMORY_MANAGEMENT -DSQLITE_ENABLE_LOAD_EXTENSION -DSQLITE_ENABLE_UNLOCK_NOTIFY -DSQLITE_ENABLE_FTS3_PARENTHESIS -DSQLITE_ENABLE_FTS4 -DSQLITE_ENABLE_FTS4_UNICODE61 -DSQLITE_ENABLE_JSON1 -DSQLITE_ENABLE_FTS5 -DHAVE_USLEEP=1 -DSQLITE_MAX_VARIABLE_NUMBER=99999"

make sqlite3.c

