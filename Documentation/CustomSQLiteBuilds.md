Custom SQLite Builds
====================

By default, GRDB uses the version of SQLite that ships with the target operating system.

**You can build GRDB with a custom build of [SQLite 3.15.2](https://www.sqlite.org/changes.html).**

A custom SQLite build can activate extra SQLite features, and extra GRDB features as well, such as support for the [FTS5 full-text search engine](../../../#full-text-search), and [SQLite Pre-Update Hooks](../../../#support-for-sqlite-pre-update-hooks).

GRDB builds SQLite with [swiftlyfalling/SQLiteLib](https://github.com/swiftlyfalling/SQLiteLib), which uses the same SQLite configuration as the one used by Apple in its operating systems, and lets you add extra compilation options that leverage the features you need.

**To install GRDB with a custom SQLite build:**

1. Clone the GRDB.swift git repository, checkout the latest tagged version, and download SQLite sources:
    
    ```sh
    cd [GRDB.swift directory]
    git checkout v0.99.1
    git submodule update --init SQLiteCustom/src
    ````
    
2. Choose your [extra compilation options](https://www.sqlite.org/compile.html). For example, `SQLITE_ENABLE_FTS5` and `SQLITE_ENABLE_PREUPDATE_HOOK`.

3. Create a folder named `GRDBCustomSQLite` somewhere in your project directory.

4. Create four files in the `GRDBCustomSQLite` folder:

    - `SQLiteLib-USER.xcconfig`: this file sets the extra SQLite compilation flags.
        
        ```xcconfig
        // As many -D options as there are custom SQLite compilation options
        // Note: there is no space between -D and the option name.
        CUSTOM_SQLLIBRARY_CFLAGS = -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_PREUPDATE_HOOK
        ```
    
    - `GRDBCustomSQLite-USER.xcconfig`: this file lets GRDB know about extra compilation flags, and enables extra GRDB APIs.
        
        ```xcconfig
        // As many -D options as there are custom SQLite compilation options
        // Note: there is one space between -D and the option name.
        CUSTOM_OTHER_SWIFT_FLAGS = -D SQLITE_ENABLE_FTS5 -D SQLITE_ENABLE_PREUPDATE_HOOK
        ```
    
    - `GRDBCustomSQLite-USER.h`: this file lets your application know about extra compilation flags.
        
        ```c
        // As many #define as there are custom SQLite compilation options
        #define SQLITE_ENABLE_FTS5
        #define SQLITE_ENABLE_PREUPDATE_HOOK
        ```
    
    - `GRDBCustomSQLite-INSTALL.sh`: this file installs the three other files.
        
        ```sh
        # License: MIT License
        # https://github.com/swiftlyfalling/SQLiteLib/blob/master/LICENSE
        #
        #######################################################
        #                   PROJECT PATHS
        #  !! MODIFY THESE TO MATCH YOUR PROJECT HIERARCHY !!
        #######################################################
        
        # The path to the folder containing GRDB.xcodeproj:
        GRDB_SOURCE_PATH="${PROJECT_DIR}/GRDB"
        
        # The path to your custom "SQLiteLib-USER.xcconfig":
        SQLITELIB_XCCONFIG_USER_PATH="${PROJECT_DIR}/GRDBCustomSQLite/SQLiteLib-USER.xcconfig"
        
        # The path to your custom "GRDBCustomSQLite-USER.xcconfig":
        CUSTOMSQLITE_XCCONFIG_USER_PATH="${PROJECT_DIR}/GRDBCustomSQLite/GRDBCustomSQLite-USER.xcconfig"
        
        # The path to your custom "GRDBCustomSQLite-USER.h":
        CUSTOMSQLITE_H_USER_PATH="${PROJECT_DIR}/GRDBCustomSQLite/GRDBCustomSQLite-USER.h"
        
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
        
        Modify the top of `GRDBCustomSQLite-INSTALL.sh` file so that it contains correct paths.

5. Embed the `GRDB.xcodeproj` project in your own project.

6. Add the `GRDBCustomSQLiteOSX` or `GRDBCustomSQLiteiOS` target in the **Target Dependencies** section of the **Build Phases** tab of your **application target**.

7. Add the `GRDBCustomSQLite.framework` from the targetted platform to the **Embedded Binaries** section of the **General**  tab of your **application target**.

8. Add a Run Script phase for your target in the **Pre-actions** section of the **Build** tab of your **application scheme**:
    
    ```sh
    source "${PROJECT_DIR}/GRDBCustomSQLite/GRDBCustomSQLite-INSTALL.sh"
    ```
    
    The path should be the path to your `GRDBCustomSQLite-INSTALL.sh` file.

9. Check the "Shared" checkbox of your application scheme (this lets you commit the pre-action in your Version Control System).

Now you can use GRDB with your custom SQLite build:

```swift
import GRDBCustomSQLite

let dbQueue = try DatabaseQueue(...)
```
