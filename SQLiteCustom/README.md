##GRDBCustomSQLite
Build GRDB with a custom version/configuration of SQLite embedded.

> **NOTE**: By default, SQLiteLib is built with [options essentially matching the built-in system library on OSX/iOS](https://github.com/swiftlyfalling/SQLiteLib/blob/master/README.md#default-compilation-options).

###To add an SQLite Compilation option:

1. Add it to the "*SQLiteLib-Custom.xcconfig*" in the **SQLiteLib.xcodeproj** to expose it to the SQLite build process ([see SQLiteLib reference](https://github.com/swiftlyfalling/SQLiteLib/blob/master/README.md))
2. Add it to the `CUSTOM_OTHER_SWIFT_FLAGS` line in "*GRDBCustomSQLite-Custom.xcconfig*", to expose it to GRDB's code.
3. Add it as a `#define` in "*GRDBCustomSQLite.h*", to expose it in the public headers for the built GRDBCustomSQLite framework.

####Example:

To build GRDBCustomSQLite with the [JSON SQL functions](https://www.sqlite.org/json1.html) enabled (`SQLITE_ENABLE_JSON1`).

1. Open "**[SQLiteLib-Custom.xcconfig](src/SQLiteLib-Custom.xcconfig)**" under **GRDBCustomSQLite > SQLiteLib.xcodeproj** in Xcode.
2. Append `-DSQLITE_ENABLE_JSON1` to the line `CUSTOM_SQLLIBRARY_CFLAGS`.

> Before:

> `CUSTOM_SQLLIBRARY_CFLAGS = -DSQLITE_ENABLE_PREUPDATE_HOOK`

> After:

> `CUSTOM_SQLLIBRARY_CFLAGS = -DSQLITE_ENABLE_PREUPDATE_HOOK -DSQLITE_ENABLE_JSON1`

3. Open "**[GRDBCustomSQLite-Custom.xcconfig](GRDBCustomSQLite-Custom.xcconfig)**" under the **GRDBCustomSQLite** group in Xcode.
4. Append `-D SQLITE_ENABLE_JSON1` to the line `CUSTOM_OTHER_SWIFT_FLAGS`.

> Before:

> `CUSTOM_OTHER_SWIFT_FLAGS = -D SQLITE_ENABLE_PREUPDATE_HOOK`

> After:

> `CUSTOM_OTHER_SWIFT_FLAGS = -D SQLITE_ENABLE_PREUPDATE_HOOK -D SQLITE_ENABLE_JSON1` 

5. Open "**[GRDBCustomSQLite.h](GRDBCustomSQLite.h)**" under the **GRDBCustomSQLite** group in Xcode.
6. Append a line containing `#define SQLITE_ENABLE_JSON1` after `// INSERT ANY ADDITIONAL SQLITE DEFINES HERE`

### To use a custom version of SQLite:

[See the SQLiteLib reference](https://github.com/swiftlyfalling/SQLiteLib/blob/master/README.md)
