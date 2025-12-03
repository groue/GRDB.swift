<picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/groue/GRDB.swift/master/GRDB~dark.png">
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/groue/GRDB.swift/master/GRDB.png">
    <img alt="GRDB: A toolkit for SQLite databases, with a focus on application development." src="https://raw.githubusercontent.com/groue/GRDB.swift/master/GRDB.png">
</picture>

<p align="center">
    <strong>A toolkit for SQLite databases, with a focus on application development</strong><br>
    Proudly serving the community since 2015
</p>

<p align="center">
    <a href="https://developer.apple.com/swift/"><img alt="Swift 6" src="https://img.shields.io/badge/swift-6-orange.svg?style=flat"></a>
    <a href="https://github.com/groue/GRDB.swift/blob/master/LICENSE"><img alt="License" src="https://img.shields.io/github/license/groue/GRDB.swift.svg?maxAge=2592000"></a>
    <a href="https://github.com/groue/GRDB.swift/actions/workflows/CI.yml"><img alt="CI Status" src="https://github.com/groue/GRDB.swift/actions/workflows/CI.yml/badge.svg?branch=master"></a>
</p>

---

<a href="https://menial.co.uk/base/"><img alt="Base: The best SQLite database editor for macOS" src="https://raw.githubusercontent.com/groue/GRDB.swift/master/Sponsors/base.png"></a>

<p align="center">
    <strong>Thank you to <a href="https://menial.co.uk/base/">Base</a> for sponsoring GRDB</strong><br />Base is a small, powerful, comfortable SQLite editor for everyone on macOS.
</p>

---

**Latest release**: October 2, 2025 • [version 7.8.0](https://github.com/groue/GRDB.swift/tree/v7.8.0) • [CHANGELOG](CHANGELOG.md) • [Migrating From GRDB 6 to GRDB 7](Documentation/GRDB7MigrationGuide.md)

**Requirements**: iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 7.0+ &bull; SQLite 3.20.0+ &bull; Swift 6+ / Xcode 16+

**Contact**:

- Release announcements and usage tips: follow [@groue@hachyderm.io](https://hachyderm.io/@groue) on Mastodon.
- Report bugs in a [Github issue](https://github.com/groue/GRDB.swift/issues/new). Make sure you check the [existing issues](https://github.com/groue/GRDB.swift/issues?q=is%3Aopen) first.
- A question? Looking for advice? Do you wonder how to contribute? Fancy a chat? Go to the [GitHub discussions](https://github.com/groue/GRDB.swift/discussions), or the [GRDB forums](https://forums.swift.org/c/related-projects/grdb).


## What is GRDB?

Use this library to save your application's permanent data into SQLite databases. It comes with built-in tools that address common needs:

- **SQL Generation**

    Enhance your application models with persistence and fetching methods, so that you don't have to deal with SQL and raw database rows when you don't want to.

- **Database Observation**

    Get notifications when database values are modified.

- **Robust Concurrency**

    Multi-threaded applications can efficiently use their databases, including WAL databases that support concurrent reads and writes.

- **Migrations**

    Evolve the schema of your database as you ship new versions of your application.

- **Leverage your SQLite skills**

    Not all developers need advanced SQLite features. But when you do, GRDB is as sharp as you want it to be. Come with your SQL and SQLite skills, or learn new ones as you go!

---

<p align="center">
    <a href="#usage">Usage</a> &bull;
    <a href="#documentation">Documentation</a> &bull;
    <a href="#installation">Installation</a>
</p>

---

## Usage

<details open>
  <summary>Start using the database in four steps</summary>

```swift
import GRDB

// 1. Open a database connection
let dbQueue = try DatabaseQueue(path: "/path/to/database.sqlite")

// 2. Define the database schema
try dbQueue.write { db in
    try db.create(table: "player") { t in
        t.primaryKey("id", .text)
        t.column("name", .text).notNull()
        t.column("score", .integer).notNull()
    }
}

// 3. Define a record type
struct Player: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
    var score: Int

    enum Columns {
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
}

// 4. Write and read in the database
try dbQueue.write { db in
    try Player(id: "1", name: "Arthur", score: 100).insert(db)
    try Player(id: "2", name: "Barbara", score: 1000).insert(db)
}

try dbQueue.read { db in
    let player = try Player.find(db, id: "1"))

    let bestPlayers = try Player
        .order(\.score.desc)
        .limit(10)
        .fetchAll(db)
}
```

</details>

<details>
    <summary>Access to raw SQL</summary>

```swift
try dbQueue.write { db in
    try db.execute(sql: """
        CREATE TABLE player (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          score INT NOT NULL)
        """)

    try db.execute(sql: """
        INSERT INTO player (id, name, score)
        VALUES (?, ?, ?)
        """, arguments: ["1", "Arthur", 100])

    // Avoid SQL injection with SQL interpolation
    let id = "2"
    let name = "O'Brien"
    let score = 1000
    try db.execute(literal: """
        INSERT INTO player (id, name, score)
        VALUES (\(id), \(name), \(score))
        """)
}
```

See [SQLite API](Documentation/SQLiteAPI.md)

</details>

<details>
    <summary>Access to raw database rows and values</summary>

```swift
try dbQueue.read { db in
    // Fetch database rows
    let rows = try Row.fetchCursor(db, sql: "SELECT * FROM player")
    while let row = try rows.next() {
        let id: String = row["id"]
        let name: String = row["name"]
        let score: Int = row["score"]
    }

    // Fetch values
    let playerCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player")! // Int
    let playerNames = try String.fetchAll(db, sql: "SELECT name FROM player") // [String]
}

let playerCount = try dbQueue.read { db in
    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM player")!
}
```

See [SQLite API](Documentation/SQLiteAPI.md)

</details>

<details>
    <summary>Database model types aka "records"</summary>

```swift
struct Player: Codable, Identifiable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
    var score: Int

    enum Columns {
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
}

try dbQueue.write { db in
    // Create database table
    try db.create(table: "player") { t in
        t.primaryKey("id", .text)
        t.column("name", .text).notNull()
        t.column("score", .integer).notNull()
    }

    // Insert a record
    var player = Player(id: "1", name: "Arthur", score: 100)
    try player.insert(db)

    // Update a record
    player.score += 10
    try score.update(db)

    try player.updateChanges { $0.score += 10 }

    // Delete a record
    try player.delete(db)
}
```

See [Records](Documentation/Records.md)

</details>

<details>
    <summary>Query the database with the Swift query interface</summary>

```swift
try dbQueue.read { db in
    // Player
    let player = try Player.find(db, id: "1")

    // Player?
    let arthur = try Player.filter { $0.name == "Arthur" }.fetchOne(db)

    // [Player]
    let bestPlayers = try Player.order(\.score.desc).limit(10).fetchAll(db)

    // Int
    let playerCount = try Player.fetchCount(db)

    // SQL is always welcome
    let players = try Player.fetchAll(db, sql: "SELECT * FROM player")
}
```

See [Query Interface](Documentation/QueryInterface.md)

</details>

<details>
    <summary>Database changes notifications</summary>

```swift
// Define the observed value
let observation = ValueObservation.tracking { db in
    try Player.fetchAll(db)
}

// Start observation
let cancellable = observation.start(
    in: dbQueue,
    onError: { error in ... },
    onChange: { (players: [Player]) in print("Fresh players: \(players)") })
```

Ready-made support for Combine and RxSwift:

```swift
// Swift concurrency
for try await players in observation.values(in: dbQueue) {
    print("Fresh players: \(players)")
}

// Combine
let cancellable = observation.publisher(in: dbQueue).sink(
    receiveCompletion: { completion in ... },
    receiveValue: { (players: [Player]) in print("Fresh players: \(players)") })

// RxSwift
let disposable = observation.rx.observe(in: dbQueue).subscribe(
    onNext: { (players: [Player]) in print("Fresh players: \(players)") },
    onError: { error in ... })
```

See [Database Observation], [Combine Support], [RxGRDB].

</details>

Documentation
=============

**GRDB runs on top of SQLite**: you should get familiar with the [SQLite FAQ](http://www.sqlite.org/faq.html). For general and detailed information, jump to the [SQLite Documentation](http://www.sqlite.org/docs.html).


#### Demo Applications & Frequently Asked Questions

- [Demo Applications](Documentation/DemoApps)
- [FAQ](Documentation/FAQ.md)

#### Reference

- :book: [GRDB Reference](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/)

#### Getting Started

- [Installation](#installation)
- [Database Connections](Documentation/DatabaseConnections.md): Connect to SQLite databases

#### SQLite and SQL

- :book: [SQLite API](Documentation/SQLiteAPI.md): The low-level SQLite API &bull; executing updates &bull; fetch queries
- :book: [SQL Interpolation](Documentation/SQLInterpolation.md): Embed values in your SQL queries without risking SQL injection
- :book: [Custom SQL Functions](Documentation/CustomSQLFunctions.md): Extend SQLite with custom functions and aggregates

#### Records and the Query Interface

- :book: [Records](Documentation/Records.md): Fetching and persistence methods for your custom structs and class hierarchies
- :book: [Query Interface](Documentation/QueryInterface.md): A swift way to generate SQL &bull; requests &bull; expressions
- :book: [Associations and Joins](Documentation/AssociationsBasics.md): Relationships between record types
- :book: [Common Table Expressions](Documentation/CommonTableExpressions.md): Compose your queries

#### Application Tools

- [Migrations]: Transform your database as your application evolves.
- [Full-Text Search]: Perform efficient and customizable full-text searches.
- [Database Observation]: Observe database changes and transactions.
- :book: [Encryption](Documentation/Encryption.md): Encrypt your database with SQLCipher.
- :book: [Backup and Utilities](Documentation/BackupAndUtilities.md): Backup, interrupt, error handling, Unicode, memory management.
- [Sharing a Database]: How to share an SQLite database between multiple processes.

#### Good to Know

- [Concurrency]: How to access databases in a multi-threaded application.
- [Combine Support](Documentation/Combine.md): Access and observe the database with Combine publishers.
- :bulb: [Migrating From GRDB 6 to GRDB 7](Documentation/GRDB7MigrationGuide.md)
- :bulb: [Why Adopt GRDB?](Documentation/WhyAdoptGRDB.md)
- :bulb: [Recommended Practices for Designing Record Types](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/recordrecommendedpractices)

#### Companion Libraries

- [GRDBQuery](https://github.com/groue/GRDBQuery): Access and observe the database from your SwiftUI views.
- [GRDBSnapshotTesting](https://github.com/groue/GRDBSnapshotTesting): Test your database.


Installation
============

**The installation procedures below have GRDB use the version of SQLite that ships with the target operating system.**

See [Encryption](Documentation/Encryption.md) for the installation procedure of GRDB with SQLCipher.

See [Custom SQLite builds](Documentation/CustomSQLiteBuilds.md) for the installation procedure of GRDB with a customized build of SQLite.


## Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) automates the distribution of Swift code. To use GRDB with SPM, add a dependency to `https://github.com/groue/GRDB.swift.git`

GRDB offers two libraries, `GRDB` and `GRDB-dynamic`. Pick only one. When in doubt, prefer `GRDB`. The `GRDB-dynamic` library can reveal useful if you are going to link it with multiple targets within your app and only wish to link to a shared, dynamic framework once. See [How to link a Swift Package as dynamic](https://forums.swift.org/t/how-to-link-a-swift-package-as-dynamic/32062) for more information.

> **Note**: Linux support is provided by contributors. It is not automatically tested, and not officially maintained. If you notice a build or runtime failure on Linux, please open a pull request with the necessary fix, thank you!


## CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Xcode projects. To use GRDB with CocoaPods (version 1.2 or higher), specify in your `Podfile`:

```ruby
pod 'GRDB.swift'
```

GRDB can be installed as a framework, or a static library.

**Important Note for CocoaPods installation**

Due to an [issue](https://github.com/CocoaPods/CocoaPods/issues/11839) in CocoaPods, it is currently not possible to deploy new versions of GRDB to CocoaPods. The last version available on CocoaPods is 6.24.1. To install later versions of GRDB using CocoaPods, use one of the following workarounds:

- Depend on the `GRDB7` branch. This is more or less equivalent to what `pod 'GRDB.swift', '~> 7.0'` would normally do, if CocoaPods would accept new GRDB versions to be published:

    ```ruby
    # Can't use semantic versioning due to https://github.com/CocoaPods/CocoaPods/issues/11839
    pod 'GRDB.swift', git: 'https://github.com/groue/GRDB.swift.git', branch: 'GRDB7'
    ```

- Depend on a specific version explicitly (Replace the tag with the version you want to use):

    ```ruby
    # Can't use semantic versioning due to https://github.com/CocoaPods/CocoaPods/issues/11839
    # Replace the tag with the tag that you want to use.
    pod 'GRDB.swift', git: 'https://github.com/groue/GRDB.swift.git', tag: 'v6.29.0'
    ```

## Carthage

[Carthage](https://github.com/Carthage/Carthage) is **unsupported**. For some context about this decision, see [#433](https://github.com/groue/GRDB.swift/issues/433).


## Manually

1. [Download](https://github.com/groue/GRDB.swift/releases) a copy of GRDB, or clone its repository and make sure you checkout the latest tagged version.

2. Embed the `GRDB.xcodeproj` project in your own project.

3. Add the `GRDB` target in the **Target Dependencies** section of the **Build Phases** tab of your application target (extension target for WatchOS).

4. Add the `GRDB.framework` to the **Embedded Binaries** section of the **General**  tab of your application target (extension target for WatchOS).


Sample Code
===========

- The [Documentation](#documentation) is full of GRDB snippets.
- [Demo Applications](Documentation/DemoApps)
- Open `GRDB.xcworkspace`: it contains GRDB-enabled playgrounds to play with.
- [groue/SortedDifference](https://github.com/groue/SortedDifference): How to synchronize a database table with a JSON payload


---

**Thanks**

- [Pierlis](http://pierlis.com), where we write great software.
- [@alextrob](https://github.com/alextrob), [@alexwlchan](https://github.com/alexwlchan), [@bellebethcooper](https://github.com/bellebethcooper), [@bfad](https://github.com/bfad), [@cfilipov](https://github.com/cfilipov), [@charlesmchen-signal](https://github.com/charlesmchen-signal), [@Chiliec](https://github.com/Chiliec), [@chrisballinger](https://github.com/chrisballinger), [@darrenclark](https://github.com/darrenclark), [@davidkraus](https://github.com/davidkraus), [@eburns-vmware](https://github.com/eburns-vmware), [@felixscheinost](https://github.com/felixscheinost), [@fpillet](https://github.com/fpillet), [@gcox](https://github.com/gcox), [@GetToSet](https://github.com/GetToSet), [@gjeck](https://github.com/gjeck), [@guidedways](https://github.com/guidedways), [@gusrota](https://github.com/gusrota), [@haikusw](https://github.com/haikusw), [@hartbit](https://github.com/hartbit), [@holsety](https://github.com/holsety), [@jroselightricks](https://github.com/jroselightricks), [@kdubb](https://github.com/kdubb), [@kluufger](https://github.com/kluufger), [@KyleLeneau](https://github.com/KyleLeneau), [@layoutSubviews](https://github.com/layoutSubviews), [@mallman](https://github.com/mallman), [@MartinP7r](https://github.com/MartinP7r), [@Marus](https://github.com/Marus), [@mattgallagher](https://github.com/mattgallagher), [@MaxDesiatov](https://github.com/MaxDesiatov), [@michaelkirk-signal](https://github.com/michaelkirk-signal), [@mtancock](https://github.com/mtancock), [@pakko972](https://github.com/pakko972), [@peter-ss](https://github.com/peter-ss), [@pierlo](https://github.com/pierlo), [@pocketpixels](https://github.com/pocketpixels), [@pp5x](https://github.com/pp5x), [@professordeng](https://github.com/professordeng), [@robcas3](https://github.com/robcas3), [@runhum](https://github.com/runhum), [@sberrevoets](https://github.com/sberrevoets), [@schveiguy](https://github.com/schveiguy), [@SD10](https://github.com/SD10), [@sobri909](https://github.com/sobri909), [@sroddy](https://github.com/sroddy), [@steipete](https://github.com/steipete), [@swiftlyfalling](https://github.com/swiftlyfalling), [@Timac](https://github.com/Timac), [@tternes](https://github.com/tternes), [@valexa](https://github.com/valexa), [@wuyuehyang](https://github.com/wuyuehyang), [@ZevEisenberg](https://github.com/ZevEisenberg), and [@zmeyc](https://github.com/zmeyc) for their contributions, help, and feedback on GRDB.
- [@aymerick](https://github.com/aymerick) and [@kali](https://github.com/kali) because SQL.
- [ccgus/fmdb](https://github.com/ccgus/fmdb) for its excellency.


[Associations]: Documentation/AssociationsBasics.md
[Combine Support]: Documentation/Combine.md
[Common Table Expressions]: Documentation/CommonTableExpressions.md
[Concurrency]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/concurrency
[Database Observation]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseobservation
[Full-Text Search]: Documentation/FullTextSearch.md
[Migrations]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/migrations
[RxGRDB]: https://github.com/RxSwiftCommunity/RxGRDB
[Sharing a Database]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasesharing
[ValueObservation]: https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/valueobservation
