#GRDBCustomSQLite
Build GRDB with a custom version/configuration of SQLite embedded.

> **NOTE**: By default, SQLiteLib is built with [options essentially matching the built-in system library on OSX/iOS](https://github.com/swiftlyfalling/SQLiteLib/blob/master/README.md#default-compilation-options).

> **TIP:** Build GRDBCustomSQLite once to generate the USER config files from the `.example` files.
Future builds should remove any warnings about missing files. (These warnings don't affect functionality.)

##Configuration / Before First Build:

To build without warnings, you need to generate the USER configuration files.

**Option A:**

Simply run build once, and the project will automatically generate them.

**Option B:**

If you'd prefer to do it manually, copy the appropriate .example files and rename them to the required files below:

- `GRDBCustomSQLite-USER.h`
- `GRDBCustomSQLite-USER.xcconfig`
- `src/SQLiteLib-USER.xcconfig` (required by the SQLiteLib project)


##To add a SQLite compilation option:

1. Add it to the "*SQLiteLib-USER.xcconfig*" in the **SQLiteLib.xcodeproj** to expose it to the SQLite build process ([see SQLiteLib reference](https://github.com/swiftlyfalling/SQLiteLib/blob/master/README.md))
2. Add it to the `CUSTOM_OTHER_SWIFT_FLAGS` line in "*GRDBCustomSQLite-USER.xcconfig*", to expose it to GRDB's code.
3. Add it as a `#define` in "*GRDBCustomSQLite-USER.h*", to expose it in the public headers for the built GRDBCustomSQLite framework.

####Example:

To build GRDBCustomSQLite with the [JSON SQL functions](https://www.sqlite.org/json1.html) enabled (`SQLITE_ENABLE_JSON1`).

1. Open "**[SQLiteLib-USER.xcconfig](src/SQLiteLib-USER.xcconfig.example)**" under **GRDBCustomSQLite > SQLiteLib.xcodeproj** in Xcode.
2. Append `-DSQLITE_ENABLE_JSON1` to the line `CUSTOM_SQLLIBRARY_CFLAGS`.

> Before:

> `CUSTOM_SQLLIBRARY_CFLAGS = `

> After:

> `CUSTOM_SQLLIBRARY_CFLAGS = -DSQLITE_ENABLE_JSON1`

3. Open "**[GRDBCustomSQLite-USER.xcconfig](GRDBCustomSQLite-USER.xcconfig.example)**" under the **GRDBCustomSQLite > Customize** group in Xcode.
4. Append `-D SQLITE_ENABLE_JSON1` to the line `CUSTOM_OTHER_SWIFT_FLAGS`.

> Before:

> `CUSTOM_OTHER_SWIFT_FLAGS = `

> After:

> `CUSTOM_OTHER_SWIFT_FLAGS = -D SQLITE_ENABLE_JSON1` 

5. Open "**[GRDBCustomSQLite-USER.h](GRDBCustomSQLite-USER.h.example)**" under the **GRDBCustomSQLite > Customize** group in Xcode.
6. Append a line containing `#define SQLITE_ENABLE_JSON1` after `// INSERT ANY ADDITIONAL SQLITE DEFINES HERE:`

## To use a custom version of SQLite:

Please see the [SQLiteLib reference](https://github.com/swiftlyfalling/SQLiteLib/blob/master/README.md) for details.

## Automatically Sync GRDBCustomSQLite Configuration:

If you have a project containing GRDB, you wish to use GRDBCustomSQLite, and you wish to automate propagating the GRDBCustomSQLite configuration files from within your main project, read on:

> :bulb: **NOTE:**

> Use this technique to store the GRDBCustomSQLite "USER" config files in your project's Git repo, and sync changes to the expected locations for building GRDBCustomSQLite.

For each Scheme in your main project in Xcode:

1. "Edit Scheme..."
2. Expand the "Build" option.
3. Select "Pre-actions".
4. Click the "+" button and select "New Run Script Action".

In the new "Run Script" action:

1. Set "**Shell**" to `/bin/sh` (without quotes)
2. Set "**Provide build settings from**" to your Target.
3. In the script box, enter the following script
(modifying the paths in the "PROJECT PATHS" section to match the locations of the respective files in your project):

> :heavy_exclamation_mark: **IMPORTANT**: 
> You **must** modify the paths in the script below to match your project's directory setup.

```sh

#
# Sync USER Configuration Files
#
# Last Updated: 2016-05-31 (A)
#
# License: MIT License
# https://github.com/swiftlyfalling/SQLiteLib/blob/master/LICENSE

#######################################################
#                   PROJECT PATHS
#  !! MODIFY THESE TO MATCH YOUR PROJECT HIERARCHY !!
#######################################################

# The path to the folder containing GRDB.xcodeproj:
GRDB_SOURCE_PATH="${PROJECT_DIR}/Externals/GRDB"

# The path to your custom "SQLiteLib-USER.xcconfig":
SQLITELIB_XCCONFIG_USER_PATH="${PROJECT_DIR}/SQLiteLib-USER.xcconfig"

# The path to your custom "GRDBCustomSQLite-USER.xcconfig":
CUSTOMSQLITE_XCCONFIG_USER_PATH="${PROJECT_DIR}/GRDBCustomSQLite-USER.xcconfig"

# The path to your custom "GRDBCustomSQLite-USER.h":
CUSTOMSQLITE_H_USER_PATH="${PROJECT_DIR}/GRDBCustomSQLite-USER.h"

#######################################################
# 
#######################################################


if [ ! -d "$GRDB_SOURCE_PATH" ];
then
  echo "error: Path to GRDB source (GRDB_SOURCE_PATH) missing/incorrect: $GRDB_SOURCE_PATH"
  exit 1
fi

SyncFileChanges () {
  SOURCE=$1
  DESTINATIONPATH=$2
  DESTINATIONFILENAME=$3
  DESTINATION="${DESTINATIONPATH}/${DESTINATIONFILENAME}"

  if [ ! -f "$SOURCE" ];
  then
    echo "error: Source file missing: $SOURCE"
    exit 1
  fi

  rsync -a "$SOURCE" "$DESTINATION"
}

SyncFileChanges $SQLITELIB_XCCONFIG_USER_PATH "${GRDB_SOURCE_PATH}/SQLiteCustom/src" "SQLiteLib-USER.xcconfig"
SyncFileChanges $CUSTOMSQLITE_XCCONFIG_USER_PATH "${GRDB_SOURCE_PATH}/SQLiteCustom" "GRDBCustomSQLite-USER.xcconfig"
SyncFileChanges $CUSTOMSQLITE_H_USER_PATH "${GRDB_SOURCE_PATH}/SQLiteCustom" "GRDBCustomSQLite-USER.h"

echo "Finished syncing"

```

This will ensure that the files are synced before any of the projects are built.

> **NOTE:** Xcode Scheme pre-action Run Script phases do not output errors to the Xcode build log.
