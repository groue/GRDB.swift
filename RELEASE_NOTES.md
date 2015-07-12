Release Notes
=============

## 0.4.0

**Breaking changes**

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
