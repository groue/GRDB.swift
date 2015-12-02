Release Notes
=============

## 0.32.1

Released December 2, 2015

**Fixed**

- `DatabaseCollation` did incorrectly process strings provided by sqlite.


## 0.32.0

Released November 23, 2015

**New**

- `DatabaseCollation` let you inject custom string comparison functions into SQLite.
- `DatabaseValue` adopts Hashable.
- `DatabaseValue.isNull` is true if a database value is NULL.
- `DatabaseValue.storage` exposes the underlying SQLite storage (NULL, INTEGER, REAL, TEXT, BLOB).


## 0.31.0

Released November 19, 2015

**New**

- `DatabaseFunction` lets you define custom SQL functions.


## 0.30.0

Released November 17, 2015

**Fixed**

- Prepared statements won't execute unless their arguments are all set.


## 0.29.0

Released November 14, 2015

**New**

- `DatabaseValue.init?(object: AnyObject)` initializer.
- `StatementArguments.Default` is the preferred sentinel for functions that have an optional arguments parameter.


**Breaking Changes**

- `Row.init?(dictionary: NSDictionary)` is now a failable initializer which returns nil if the NSDictionary contains invalid values.
- `RowConvertible.init?(dictionary: NSDictionary)` is now a failable initializer which returns nil if the NSDictionary contains invalid values.
- `StatementArguments.init?(_ array: NSArray)` is now a failable initializer which returns nil if the NSArray contains invalid values.
- `StatementArguments.init?(_ dictionary: NSDictionary)` is now a failable initializer which returns nil if the NSDictionary contains invalid values.
- All methods that used to have an `StatementArguments?` parameter with nil default value now have a non-optional `StatementArguments` parameter with `StatementArguments.Default` as a default value. This makes sure failable StatementArguments initializers don't let invalid inputs sneak in your queries.


## 0.28.0

Released November 13, 2015

**Breaking Change**

- The methods of protocol `TransactionObserverType` are no longer optional.


## 0.27.0

Released November 4, 2015

**New**

- `DatabaseCoder` reads and stores objects that conform to NSCoding in the database.
- `Database.inTransaction()` executes a block inside a database transaction.
- `DatabaseMigrator.registerMigrationWithoutForeignKeyChecks()` let you make arbitrary changes to the database schema, as described at https://www.sqlite.org/lang_altertable.html#otheralter.


**Breaking Changes**

- `Record.delete` returns a Bool which tells whether a database row was deleted or not.


## 0.26.1

Released October 31, 2015

**Fixed repository mess introduced by 0.26.0**


## 0.26.0

Released October 31, 2015

**Breaking Changes**

- The `fetch(:primaryKeys:)`, `fetchAll(:primaryKeys:)` and `fetchOne(:primaryKey:)` methods have been renamed `fetch(:keys:)`, `fetchAll(:keys:)` and `fetchOne(:key:)`.


## 0.25.0

Released October 29, 2015

**Fixed**

- `Record.reload(_)` is no longer a final method.
- GRDB always crashes when you try to convert a database NULL to a non-optional value.


**New**

- CGFloat can be stored and read from the database.
- `Person.fetch(_:primaryKeys:)` returns a sequence of objects with matching primary keys.
- `Person.fetchAll(_:primaryKeys:)` returns an array of objects with matching primary keys.
- `Person.fetch(_:keys:)` returns a sequence of objects with matching keys.
- `Person.fetchAll(_:keys:)` returns an array of objects with matching keys.


## 0.24.0

Released October 14, 2015

**Fixed**

- Restored iOS7 compatibility


## 0.23.0

Released October 13, 2015

**New**

- `Row()` initializes an empty row.

**Breaking Changes**

- NSData is now the canonical type for blobs. The former intermediate `Blob` type has been removed.
- `DatabaseValue.dataNoCopy()` has turned useless, and has been removed.


## 0.22.0

Released October 8, 2015

**New**

- `Database.sqliteConnection`: the raw SQLite connection, suitable for SQLite C API.
- `Statement.sqliteStatement`: the raw SQLite statement, suitable for SQLite C API.


## 0.21.0

Released October 1, 2015

**Fixed**

- `RowConvertible.awakeFromFetch(_)` is declared as `mutating`.


**New**

- Improved value extraction errors.

- `Row.hasColumn(_)`

- `RowConvertible` and `Record` get a dictionary initializer for free:

    ```swift
    class Person: Record { ... }
    let person = Person(dictionary: ["name": "Arthur", "birthDate": nil])
    ```

- Improved Foundation support:
    
    ```swift
    Row(dictionary: NSDictionary)
    Row.toDictionary() -> NSDictionary
    ```

- Int32 and Int64 enums are supported via DatabaseInt32Representable and DatabaseInt64Representable.


**Breaking Changes**

- `TraceFunction` is now defined as `(String) -> ()`


## 0.20.0

Released September 29, 2015

**New**

- Support for NSURL

**Breaking Changes**

- The improved TransactionObserverType protocol lets adopting types modify the database after a successful commit or rollback, and abort a transaction with an error.


## 0.19.0

Released September 28, 2015

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
