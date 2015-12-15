- [ ] #2: this commit may be how stephencelis fixed it: https://github.com/stephencelis/SQLite.swift/commit/8f64e357c3a6668c5f011c91ba33be3e8d4b88d0
- [ ] Study SQLCipher
- [ ] `IN (?)` sql snippet, with an array argument.
- [ ] Write sample code around NSFetchedResultsController: fetch and output a list of TableView sections & row differences.
- [ ] Compare DatabaseCoder with http://mjtsai.com/blog/2015/11/08/the-java-deserialization-bug-and-nssecurecoding/
- [ ] Now that DatabasePersistable is out, Record has this didInsertWithRowID(:forColumn:) which calls updateFromRow. When we document "The updateFromRow method MUST NOT assume the presence of particular columns. The Record class itself reserves the right to call updateFromRow with arbitrary columns", we are actually talking about didInsertWithRowID, which is now exposed. Users may be confused.
- [ ] What happens when RowConvertible.awakeFromFetch and DatabasePersistable.didInsertWithRowID(_:forColumn:) assign to self? Do we need to split RowConvertible into MutableRowConvertible + RowConvertible?
- [ ] Check Swift API Guideline https://swift.org/documentation/api-design-guidelines.html
    - [ ] databaseTableName, etc.
    - [ ] didInsertWithRowID(_:forColumn:)
    - [ ] databaseEdited -> hasDatabaseChanges, hasNotPersistedChanges ? Check if doc makes it clear that the changes are based on last fetch. The method name should make it clear too.
    - [ ] Read conversion methods conventions (fromRow, fromDatabaseValue)
- [X] Row.value(named:) should return nil if column is not there.
    - [X] Row.value(named:) returns nil if column is not there.
    - [X] Update documentation
- [ ] Conversion should crash when type mismatch (Optional<String>.fetchOne(db, "SELECT 1"))
- [ ] Record:
    - [X] Remove reloading
    - [X] Expose didInsertWithRowID(_:forColumn:)
    - [X] Make Person subclass that eats an extra column easier to write (in PersonWithOverrides)
    - [X] Update Record documentation
    - [X] Update Record playground
    - [ ] Update JSONSynchronisation playground
    - [ ] Update https://gist.github.com/groue/dcdd3784461747874f41

Not sure:

- [ ] Since Records' primary key are infered, no operation is possible on the primary key unless we have a Database instance. It's impossible to define the record.primaryKey property, or to provide a copy() function that does not clone the primary key: they miss the database that is the only object aware of the primary key. Should we change our mind, and have Record explicitly expose their primary key again?
- [ ] Have Record adopt Hashable and Equatable, based on primary key. Problem: we can't do it know because we don't know the primary key until we have a database connection.


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
