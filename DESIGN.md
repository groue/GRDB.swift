The Design of GRDB.swift
========================

More than caveats or defects, there are a few glitches, or surprises in the GRDB.swift API. We try to explain them here. And eventually, explanations may lead to solutions :-)


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
    
- **Why are DatabaseQueue.inTransaction() and DatabaseQueue.inDatabase() not reentrant?**
    
    TODO
    
- **Why must we provide query arguments in an Array, when Swift provides variadic method parameters?**
    
    TODO
    
