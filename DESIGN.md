The Design of GRDB.swift
========================

More than caveats or defects, there are a few glitches, or surprises in the GRDB.swift API. We try to explain them here. The interested readers can take them as Swift challenges!

- **Why is RowModel a class, when protocols are all the rage?**
    
    Easy: Swift protocols don't provide `super`, and `super` is what turns RowModel into the flexible base class you need when you implement your specific needs:
    
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
    
    I, the library author, do not like database accesses to be hidden behind innocent-looking methods.
    
    For example, assuming a global `dbQueue`, let's compare:
    
    ```swift
    class Person {
        // Hidden database access:
        class func personsSortedByName() -> [Person] {
            return dbQueue.inDatabase { db in
                Person.fetchAll(db, "SELECT * FROM persons ORDER BY name")
            }
        }
        // Exposed database access:
        class func fetchPersonsSortedByName(db: Database) -> [Person] {
            return Person.fetchAll(db, "SELECT * FROM persons ORDER BY name")
        }
    }
    ```
    
    The first hides the database access, and will crash as soon as it is used inside a database block:
    
    ```swift
    dbQueue.inDatabase { db in
        // fatal error: DatabaseQueue.inDatabase(_:) was called reentrantly
        // on the same queue, which would lead to a deadlock.
        let persons = Person.personsSortedByName()
        ...
    }
    ```
    
    Sooner or later, it will have to be refactored into the second version:

    ```swift
    dbQueue.inDatabase { db in
        let persons = Person.fetchPersonsSortedByName(db)
        ...
    }
    ```
    
- **Why must we provide query arguments in an Array, when Swift provides variadic method parameters?**
    
    I admit that the array argument below looks odd:
    
    ```swift
    Int.fetch(db,
        "SELECT COUNT(*) FROM persons WHERE name = ?",
        arguments: ["Arthur"])
    ```
    
    The reason is one of my pet-peeves with SQLite, which is that it is a pain to write an SQL query with the `IN` operator because SQLite won't feed a single `?` placeholder with an array of values:
    
    ```swift
    // Let's load persons whose name is in names:
    let names = ["Arthur", "Barbara"]
    let questioMarks = Array(count: names.count, repeatedValue: "?").joinWithSeparator(",") // OMG Swift come on
    let sql = "SELECT * FROM persons WHERE name IN (\(questioMarks))"
    let persons = Person.fetchAll(db, sql, arguments: StatementArguments(names))
    ```
    
    I wish that in a future version of GRDB, we can write instead:
    
    ```swift
    let persons = Person.fetchAll(db,
        "SELECT * FROM persons WHERE name IN (?)",
        arguments: [["Arthur", "Barbara"]])
    ```
    
    This will require to distinguish arrays of values from arrays of arrays of values, and... Oh maybe I'm misled here... TO BE CONTINUED...
