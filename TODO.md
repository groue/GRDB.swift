- [ ] #2: this commit may be how stephencelis fixed it: https://github.com/stephencelis/SQLite.swift/commit/8f64e357c3a6668c5f011c91ba33be3e8d4b88d0
- [ ] Use @warn_unused_result where applicable
- [ ] Turn DatabaseTableMapping into a private protocol
- [ ] Expose raw SQLite connection and statement handles. Without them the user won't be able to perform operations that don't have a matching GRDB API.
- [ ] Ship TableChangeObserver with the library.
- [ ] Study VACUUM (https://blogs.gnome.org/jnelson/)
- [ ] Study full text search (related: https://blogs.gnome.org/jnelson/)
- [ ] Study SQLCipher
- [ ] Study save points http://www.sqlite.org/lang_savepoint.html
- [ ] Study custom SQL functions
- [ ] Study custom collations
- [ ] Study https://www.sqlite.org/undoredo.html
- [ ] Study http://www.sqlite.org/intern-v-extern-blob.html
- [ ] Check if we have tests for DatabaseValueConvertible adoption by DatabaseValue


Not sure:

- [ ] Since Records' primary key are infered, no operation is possible on the primary key unless we have a Database instance. It's impossible to define the record.primaryKey property, or to provide a copy() function that does not clone the primary key: they miss the database that is the only object aware of the primary key. Should we change our mind, and have Record explicitly expose their primary key again?


Require changes in the Swift language:

- [ ] Turn DatabaseIntRepresentable and DatabaseStringRepresentable into SQLiteStatementConvertible when Swift allows for it.
- [ ] Specific and optimized Optional<SQLiteStatementConvertible>.fetch... methods when rdar://22852669 is fixed.


Requires recompilation of SQLite:

- [ ] https://www.sqlite.org/c3ref/column_database_name.html could help extracting out of a row a subrow only made of columns that come from a specific table. Requires SQLITE_ENABLE_COLUMN_METADATA which is not set on the sqlite3 lib that ships with OSX.
