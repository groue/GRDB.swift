Release Notes
=============

## Next Release

**New**

- The `Configuration.transactionObserver` lets you observe database changes.


## 0.18.0

Released September 26, 2015

**Fixed**

- It is now mandatory to provide values for all arguments of an SQL statement. GRDB used to assume NULL for missing ones.

**New**

- `Row.dataNoCopy(atIndex:)` and `Row.dataNoCopy(named:)`.
- `Blob.dataNoCopy`
- `DatabaseValue.dataNoCopy`

**Breaking Changes**

- `String.fetch...` now returns non-optional values. Use `Optional<String>.fetch...` when values may be NULL.


## 0.17.0

Released September 24, 2015

**New**

- Performance improvements.
- You can extract non-optional values from Row and DatabaseValue.
- Types that adopt SQLiteStatementConvertible on top of the DatabaseValueConvertible protocol are granted with faster database access.

**Breaking Changes**

- Rows can be reused during a fetch query iteration. Use `row.copy()` to keep one.
- Database sequences are now of type DatabaseSequence.
- Blob and NSData relationships are cleaner.


## 0.16.0

Released September 14, 2015

**New**

- `Configuration.busyMode` let you specify how concurrent connections should handle database locking.
- `Configuration.transactionType` let you specify the default transaction type.

**Breaking changes**

- Default transaction type has changed from EXCLUSIVE to IMMEDIATE.


## 0.15.0

Released September 12, 2015

**Fixed**

- Usage assertions used to be disabled. They are activated again.

**Breaking changes**

- `DatabaseQueue.inDatabase` and `DatabaseQueue.inTransaction` are no longer reentrant.


## 0.14.0

Released September 12, 2015

**Fixed**

- `DatabaseQueue.inTransaction()` no longer crashes when SQLite returns a SQLITE_BUSY error code.

**Breaking changes**

- `Database.updateStatement(_:)` is no longer a throwing method.
- `DatabaseQueue.inTransaction()` is now declared as `throws`, not `rethrows`.


## 0.13.0

Released September 10, 2015

**New**

- `DatabaseQueue.inDatabase` and `DatabaseQueue.inTransaction` are now reentrant. You can't open a transaction inside another, though.
- `Record.copy()` returns a copy of the receiver.
- `Row[columnName]` and `Row.value(named:)` are now case-insensitive.

**Breaking changes**

- Requires Xcode 7.0 (because of [#2](https://github.com/groue/GRDB.swift/issues/2))
- `RowModel` has been renamed `Record`.
- `Record.copyDatabaseValuesFrom` has been removed in favor of `Record.copy()`.
- `Record.awakeFromFetch()` now takes a row argument.


## 0.12.0

Released September 6, 2015

**New**

- `RowConvertible` and `DatabaseTableMapping` protocols grant any type the fetching methods that used to be a privilege of `RowModel`.
- `Row.columnNames` returns the names of columns in the row.
- `Row.databaseValues` returns the database values in the row.
- `Blob.init(bytes:length:)` is a new initializer.
- `DatabaseValueConvertible` can now be adopted by non-final classes.
- `NSData`, `NSDate`, `NSNull`, `NSNumber` and `NSString` adopt `DatabaseValueConvertible` and can natively be stored and fetched from a database.

**Breaking changes**

- `DatabaseDate` has been removed (replaced by built-in NSDate support).
- `DatabaseValueConvertible`: `init?(databaseValue:)` has been replaced by `static func fromDatabaseValue(_:) -> Self?`
- `Blob.init(_:)` has been replaced with `Blob.init(data:)` and `Blob.init(dataNoCopy:)`.
- `RowModel.edited` has been renamed `RowModel.databaseEdited`.
- `RowModel.databaseTable` has been replaced with `RowModel.databaseTableName()` which returns a String.
- `RowModel.setDatabaseValue(_:forColumn:)` has been removed. Use and override `RowModel.updateFromRow(_:)` instead.
- `RowModel.didFetch()` has been renamed `RowModel.awakeFromFetch()`


## 0.11.0

Released September 4, 2015

**Breaking changes**

The fetching methods are now available on the fetched type themselves:

```swift
dbQueue.inDatabase { db in
    Row.fetch(db, "SELECT ...", arguments: ...)        // AnySequence<Row>
    Row.fetchAll(db, "SELECT ...", arguments: ...)     // [Row]
    Row.fetchOne(db, "SELECT ...", arguments: ...)     // Row?
    
    String.fetch(db, "SELECT ...", arguments: ...)     // AnySequence<String?>
    String.fetchAll(db, "SELECT ...", arguments: ...)  // [String?]
    String.fetchOne(db, "SELECT ...", arguments: ...)  // String?
    
    Person.fetch(db, "SELECT ...", arguments: ...)     // AnySequence<Person>
    Person.fetchAll(db, "SELECT ...", arguments: ...)  // [Person]
    Person.fetchOne(db, "SELECT ...", arguments: ...)  // Person?
}
```


## 0.10.0

Released September 4, 2015

**New**

- `DatabaseValue` adopts `DatabaseValueConvertible`: a fetched value can be used as an argument of another query, without having to convert the raw database value into a regular Swift type.
- `Row.init(dictionary)` lets you create a row from scratch.
- `RowModel.didFetch()` is an overridable method that is called after a RowModel has been fetched or reloaded.
- `RowModel.updateFromRow(row)` is an overridable method that helps updating compound properties that do not fit in a single column, such as CLLocationCoordinate2D.


## 0.9.0

Released August 25, 2015

**Fixed**

- Reduced iOS Deployment Target to 8.0, and OSX Deployment Target to 10.9.
- `DatabaseQueue.inTransaction()` is now declared as `rethrows`.

**Breaking changes**

- Requires Xcode 7 beta 6
- `QueryArguments` has been renamed `StatementArguments`.


## 0.8.0

Released August 18, 2015

**New**

- `RowModel.exists(db)` returns whether a row model has a matching row in the database.
- `Statement.arguments` property gains a public setter.
- `Database.executeMultiple(sql)` can execute several SQL statements separated by a semi-colon ([#6](http://github.com/groue/GRDB.swift/pull/6) by [peter-ss](https://github.com/peter-ss))

**Breaking changes**

- `UpdateStatement.Changes` has been renamed `DatabaseChanges` ([#6](http://github.com/groue/GRDB.swift/pull/6) by [peter-ss](https://github.com/peter-ss)).


## 0.7.0

Released July 30, 2015

**New**

- `RowModel.delete(db)` returns whether a database row was deleted or not.

**Breaking changes**

- `RowModelError.InvalidPrimaryKey` has been replaced by a fatal error.


## 0.6.0

Released July 30, 2015

**New**

- `DatabaseDate` can read dates stored as Julian Day Numbers.
- `Int32` can be stored and fetched.


## 0.5.0

Released July 22, 2015

**New**

- `DatabaseDate` handles storage of NSDate in the database.
- `DatabaseDateComponents` handles storage of NSDateComponents in the database.

**Fixed**

- `RowModel.save(db)` calls `RowModel.insert(db)` or `RowModel.update(db)` so that eventual overridden versions of `insert` or `update` are invoked.
- `QueryArguments(NSArray)` and `QueryArguments(NSDictionary)` now accept NSData elements.

**Breaking changes**

- "Bindings" has been renamed "QueryArguments", and `bindings` parameters renamed `arguments`.
- Reusable statements no longer expose any setter for their `arguments` property, and no longer accept any arguments in their initializer. To apply arguments, give them to the `execute()` and `fetch()` methods.
- `RowModel.isEdited` and `RowModel.setEdited()` have been replaced by the `RowModel.edited` property.


## 0.4.0

Released July 12, 2015

**Fixed**

- `RowModel.save(db)` makes its best to store values in the database. In particular, when the row model has a non-nil primary key, it will insert when there is no row to update. It used to throw RowModelNotFound in this case.


## v0.3.0

Released July 11, 2015

**New**

- `Blob.init?(NSData?)`

    Creates a Blob from NSData. Returns nil if and only if *data* is nil or zero-length (SQLite can't store empty blobs).

- `RowModel.isEdited`

    A boolean that indicates whether the row model has changes that have not been saved.

    This flag is purely informative: it does not alter the behavior the update() method, which executes an UPDATE statement in every cases.

    But you can prevent UPDATE statements that are known to be pointless, as in the following example:

    ```swift
    let json = ...

    // Fetches or create a new person given its ID:
    let person = Person.fetchOne(db, primaryKey: json["id"]) ?? Person()

    // Apply json payload:
    person.updateFromJSON(json)

    // Saves the person if it is edited (fetched then modified, or created):
    if person.isEdited {
        person.save(db) // inserts or updates
    }
    ```

- `RowModel.copyDatabaseValuesFrom(_:)`

    Updates a row model with values of another one.

- `DatabaseValue` adopts Equatable.

**Breaking changes**

- `RowModelError.UnspecifiedTable` and `RowModelError.InvalidDatabaseDictionary` have been replaced with fatal errors because they are programming errors.

## v0.2.0

Released July 9, 2015

**Breaking changes**

- Requires Xcode 7 beta 3

**New**

- `RowModelError.InvalidDatabaseDictionary`: new error case that helps you designing a fine RowModel subclass.


## v0.1.0

Released July 9, 2015

Initial release
