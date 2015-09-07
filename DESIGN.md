The Design of GRDB.swift
========================

More than caveats or defects, there are a few glitches, or surprises in the GRDB.swift API. We try to explain them here. The interested readers can take them as Swift challenges!

- **Why is RowModel a class, when protocols are all the rage?**
    
    Easy: Swift protocols don't provide `super`.
    
    ```swift
    // A RowModel that makes sure its UUID is set before insertion:
    class A : RowModel {
        var UUID: NSString?
        override func insert(db: Database) throws {
            if UUID == nil {
                UUID = NSUUID().UUIDString
            }
            try super.insert()
        }
    }
    
    // A RowModel that validates itself before saving:
    class B : RowModel {
        override func insert(db: Database) throws {
            try validate()
            try super.insert(db)
        }
        override func update(db: Database) throws {
            try validate()
            try super.update(db)
        }
        func validate() throws {
            ...
        }
    }
    ```
    
    A second reason: the `databaseEdited` flag, which is true when a RowModel has unsaved changes, is easily provided by the base class RowModel. RowModel can manage its internal state *accross method calls*. Protocols could not provide this service without extra complexity.
    
    Yet, don't miss the [RowConvertible](http://cocoadocs.org/docsets/GRDB.swift/0.12.0/Protocols/RowConvertible.html) and [DatabaseMapping](http://cocoadocs.org/docsets/GRDB.swift/0.12.0/Protocols/DatabaseTableMapping.html) protocols: they provide fetching from custom SQL queries and fetching by primary key for free.
    
    
- **Why are DatabaseQueue.inTransaction() and DatabaseQueue.inDatabase() not reentrant?**
    
    TODO
    
- **Why must we provide query arguments in an Array, when Swift provides variadic method parameters?**
    
    TODO
    
