Migrating From GRDB 3 to GRDB 4
===============================

GRDB 4 comes with new features, but also a few breaking changes. This guide aims at helping you upgrading your applications.

- [New requirements](#new-requirements)
- [Raw SQL](#raw-sql)
- [ValueObservation](#valueobservation)
- [Associations](#associations)
- [Good Practices for Designing Record Types](GoodPracticesForDesigningRecordTypes.md)
- [SQLCipher](#sqlcipher)
- [PersistenceError.recordNotFound](#persistenceerrorrecordnotfound)


### New requirements

GRDB now requires Swift 4.2+ and Xcode 10+. Swift 4.0 and 4.1 are no longer supported. Xcode 9 is no longer supported.

iOS 8 is no longer supported. The minimum iOS target is now iOS 9.


### Raw SQL

Whenever your application uses raw SQL queries or snippets, you will now always have to use the `sql` argument label:

```swift
// GRDB 3
try db.execute("INSERT INTO player (name) VALUES (?)", arguments: ["Arthur"])
let playerCount = try Int.fetchOne(db, "SELECT COUNT(*) FROM player")

// GRDB 4
try db.execute(sql: "INSERT INTO player (name) VALUES (?)", arguments: ["Arthur"])
let playerCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player")
```

This change was made necessary by the introduction of [SQL Interpolation].


### ValueObservation

[ValueObservation] has been refreshed in GRDB 4.

To guarantee asynchronous notifications, and never ever block your main thread, use the `.async(onQueue:startImmediately:)` scheduling:

```swift
// On main queue
var observation = Player.observationForAll()
observation.scheduling = .async(onQueue: .main, startImmediately: true)
let observer = try observation.start(
    in: dbQueue,
    onError: { error in ... },
    onChange: { (players: [Player]) in
        // On main queue
        print("fresh players: \(players)")s
    })
// <- here "fresh players" is not printed yet.
```

In GRDB 3, this scheduling used to be named `.queue(_: startImmediately:)`.

The second breaking change is `ValueObservation.extent`, which was removed in GRDB 4. Now all observations last until the observer returned by the `start` method is deallocated.


### Associations

GRDB 4 brought a few new [associations] features:

- **Indirect associations** [HasOneThrough] and [HasManyThrough] let you define associations from a record to another through a third one. For example, they let you easily express many-to-many relations such as "a country has many citizens through its passports":

    ```swift
    struct Country: TableRecord, EncodableRecord {
        static let passports = hasMany(Passport.self)
        // New!
        static let citizens = hasMany(Citizen.self, through: passports, using: Passport.citizen)
        var citizens: QueryInterfaceRequest<Citizen> {
            return request(for: Country.citizens)
        }
    }

    struct Passport: TableRecord {
        static let citizen = belongsTo(Citizen.self)
    }
 
    struct Citizen: TableRecord {
    }
    
    let country: Country = ...
    let citizens: [Citizen] = try dbQueue.read { db in
        try country.citizens.fetchAll(db)
    }
    ```
    
    ![HasManyThroughSchema](https://cdn.rawgit.com/groue/GRDB.swift/master/Documentation/Images/Associations2/HasManyThroughSchema.svg)

- **Eager loading of HasMany associations**: The new `including(all:)` method lets you load arrays or sets of associated records in a single request:

    ```swift
    // All authors with their respective books
    let request = Author.including(all: Author.books)
    
    // This request can feed the following record:
    struct AuthorInfo: FetchableRecord, Decodable {
        var author: Author
        var books: [Book] // all associated books
    }
    let authorInfos: [AuthorInfo] = try AuthorInfo.fetchAll(db, request)
    ```
    
    See [Joining And Prefetching Associated Records] for more information.

- **Automatic pluralization and singularization** of association identifiers.
    
    GRDB will automatically **pluralize** or **singularize** names in order to help you easily associate records.

    For example, the Book and Author records will automatically feed properties named `books`, `author`, or `bookCount` in your decoded records, without any explicit configuration, as long as the names of the backing database tables are "book" and "author".

    The GRDB pluralization mechanisms are very powerful, being capable of pluralizing and singularizing both regular and irregular words (it's directly inspired from the battle-tested [Ruby on Rails inflections](https://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-pluralize)).
    
    However, this change may have introduced some incompatibilities with GRDB 3 associations. Check [The Structure of a Joined Request] for more information.


### SQLCipher

The integration of GRDB with SQLCipher has changed.

1. With GRDB 3, it was possible to perform a manual installation, or to use CocoaPods and the GRDBCipher pod.
    
    With GRDB 4, CocoaPods is the only supported installation method. And the GRDBCipher pod is discontinued, replaced with GRDB.swift/SQLCipher:
    
    ```diff
    -pod 'GRDBCipher'
    +pod 'GRDB.swift/SQLCipher'
    ```
    
    In your Swift code, you no longer import the GRDBCipher module, but GRDB:
    
    ```diff
    -import GRDBCipher
    +import GRDB
    ```

2. The default SQLCipher version which comes with GRDB 4 is now SQLCipher 4, which is incompatible with SQLCipher 3. SQLCipher 3 is still supported, though. See [Encryption] for more details.

3. The `cipherPageSize` and `kdfIterations` configuration properties are discontinued. With GRDB 4, run sql pragmas in the `prepareDatabase` property of the configuration:
    
    ```swift
    var configuration = Configuration()
    configuration.passphrase = "secret"
    configuration.prepareDatabase = { db in
        try db.execute(sql: "PRAGMA cipher_page_size = 4096")
        try db.execute(sql: "PRAGMA kdf_iter = 128000")
    }
    let dbQueue = try DatabaseQueue(path: "...", configuration: configuration)
    ```


### PersistenceError.recordNotFound

PersistenceError.recordNotFound is thrown whenever a record update method does not find any database row to update. It was refactored in GRDB 4:

```swift
public enum PersistenceError: Error {
    case recordNotFound(databaseTableName: String, key: [String: DatabaseValue])
}

do {
    try player.updateChanges { 
        $0.score += 1000
    }
} catch let error as PersistenceError.recordNotFound {
    // Update failed because player does not exist in the database
    print(error)
    // prints "Key not found in table player: [id:42]"
}
```

[SQL Interpolation]: SQLInterpolation.md
[ValueObservation]: ../README.md#valueobservation
[Encryption]: ../README.md#encryption
[HasOneThrough]: AssociationsBasics.md#hasonethrough
[HasManyThrough]: AssociationsBasics.md#hasmanythrough
[PersistableRecord]: ../README.md#persistablerecord-protocol
[associations]: AssociationsBasics.md
[EncodableRecord]: ../README.md#persistablerecord-protocol
[The Structure of a Joined Request]: AssociationsBasics.md#the-structure-of-a-joined-request
[Joining And Prefetching Associated Records]: AssociationsBasics.md#joining-and-prefetching-associated-records

