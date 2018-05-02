Migrating From GRDB 2 to GRDB 3
===============================

GRDB 3 comes with new features, but also a few breaking changes, and a set of updated good practices. This guide aims at helping you upgrading your applications.

- [How To Upgrade]
- [Database Schema Recommendations]
- [If You Target iOS 8]
- [If You Use Database Queues]
- [If You Use Database Pools]


## How to Upgrade

Target the "GRDB3" branch:

### CocoaPods

Update your Podfile:

```ruby
pod 'GRDB.swift', git: 'https://github.com/groue/GRDB.swift', branch: 'GRDB3'
# pod 'RxGRDB', git: 'https://github.com/groue/RxGRDB', branch: 'GRDB3'
```

### Swift Package Manager

Update your Package.swift file:

```swift
let package = Package(
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", branch: "GRDB3")
    ]
)
```

### Manually

Update your local copy of GRDB:

```sh
git checkout GRDB3
git pull
```


## Database Schema Recommendations

GRDB 2 was totally schema-agnostic, and would gladly accept any database.

GRDB 3 still accepts any database, but brings two schema recommendations:

- :bulb: Integer primary keys should be auto-incremented, in order to avoid any row id to be reused.
    
    When ids can be reused, your app and [database observation tools] may think that a row was updated, when it was actually deleted, then replaced. Depending on your application needs, this may be OK. Or not.
    
    GRDB3 thus comes with a new good practice: use the `autoIncrementedPrimaryKey` method when you create a database table with an integer primary key:
    
    ```diff
     try db.create(table: "author") { t in
    -    t.column("id", .integer).primaryKey() // GRDB 2
    +    t.autoIncrementedPrimaryKey("id")     // GRDB 3 recommendation
         t.column("name", .text).notNull()
     }
    ```

- :bulb: Database table names should be singular, and camel-cased. Make them look like Swift identifiers: `place`, `country`, `postalAddress`.
    
    This will help you using the new [Associations] feature when you need it. Database table names that follow another naming convention are totally OK, but you will need to perform extra configuration.

Since you are reading this guide, your application has already defined its database schema. You can migrate it in order to apply the new recommendations, if needed. Below is a sample code that uses [DatabaseMigrator], the recommended tool for managing your database schema:

```swift
var migrator = DatabaseMigrator()

// GRDB 2 migration
migrator.registerMigration("initial") { db in
    try db.create(table: "authors") { t in
        t.column("id", .integer).primaryKey()
        t.column("name", .text).notNull()
    }
    try db.create(table: "books") { t in
        t.column("id", .integer).primaryKey()
        t.column("authorId", .integer).notNull().references("authors")
        t.column("title", .text).notNull()
    }
}

// GRDB 3 migration:
// - table names look like Swift identifiers (singular and camelCased)
// - integer primary keys are auto-incremented
//
// Use registerMigrationWithDeferredForeignKeyCheck in order to disable
// foreign key checks during the migration:
migrator.registerMigrationWithDeferredForeignKeyCheck("GRDB3") { db in
    try db.create(table: "author") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
    }
    try db.create(table: "book") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("authorId", .integer).notNull().references("author")
        t.column("title", .text).notNull()
    }
    try db.execute("""
        INSERT INTO author SELECT * FROM authors;
        INSERT INTO book SELECT * FROM books;
        """)
    try db.drop(table: "authors")
    try db.drop(table: "books")
}
```


## If You Target iOS 8

GRDB 3 is only supported on iOS 9+.

That is because the library requires Swift 4.1, which ships with Xcode 9.3, unable to run tests before iOS 9.

> :construction_worker: Beta note: GRDB 3 currently still *runs* on iOS8, although untested. I won't delete the code that targets older versions of SQLite and iOS until I grab some feedback.


## If You Use Database Queues

## If You Use Database Pools


[How To Upgrade]: #how-to-upgrade
[Database Schema Recommendations]: #database-schema-recommendations
[If You Target iOS 8]: #if-you-target-ios-8
[If You Use Database Queues]: #if-you-use-database-queues
[If You Use Database Pools]: #if-you-use-database-pools
[FetchedRecordsController]: ../README.md#fetchedrecordscontroller
[RxGRDB]: http://github.com/RxSwiftCommunity/RxGRDB
[Associations]: AssociationsBasics.md
[DatabaseMigrator]: ../README.md#migrations
[database observation tools]: ../README.md#database-changes-observation