# ``GRDB``

A toolkit for SQLite databases, with a focus on application development

##

![GRDB Logo](GRDBLogo.png)

## Overview

Use this library to save your application’s permanent data into SQLite databases. It comes with built-in tools that address common needs:

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

## Usage

Start using the database in four steps:

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
struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
    var score: Int
}

// 4. Write and read in the database
try dbQueue.write { db in
    try Player(id: "1", name: "Arthur", score: 100).insert(db)
    try Player(id: "2", name: "Barbara", score: 1000).insert(db)
}

let players: [Player] = try dbQueue.read { db in
    try Player.fetchAll(db)
}
```

## Links and Companion Libraries

- [GitHub Repository](http://github.com/groue/GRDB.swift)
- [Installation Instructions, encryption with SQLCipher, custom SQLite builds](https://github.com/groue/GRDB.swift#installation)
- [GRDBQuery](https://github.com/groue/GRDBQuery): the SwiftUI companion for GRDB.
- [GRDBSnapshotTesting](https://github.com/groue/GRDBSnapshotTesting): Test your database.

## Topics

### Fundamentals

- <doc:DatabaseConnections>
- <doc:SQLSupport>
- <doc:Concurrency>
- <doc:Transactions>

### Migrations and The Database Schema

- <doc:DatabaseSchema>
- <doc:Migrations>

### Records and the Query Interface

- <doc:QueryInterface>
- <doc:RecordRecommendedPractices>
- <doc:RecordTimestamps>
- <doc:SingleRowTables>

### Application Tools

- <doc:DatabaseObservation>
- <doc:FullTextSearch>
- <doc:JSON>
- ``DatabasePublishers``
