- [ ] #2: this commit may be how stephencelis fixed it: https://github.com/stephencelis/SQLite.swift/commit/8f64e357c3a6668c5f011c91ba33be3e8d4b88d0
- [ ] Use @warn_unused_result where applicable
- [ ] Turn DatabaseTableMapping into a private protocol
- [ ] Ship TableChangeObserver with the library.

Not sure:

- [ ] See how https://www.sqlite.org/c3ref/column_database_name.html could help Record.
- [ ] Since Records' primary key are infered, no operation is possible on the primary key unless we have a Database instance. It's impossible to define the record.primaryKey property, or to provide a copy() function that does not clone the primary key: they miss the database that is the only object aware of the primary key. Should we change our mind, and have Record explicitly expose their primary key again?


Require changes in the Swift language:

- [ ] Turn DatabaseIntRepresentable and DatabaseStringRepresentable into SQLiteStatementConvertible when Swift allows for it.
- [ ] Specific and optimized Optional<SQLiteStatementConvertible>.fetch... methods when rdar://22852669 is fixed.
