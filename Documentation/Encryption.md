Encryption
==========

**GRDB can encrypt your database with [SQLCipher](http://sqlcipher.net) v3.4+.**

Use [CocoaPods](http://cocoapods.org/), and specify in your `Podfile`:

```ruby
# GRDB with SQLCipher 4
pod 'GRDB.swift/SQLCipher'
pod 'SQLCipher', '~> 4.0'

# GRDB with SQLCipher 3
pod 'GRDB.swift/SQLCipher'
pod 'SQLCipher', '~> 3.4'
```

Make sure you remove any existing `pod 'GRDB.swift'` from your Podfile. `GRDB.swift/SQLCipher` must be the only active GRDB pod in your whole project, or you will face linker or runtime errors, due to the conflicts between SQLCipher and the system SQLite.

- [Creating or Opening an Encrypted Database](#creating-or-opening-an-encrypted-database)
- [Changing the Passphrase of an Encrypted Database](#changing-the-passphrase-of-an-encrypted-database)
- [Exporting a Database to an Encrypted Database](#exporting-a-database-to-an-encrypted-database)
- [Security Considerations](#security-considerations)


## Creating or Opening an Encrypted Database

**You create and open an encrypted database** by providing a passphrase to your [database connection](DatabaseConnections.md):

```swift
var config = Configuration()
config.prepareDatabase { db in
    try db.usePassphrase("secret")
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

It is also in `prepareDatabase` that you perform other [SQLCipher configuration steps](https://www.zetetic.net/sqlcipher/sqlcipher-api/) that must happen early in the lifetime of a SQLCipher connection. For example:

```swift
var config = Configuration()
config.prepareDatabase { db in
    try db.usePassphrase("secret")
    try db.execute(sql: "PRAGMA cipher_page_size = ...")
    try db.execute(sql: "PRAGMA kdf_iter = ...")
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

When you want to open an existing SQLCipher 3 database with SQLCipher 4, you may want to run the `cipher_compatibility` pragma:

```swift
// Open an SQLCipher 3 database with SQLCipher 4
var config = Configuration()
config.prepareDatabase { db in
    try db.usePassphrase("secret")
    try db.execute(sql: "PRAGMA cipher_compatibility = 3")
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

See [SQLCipher 4.0.0 Release](https://www.zetetic.net/blog/2018/11/30/sqlcipher-400-release/) and [Upgrading to SQLCipher 4](https://discuss.zetetic.net/t/upgrading-to-sqlcipher-4/3283) for more information.


## Changing the Passphrase of an Encrypted Database

**You can change the passphrase** of an already encrypted database.

When you use a [database queue](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasequeue), open the database with the old passphrase, and then apply the new passphrase:

```swift
try dbQueue.write { db in
    try db.changePassphrase("newSecret")
}
```

When you use a [database pool](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasepool), make sure that no concurrent read can happen by changing the passphrase within the `barrierWriteWithoutTransaction` block. You must also ensure all future reads open a new database connection by calling the `invalidateReadOnlyConnections` method:

```swift
try dbPool.barrierWriteWithoutTransaction { db in
    try db.changePassphrase("newSecret")
    dbPool.invalidateReadOnlyConnections()
}
```

> **Note**: When an application wants to keep on using a database queue or pool after the passphrase has changed, it is responsible for providing the correct passphrase to the `usePassphrase` method called in the database preparation function. Consider:
>
> ```swift
> // WRONG: this won't work across a passphrase change
> let passphrase = try getPassphrase()
> var config = Configuration()
> config.prepareDatabase { db in
>     try db.usePassphrase(passphrase)
> }
>
> // CORRECT: get the latest passphrase when it is needed
> var config = Configuration()
> config.prepareDatabase { db in
>     let passphrase = try getPassphrase()
>     try db.usePassphrase(passphrase)
> }
> ```


## Exporting a Database to an Encrypted Database

Providing a passphrase won't encrypt a clear-text database that already exists, though. SQLCipher can't do that, and you will get an error instead: `SQLite error 26: file is encrypted or is not a database`.

Instead, create a new encrypted database, at a distinct location, and export the content of the existing database. This can both encrypt a clear-text database, or change the passphrase of an encrypted database.

The technique to do that is [documented](https://discuss.zetetic.net/t/how-to-encrypt-a-plaintext-sqlite-database-to-use-sqlcipher-and-avoid-file-is-encrypted-or-is-not-a-database-errors/868/1) by SQLCipher.

With GRDB, it gives:

```swift
// The existing database
let existingDBQueue = try DatabaseQueue(path: "/path/to/existing.db")

// The new encrypted database, at some distinct location:
var config = Configuration()
config.prepareDatabase { db in
    try db.usePassphrase("secret")
}
let newDBQueue = try DatabaseQueue(path: "/path/to/new.db", configuration: config)

try existingDBQueue.inDatabase { db in
    try db.execute(
        sql: """
            ATTACH DATABASE ? AS encrypted KEY ?;
            SELECT sqlcipher_export('encrypted');
            DETACH DATABASE encrypted;
            """,
        arguments: [newDBQueue.path, "secret"])
}

// Now the export is completed, and the existing database can be deleted.
```


## Security Considerations

### Managing the lifetime of the passphrase string

It is recommended to avoid keeping the passphrase in memory longer than necessary. To do this, make sure you load the passphrase from the `prepareDatabase` method:

```swift
// NOT RECOMMENDED: this keeps the passphrase in memory longer than necessary
let passphrase = try getPassphrase()
var config = Configuration()
config.prepareDatabase { db in
    try db.usePassphrase(passphrase)
}

// RECOMMENDED: only load the passphrase when it is needed
var config = Configuration()
config.prepareDatabase { db in
    let passphrase = try getPassphrase()
    try db.usePassphrase(passphrase)
}
```

This technique helps manages the lifetime of the passphrase, although keep in mind that the content of a String may remain intact in memory long after the object has been released.

For even better control over the lifetime of the passphrase in memory, use a Data object which natively provides the `resetBytes` function.

```swift
// RECOMMENDED: only load the passphrase when it is needed and reset its content immediately after use
var config = Configuration()
config.prepareDatabase { db in
    var passphraseData = try getPassphraseData() // Data
    defer {
        passphraseData.resetBytes(in: 0..<passphraseData.count)
    }
    try db.usePassphrase(passphraseData)
}
```

Some demanding users will want to go further, and manage the lifetime of the raw passphrase bytes. See below.


### Managing the lifetime of the passphrase bytes

GRDB offers convenience methods for providing the database passphrases as Swift strings: `usePassphrase(_:)` and `changePassphrase(_:)`. Those methods don't keep the passphrase String in memory longer than necessary. But they are as secure as the standard String type: the lifetime of actual passphrase bytes in memory is not under control.

When you want to precisely manage the passphrase bytes, talk directly to SQLCipher, using its raw C functions.

For example:

```swift
var config = Configuration()
config.prepareDatabase { db in
    ... // Carefully load passphrase bytes
    let code = sqlite3_key(db.sqliteConnection, /* passphrase bytes */)
    ... // Carefully dispose passphrase bytes
    guard code == SQLITE_OK else {
        throw DatabaseError(
            resultCode: ResultCode(rawValue: code),
            message: db.lastErrorMessage)
    }
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

### Passphrase availability vs. Database availability

When the passphrase is securely stored in the system keychain, your application can protect it using the [`kSecAttrAccessible`](https://developer.apple.com/documentation/security/ksecattraccessible) attribute.

Such protection prevents GRDB from creating SQLite connections when the passphrase is not available:

```swift
var config = Configuration()
config.prepareDatabase { db in
    let passphrase = try loadPassphraseFromSystemKeychain()
    try db.usePassphrase(passphrase)
}

// Success if and only if the passphrase is available
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
```

For the same reason, [database pools](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasepool), which open SQLite connections on demand, may fail at any time as soon as the passphrase becomes unavailable.

Applications are thus responsible for protecting database accesses when the passphrase is unavailable. To this end, they can use [Data Protection](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/encrypting_your_app_s_files). They can also destroy their instances of database queue or pool when the passphrase becomes unavailable.
