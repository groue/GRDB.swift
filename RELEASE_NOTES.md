Release Notes
=============

## Next Release

**New**

- `RowModel.delete(db)` returns whether a database row was deleted or not.

**Breaking changes**

- RowModelError.InvalidPrimaryKey has been replaced by a fatal error.


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
    let person = db.fetchOne(Person.self, primaryKey: json["id"]) ?? Person()

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

- Requires Xcode 7.0 beta 3

**New**

- `RowModelError.InvalidDatabaseDictionary`: new error case that helps you designing a fine RowModel subclass.


## v0.1.0

Released July 9, 2015

Initial release
