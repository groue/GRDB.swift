##GRDBCustomSQLite
Build GRDB with a custom version/configuration of SQLite embedded.

> **NOTE**: By default, SQLiteLib is built with [options essentially matching the built-in system library on OSX/iOS](https://github.com/swiftlyfalling/SQLiteLib/blob/master/README.md#default-compilation-options).

**TIP:** Build GRDBCustomSQLite once to generate the USER config files from the `.example` files.
Future builds should remove any warnings about missing files. (These warnings don't affect functionality.)

###Configuration / Before First Build:

To build without warnings, you need to generate the USER configuration files.

**Option A:**

Simply run build once, and the project will automatically generate them.

**Option B:**

If you'd prefer to do it manually, copy the appropriate .example files and rename them to the required files below:

- `GRDBCustomSQLite-USER.h`
- `GRDBCustomSQLite-USER.xcconfig`
- `src/SQLiteLib-USER.xcconfig` (required by the SQLiteLib project)


###To add an SQLite Compilation option:

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

### To use a custom version of SQLite:

[See the SQLiteLib reference](https://github.com/swiftlyfalling/SQLiteLib/blob/master/README.md)
