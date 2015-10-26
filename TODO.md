- [ ] #2: this commit may be how stephencelis fixed it: https://github.com/stephencelis/SQLite.swift/commit/8f64e357c3a6668c5f011c91ba33be3e8d4b88d0
- [ ] Study SQLCipher
- [ ] Study custom SQL functions
- [ ] Study custom collations
- [ ] `IN (?)` sql snippet, with an array argument.
- [ ] http://stackoverflow.com/questions/33306519/fmdb-retrieval-of-null-values-for-value-types-in-swift - stop letting sqlite silently converting NULL to zero (see Row.swift).


Not sure:

- [ ] Since Records' primary key are infered, no operation is possible on the primary key unless we have a Database instance. It's impossible to define the record.primaryKey property, or to provide a copy() function that does not clone the primary key: they miss the database that is the only object aware of the primary key. Should we change our mind, and have Record explicitly expose their primary key again?
- [ ] Have Record adopt Hashable and Equatable, based on primary key. Problem: we can't do it know because we don't know the primary key until we have a database connection.
- [ ] Support for UIColor (through NSCoding? "#RRGGBB"? "rgba(r,g,b,a)"?
- [ ] Support for NSUUID (with documentation about preferred collation)


Require changes in the Swift language:

- [ ] Turn DatabaseIntRepresentable and DatabaseStringRepresentable into SQLiteStatementConvertible when Swift allows for it.
- [ ] Specific and optimized Optional<SQLiteStatementConvertible>.fetch... methods when rdar://22852669 is fixed.


Requires recompilation of SQLite:

- [ ] https://www.sqlite.org/c3ref/column_database_name.html could help extracting out of a row a subrow only made of columns that come from a specific table. Requires SQLITE_ENABLE_COLUMN_METADATA which is not set on the sqlite3 lib that ships with OSX.



Reading list:

- VACUUM (https://blogs.gnome.org/jnelson/)
- Full text search (https://www.sqlite.org/fts3.html. Related: https://blogs.gnome.org/jnelson/)
- https://www.sqlite.org/undoredo.html
- http://www.sqlite.org/intern-v-extern-blob.html
