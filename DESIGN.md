The Design of GRDB.swift
========================

More than caveats or defects, there are a few glitches, or surprises in the GRDB.swift API. We try to explain them here.

- **Why can't NSDate, NSData and other classes adopt DatabaseValueConvertible, so that they can be used as query arguments, or fetched from the database?**
    
    Indeed, those types are indirectly supported: GRDB's Blob handles NSData, DatabaseDate handles NSDate, etc.
    
    This is because the `DatabaseValueConvertible` protocol requires adopting types to implement an initializer. Initializers can't be added to an extension of an existing non-final class, and all our fellow Objective-C friends are left out of the game.
    
    ```swift
    public protocol DatabaseValueConvertible {
        /// Returns a value that can be stored in the database.
        var databaseValue: DatabaseValue { get }
        
        /// Create an instance initialized to `databaseValue`.
        init?(databaseValue: DatabaseValue)
    }
    ```
    
    Don't expect this constraint to be lifted in a future version of the language. In Swift, subclasses don't have to support the non-required initializers of their superclass, and thus one can not add a required initializer in a class extension. In other words, the *potentiality* of an NSDate subclass that does not support DatabaseValueConvertible's initializer prevents NSDate to adopt it.
    
    This is an inconvenience for GRDB, because we need to define wrappers in order to support non-final classes. GRDB indeed ships with Blob, DatabaseDate and DatabaseDateComponents that wrap NSData, NSDate, and NSDateComponents.
    
    **Rationale**
    
    Yet we gain a big advantage: *DatabaseValueConvertible is not generic*. Being not generic, we can talk about arrays and dictionaries of heterogenous values adopting the protocol: `[DatabaseValueConvertible?]` and `[String: DatabaseValueConvertible?]` are usable types. And this is why you can easily provide query arguments:
    
    ```swift
    db.execute(
        "INSERT ... (?,?,?,?)",
        arguments: [1, "foo", Blob(...), DatabaseDate(...)]) // yum, soup!
    ```
    
    Feeding queries with data soup is a much more common use case than granting new types the ability to be stored and fetched from the database: the decision was very easy:
    
    - Keep DatabaseValueConvertible non generic
    - Lose NSObject
    - Provide and document built-in types that support the ultra-common NSData, NSDate and NSDateComponents.
    - Extra bonus: there are several ways to store dates in an SQLite database. The built-in DatabaseDate type provides a reasonable option, but it may not fit all needs. Fortunately, NSDate has not been polluted, and the user can write her own date support.
    
    **Exploration**
    
    Were there any other options?
    
    This one looks promising:
    
    ```swift
    protocol DatabaseValueConvertible2 {
        static func fromDatabaseValue(databaseValue: DatabaseValue) -> Self?
    }
    
    // Oops, nope.
    extension NSDate: DatabaseValueConvertible2 {
        // error: method 'fromDatabaseValue' in non-final class 'NSDate' must return `Self` to conform to protocol 'DatabaseValueConvertible2'
        static func fromDatabaseValue(databaseValue: DatabaseValue) -> NSDate? { ... }
    }
    ```
    
    Another try, with a generic protocol:
    
    ```swift
    protocol DatabaseValueConvertible3 {
        typealias ConvertedType
        static func fromDatabaseValue(databaseValue: DatabaseValue) -> ConvertedType?
    }
    
    // Boom, no arguments soup:
    // error: protocol 'DatabaseValueConvertible3' can only be used as a generic constraint because it has Self or associated type requirements
    let arguments: [DatabaseValueConvertible3] = []
    ```
    
    If you have another idea, I'm all ears!
    

- **Why is RowModel a class, when protocols are all the rage?**
    
    TODO
    
- **Why are DatabaseQueue.inTransaction() and DatabaseQueue.inDatabase() not reentrant?**
    
    TODO
    
- **Why must we provide query arguments in an Array, when Swift provides variadic method parameters?**
    
    TODO
    
