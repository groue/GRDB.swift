Records
=======

**On top of the [SQLite API](SQLiteAPI.md), GRDB provides protocols** that help manipulating database rows as regular objects named "records":

```swift
try dbQueue.write { db in
    if var place = try Player.fetchOne(db, id: 1) {
        player.score += 10
        try player.update(db)
    }
}
```

Of course, you need to open a [database connection](DatabaseConnections.md), and [create database tables](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseschema) first.

To define a record type, define a type and extend it with database protocols:

- `FetchableRecord` makes it possible to fetch instances from the database.
- `PersistableRecord` makes it possible to save instances into the database.
- `Codable` (not mandatory) provides ready-made serialization to and from database rows.
- `Identifiable` (not mandatory) provides extra convenience database methods.

To make it easier to customize database requests, also nest a `Columns` enum:

```swift
struct Player: Codable, Identifiable {
    var id: Int64
    var name: String
    var score: Int
    var team: String?
}

// Add database support
extension Player: FetchableRecord, PersistableRecord {
    enum Columns {
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
        static let team = Column(CodingKeys.team)
    }
}
```

See more [examples of record definitions](#examples-of-record-definitions) below.

> Note: if you are familiar with Core Data's NSManagedObject or Realm's Object, you may experience a cultural shock: GRDB records are not uniqued, do not auto-update, and do not lazy-load. This is both a purpose, and a consequence of protocol-oriented programming.
>
> Tip: The [Recommended Practices for Designing Record Types](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/recordrecommendedpractices) guide provides general guidance..
>
> Tip: See the [Demo Applications](DemoApps) for sample apps that uses records.

**Overview**

- [Inserting Records](#inserting-records)
- [Fetching Records](#fetching-records)
- [Updating Records](#updating-records)
- [Deleting Records](#deleting-records)
- [Counting Records](#counting-records)

**Protocols and the Record Class**

- [Record Protocols Overview](#record-protocols-overview)
- [FetchableRecord Protocol](#fetchablerecord-protocol)
- [TableRecord Protocol](#tablerecord-protocol)
- [PersistableRecord Protocol](#persistablerecord-protocol)
    - [Persistence Methods](#persistence-methods)
    - [Persistence Methods and the `RETURNING` clause](#persistence-methods-and-the-returning-clause)
    - [Persistence Callbacks](#persistence-callbacks)
- [Identifiable Records](#identifiable-records)
- [Codable Records](#codable-records)
- [Record Comparison](#record-comparison)
- [Record Customization Options](#record-customization-options)
- [Record Timestamps and Transaction Date](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/recordtimestamps)


### Inserting Records

To insert a record in the database, call the `insert` method:

```swift
let player = Player(id: 1, name: "Arthur", score: 1000)
try player.insert(db)
```

:point_right: `insert` is available for types that adopt the [PersistableRecord](#persistablerecord-protocol) protocol.


### Fetching Records

To fetch records from the database, call a [fetching method](SQLiteAPI.md#fetching-methods):

```swift
let arthur = try Player.fetchOne(db,            // Player?
    sql: "SELECT * FROM players WHERE name = ?",
    arguments: ["Arthur"])

let bestPlayers = try Player                    // [Player]
    .order(\.score.desc)
    .limit(10)
    .fetchAll(db)

let spain = try Country.fetchOne(db, id: "ES")  // Country?
let italy = try Country.find(db, id: "IT")      // Country
```

:point_right: Fetching from raw SQL is available for types that adopt the [FetchableRecord](#fetchablerecord-protocol) protocol.

:point_right: Fetching without SQL, using the [query interface](QueryInterface.md), is available for types that adopt both [FetchableRecord](#fetchablerecord-protocol) and [TableRecord](#tablerecord-protocol) protocol.


### Updating Records

To update a record in the database, call the `update` method:

```swift
var player: Player = ...
player.score = 1000
try player.update(db)
```

It is possible to [avoid useless updates](#record-comparison):

```swift
// does not hit the database if score has not changed
try player.updateChanges(db) {
    $0.score = 1000
}
```

See the [query interface](QueryInterface.md) for batch updates:

```swift
try Player
    .filter { $0.team == "red" }
    .updateAll(db) { $0.score += 1 }
```

:point_right: update methods are available for types that adopt the [PersistableRecord](#persistablerecord-protocol) protocol. Batch updates are available on the [TableRecord](#tablerecord-protocol) protocol.


### Deleting Records

To delete a record in the database, call the `delete` method:

```swift
let player: Player = ...
try player.delete(db)
```

You can also delete by primary key, unique key, or perform batch deletes (see [Delete Requests](QueryInterface.md#delete-requests)):

```swift
try Player.deleteOne(db, id: 1)
try Player.deleteOne(db, key: ["email": "arthur@example.com"])
try Country.deleteAll(db, ids: ["FR", "US"])
try Player
    .filter { $0.email == nil }
    .deleteAll(db)
```

:point_right: delete methods are available for types that adopt the [PersistableRecord](#persistablerecord-protocol) protocol. Batch deletes are available on the [TableRecord](#tablerecord-protocol) protocol.


### Counting Records

To count records, call the `fetchCount` method:

```swift
let playerCount: Int = try Player.fetchCount(db)

let playerWithEmailCount: Int = try Player
    .filter { $0.email == nil }
    .fetchCount(db)
```

:point_right: `fetchCount` is available for types that adopt the [TableRecord](#tablerecord-protocol) protocol.


## Record Protocols Overview

**GRDB ships with three record protocols**. Your own types will adopt one or several of them, according to the abilities you want to extend your types with.

- [FetchableRecord](#fetchablerecord-protocol) is able to **decode database rows**.

    ```swift
    struct Place: FetchableRecord { ... }

    let places = try dbQueue.read { db in
        try Place.fetchAll(db, sql: "SELECT * FROM place")
    }
    ```

    > :bulb: **Tip**: `FetchableRecord` can derive its implementation from the standard `Decodable` protocol. See [Codable Records](#codable-records) for more information.

    `FetchableRecord` can decode database rows, but it is not able to build SQL requests for you. For that, you also need `TableRecord`:

- [TableRecord](#tablerecord-protocol) is able to **generate SQL queries**:

    ```swift
    struct Place: TableRecord { ... }

    let placeCount = try dbQueue.read { db in
        // Generates and runs `SELECT COUNT(*) FROM place`
        try Place.fetchCount(db)
    }
    ```

    When a type adopts both `TableRecord` and `FetchableRecord`, it can load from those requests:

    ```swift
    struct Place: TableRecord, FetchableRecord { ... }

    try dbQueue.read { db in
        let places = try Place.order(\.title).fetchAll(db)
        let paris = try Place.fetchOne(id: 1)
    }
    ```

- [PersistableRecord](#persistablerecord-protocol) is able to **write**: it can create, update, and delete rows in the database:

    ```swift
    struct Place : PersistableRecord { ... }

    try dbQueue.write { db in
        try Place.delete(db, id: 1)
        try Place(...).insert(db)
    }
    ```

    A persistable record can also [compare](#record-comparison) itself against other records, and avoid useless database updates.

    > :bulb: **Tip**: `PersistableRecord` can derive its implementation from the standard `Encodable` protocol. See [Codable Records](#codable-records) for more information.


## FetchableRecord Protocol

**The FetchableRecord protocol grants fetching methods to any type** that can be built from a database row:

```swift
protocol FetchableRecord {
    /// Row initializer
    init(row: Row) throws
}
```

For example:

```swift
struct Place {
    var id: Int64?
    var title: String
    var coordinate: CLLocationCoordinate2D
}

extension Place: FetchableRecord {
    enum Columns {
        static let id = Column("id")
        static let title = Column("title")
        static let latitude = Column("latitude")
        static let longitude = Column("longitude")
    }

    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        coordinate = CLLocationCoordinate2D(
            latitude: row[Columns.latitude],
            longitude: row[Columns.longitude])
    }
}
```

See [column values](SQLiteAPI.md#column-values) for more information about the `row[]` subscript.

When your record type adopts the standard Decodable protocol, you don't have to provide the implementation for `init(row:)`. See [Codable Records](#codable-records) for more information:

```swift
// That's all
struct Player: Decodable, FetchableRecord {
    var id: Int64
    var name: String
    var score: Int

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
}
```

FetchableRecord allows adopting types to be fetched from SQL queries:

```swift
try Place.fetchCursor(db, sql: "SELECT ...", arguments:...) // A Cursor of Place
try Place.fetchAll(db, sql: "SELECT ...", arguments:...)    // [Place]
try Place.fetchSet(db, sql: "SELECT ...", arguments:...)    // Set<Place>
try Place.fetchOne(db, sql: "SELECT ...", arguments:...)    // Place?
```

See [fetching methods](SQLiteAPI.md#fetching-methods) for information about the `fetchCursor`, `fetchAll`, `fetchSet` and `fetchOne` methods. See [`StatementArguments`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/statementarguments) for more information about the query arguments.

> **Note**: for performance reasons, the same row argument to `init(row:)` is reused during the iteration of a fetch query. If you want to keep the row for later use, make sure to store a copy: `self.row = row.copy()`.

> **Note**: The `FetchableRecord.init(row:)` initializer fits the needs of most applications. But some application are more demanding than others. When FetchableRecord does not exactly provide the support you need, have a look at the [Beyond FetchableRecord](#beyond-fetchablerecord) chapter.


## TableRecord Protocol

**The TableRecord protocol** generates SQL for you:

```swift
protocol TableRecord {
    static var databaseTableName: String { get }
    static var databaseSelection: [any SQLSelectable] { get }
}
```

The `databaseSelection` type property is optional, and documented in the [Columns Selected by a Request](QueryInterface.md#columns-selected-by-a-request) chapter.

The `databaseTableName` type property is the name of a database table. By default, it is derived from the type name:

```swift
struct Place: TableRecord { }
print(Place.databaseTableName) // prints "place"
```

For example:

- Place: `place`
- Country: `country`
- PostalAddress: `postalAddress`
- HTTPRequest: `httpRequest`
- TOEFL: `toefl`

You can still provide a custom table name:

```swift
struct Place: TableRecord {
    static let databaseTableName = "location"
}

print(Place.databaseTableName) // prints "location"
```

When a type adopts both TableRecord and [FetchableRecord](#fetchablerecord-protocol), it can be fetched using the [query interface](QueryInterface.md):

```swift
// SELECT * FROM place WHERE name = 'Paris'
let paris = try Place.filter { $0.name == "Paris" }.fetchOne(db)
```

TableRecord can also fetch deal with primary and unique keys: see [Fetching by Key](QueryInterface.md#fetching-by-key) and [Testing for Record Existence](QueryInterface.md#testing-for-record-existence).


## PersistableRecord Protocol

**GRDB record types can create, update, and delete rows in the database.**

Those abilities are granted by three protocols:

```swift
// Defines how a record encodes itself into the database
protocol EncodableRecord {
    /// Defines the values persisted in the database
    func encode(to container: inout PersistenceContainer) throws
}

// Adds persistence methods
protocol MutablePersistableRecord: TableRecord, EncodableRecord {
    /// Optional method that lets your adopting type store its rowID upon
    /// successful insertion. Don't call it directly: it is called for you.
    mutating func didInsert(_ inserted: InsertionSuccess)
}

// Adds immutability
protocol PersistableRecord: MutablePersistableRecord {
    /// Non-mutating version of the optional didInsert(_:)
    func didInsert(_ inserted: InsertionSuccess)
}
```

Yes, three protocols instead of one. Here is how you pick one or the other:

- **If your type is a class**, choose `PersistableRecord`. On top of that, implement `didInsert(_:)` if the database table has an auto-incremented primary key.

- **If your type is a struct, and the database table has an auto-incremented primary key**, choose `MutablePersistableRecord`, and implement `didInsert(_:)`.

- **Otherwise**, choose `PersistableRecord`, and ignore `didInsert(_:)`.

The `encode(to:)` method defines which [values](SQLiteAPI.md#values) (Bool, Int, String, Date, Swift enums, etc.) are assigned to database columns.

The optional `didInsert` method lets the adopting type store its rowID after successful insertion, and is only useful for tables that have an auto-incremented primary key. It is called from a protected dispatch queue, and serialized with all database updates.

For example:

```swift
extension Place: MutablePersistableRecord {
    enum Columns {
        static let id = Column("id")
        static let title = Column("title")
        static let latitude = Column("latitude")
        static let longitude = Column("longitude")
    }

    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.latitude] = coordinate.latitude
        container[Columns.longitude] = coordinate.longitude
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

var paris = Place(
    id: nil,
    title: "Paris",
    coordinate: CLLocationCoordinate2D(latitude: 48.8534100, longitude: 2.3488000))

try paris.insert(db)
paris.id   // some value
```

When your record type adopts the standard Encodable protocol, you don't have to provide the implementation for `encode(to:)`. See [Codable Records](#codable-records) for more information:

```swift
// That's all
struct Player: Encodable, MutablePersistableRecord {
    var id: Int64?
    var name: String
    var score: Int

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```


### Persistence Methods

Types that adopt the [PersistableRecord](#persistablerecord-protocol) protocol are given methods that insert, update, and delete:

```swift
// INSERT
try place.insert(db)
let insertedPlace = try place.inserted(db) // non-mutating

// UPDATE
try place.update(db)
try place.update(db, columns: ["title"])

// Maybe UPDATE
try place.updateChanges(db, from: otherPlace)
try place.updateChanges(db) { $0.isFavorite = true }

// INSERT or UPDATE
try place.save(db)
let savedPlace = place.saved(db) // non-mutating

// UPSERT
try place.upsert(db)
let insertedPlace = place.upsertAndFetch(db)

// DELETE
try place.delete(db)

// EXISTENCE CHECK
let exists = try place.exists(db)
```

See [Upsert](#upsert) below for more information about upserts.

**The [TableRecord](#tablerecord-protocol) protocol comes with batch operations**:

```swift
// UPDATE
try Place.updateAll(db, ...)

// DELETE
try Place.deleteAll(db)
try Place.deleteAll(db, ids:...)
try Place.deleteAll(db, keys:...)
try Place.deleteOne(db, id:...)
try Place.deleteOne(db, key:...)
```

For more information about batch updates, see [Update Requests](QueryInterface.md#update-requests).

- All persistence methods can throw a [DatabaseError](BackupAndUtilities.md#error-handling).

- `update` and `updateChanges` throw [RecordError](#recorderror) if the database does not contain any row for the primary key of the record.

- `save` makes sure your values are stored in the database. It performs an UPDATE if the record has a non-null primary key, and then, if no row was modified, an INSERT. It directly performs an INSERT if the record has no primary key, or a null primary key.

- `delete` and `deleteOne` returns whether a database row was deleted or not. `deleteAll` returns the number of deleted rows. `updateAll` returns the number of updated rows. `updateChanges` returns whether a database row was updated or not.

**All primary keys are supported**, including composite primary keys that span several columns, and the [hidden `rowid` column](https://www.sqlite.org/rowidtable.html).

**To customize persistence methods**, you provide [Persistence Callbacks](#persistence-callbacks), described below. Do not attempt at overriding the ready-made persistence methods.

### Upsert

[UPSERT](https://www.sqlite.org/lang_UPSERT.html) is an SQLite feature that causes an INSERT to behave as an UPDATE or a no-op if the INSERT would violate a uniqueness constraint (primary key or unique index).

> **Note**: Upsert apis are available from SQLite 3.35.0+: iOS 15.0+, macOS 12.0+, tvOS 15.0+, watchOS 8.0+, or with a [custom SQLite build](CustomSQLiteBuilds.md) or [SQLCipher](Encryption.md).

[PersistableRecord](#persistablerecord-protocol) provides three upsert methods:

- `upsert(_:)`

    Inserts or updates a record.

    ```swift
    struct Player: Encodable, PersistableRecord {
        var id: Int64
        var name: String
        var score: Int
    }

    // INSERT INTO player (id, name, score)
    // VALUES (1, 'Arthur', 1000)
    // ON CONFLICT DO UPDATE SET
    //   name = excluded.name,
    //   score = excluded.score
    let player = Player(id: 1, name: "Arthur", score: 1000)
    try player.upsert(db)
    ```

- `upsertAndFetch(_:onConflict:doUpdate:)` (requires [FetchableRecord](#fetchablerecord-protocol) conformance)

    Inserts or updates a record, and returns the upserted record.

- `upsertAndFetch(_:as:onConflict:doUpdate:)` (does not require [FetchableRecord](#fetchablerecord-protocol) conformance)

    This method is identical to `upsertAndFetch(_:onConflict:doUpdate:)` described above, but you can provide a distinct [FetchableRecord](#fetchablerecord-protocol) record type as a result, in order to specify the returned columns.

### Persistence Methods and the `RETURNING` clause

SQLite is able to return values from a inserted, updated, or deleted row, with the [`RETURNING` clause](https://www.sqlite.org/lang_returning.html).

> **Note**: Support for the `RETURNING` clause is available from SQLite 3.35.0+: iOS 15.0+, macOS 12.0+, tvOS 15.0+, watchOS 8.0+, or with a [custom SQLite build](CustomSQLiteBuilds.md) or [SQLCipher](Encryption.md).

GRDB uses the `RETURNING` clause in all persistence methods that contain `AndFetch` in their name.

For example:

```swift
try dbQueue.write { db in
    let partialPlayer = PartialPlayer(name: "Alice")

    // INSERT INTO player (name) VALUES ('Alice') RETURNING *
    let player = try partialPlayer.insertAndFetch(db, as: Player.self)
    print(player.id)    // The inserted id
    print(player.name)  // The inserted name
    print(player.score) // The default score
}
```


### Persistence Callbacks

Your custom type may want to perform extra work when the persistence methods are invoked.

To this end, your record type can implement **persistence callbacks**. Callbacks are methods that get called at certain moments of a record's life cycle.

In order to use a callback method, you need to provide its implementation. For example, a frequently used callback is `didInsert`, in the case of auto-incremented database ids:

```swift
struct Player: MutablePersistableRecord {
    var id: Int64?

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

try dbQueue.write { db in
    var player = Player(id: nil, ...)
    try player.insert(db)
    print(player.id) // didInsert was called: prints some non-nil id
}
```

Callbacks can also help implementing record validation:

```swift
struct Link: PersistableRecord {
    var url: URL

    func willSave(_ db: Database) throws {
        if url.host == nil {
            throw ValidationError("url must be absolute.")
        }
    }
}

try link.insert(db) // Calls the willSave callback
try link.update(db) // Calls the willSave callback
try link.save(db)   // Calls the willSave callback
try link.upsert(db) // Calls the willSave callback
```

#### Available Callbacks

Here is a list with all the available persistence callbacks, listed in the same order in which they will get called during the respective operations:

- Inserting a record (all `record.insert` and `record.upsert` methods)
    - `willSave`
    - `aroundSave`
    - `willInsert`
    - `aroundInsert`
    - `didInsert`
    - `didSave`

- Updating a record (all `record.update` methods)
    - `willSave`
    - `aroundSave`
    - `willUpdate`
    - `aroundUpdate`
    - `didUpdate`
    - `didSave`

- Deleting a record (only the `record.delete(_:)` method)
    - `willDelete`
    - `aroundDelete`
    - `didDelete`

For detailed information about each callback, check the [reference](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/mutablepersistablerecord/).


## Identifiable Records

**When a record type maps a table with a single-column primary key, it is recommended to have it adopt the standard [Identifiable](https://developer.apple.com/documentation/swift/identifiable) protocol.**

```swift
struct Player: Identifiable, FetchableRecord, PersistableRecord {
    var id: Int64 // fulfills the Identifiable requirement
    var name: String
    var score: Int
}
```

When `id` has a [database-compatible type](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasevalueconvertible) (Int64, Int, String, UUID, ...), the `Identifiable` conformance unlocks type-safe record and request methods:

```swift
let player = try Player.find(db, id: 1)               // Player
let player = try Player.fetchOne(db, id: 1)           // Player?
let players = try Player.fetchAll(db, ids: [1, 2, 3]) // [Player]
let players = try Player.fetchSet(db, ids: [1, 2, 3]) // Set<Player>

let request = Player.filter(id: 1)
let request = Player.filter(ids: [1, 2, 3])

try Player.deleteOne(db, id: 1)
try Player.deleteAll(db, ids: [1, 2, 3])
```


## Codable Records

Record types that adopt an archival protocol ([Codable, Encodable or Decodable](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types)) get free database support just by declaring conformance to the desired [record protocols](#record-protocols-overview):

```swift
// Declare a record...
struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String
    var score: Int

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
}

// ...and there you go:
try dbQueue.write { db in
    try Player(id: 1, name: "Arthur", score: 100).insert(db)
    let players = try Player.order(\.score.desc).fetchAll(db)
}
```

Codable records encode and decode their properties according to their own implementation of the Encodable and Decodable protocols. Yet databases have specific requirements:

- Properties are always coded according to their preferred database representation, when they have one (all [values](SQLiteAPI.md#values) that adopt the [`DatabaseValueConvertible`](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasevalueconvertible) protocol).
- You can customize the encoding and decoding of dates and uuids.
- Complex properties (arrays, dictionaries, nested structs, etc.) are stored as JSON.

For more information about Codable records, see:

- [JSON Columns](#json-columns)
- [Column Names Coding Strategies](#column-names-coding-strategies)
- [Data, Date, and UUID Coding Strategies](#data-date-and-uuid-coding-strategies)
- [The userInfo Dictionary](#the-userinfo-dictionary)
- [Tip: Derive Columns from Coding Keys](#tip-derive-columns-from-coding-keys)

> :bulb: **Tip**: see the [Demo Applications](DemoApps) for sample code that uses Codable records.


### JSON Columns

When a [Codable record](#codable-records) contains a property that is not a simple [value](SQLiteAPI.md#values) (Bool, Int, String, Date, Swift enums, etc.), that value is encoded and decoded as a **JSON string**. For example:

```swift
enum AchievementColor: String, Codable {
    case bronze, silver, gold
}

struct Achievement: Codable {
    var name: String
    var color: AchievementColor
}

struct Player: Codable, FetchableRecord, PersistableRecord {
    var name: String
    var score: Int
    var achievements: [Achievement] // stored in a JSON column
}

try dbQueue.write { db in
    // INSERT INTO player (name, score, achievements)
    // VALUES (
    //   'Arthur',
    //   100,
    //   '[{"color":"gold","name":"Use Codable Records"}]')
    let achievement = Achievement(name: "Use Codable Records", color: .gold)
    let player = Player(name: "Arthur", score: 100, achievements: [achievement])
    try player.insert(db)
}
```

> :bulb: **Tip**: Make sure you set the JSONEncoder `sortedKeys` option. This option makes sure that the JSON output is stable. This stability is required for [Record Comparison](#record-comparison) to work as expected, and database observation tools such as [ValueObservation](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/valueobservation) to accurately recognize changed records.


### Column Names Coding Strategies

By default, [Codable Records](#codable-records) store their values into database columns that match their coding keys: the `teamID` property is stored into the `teamID` column.

This behavior can be overridden, so that you can, for example, store the `teamID` property into the `team_id` column:

```swift
protocol FetchableRecord {
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { get }
}

protocol EncodableRecord {
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { get }
}
```

See [DatabaseColumnDecodingStrategy](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasecolumndecodingstrategy) and [DatabaseColumnEncodingStrategy](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasecolumnencodingstrategy/) to learn about all available strategies.


### Data, Date, and UUID Coding Strategies

By default, [Codable Records](#codable-records) encode and decode their Data properties as blobs, and Date and UUID properties as described in the general [Date and DateComponents](SQLiteAPI.md#date-and-datecomponents) and [UUID](SQLiteAPI.md#uuid) chapters.

Those behaviors can be overridden:

```swift
protocol FetchableRecord {
    static func databaseDataDecodingStrategy(for column: String) -> DatabaseDataDecodingStrategy
    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy
}

protocol EncodableRecord {
    static func databaseDataEncodingStrategy(for column: String) -> DatabaseDataEncodingStrategy
    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy
    static func databaseUUIDEncodingStrategy(for column: String) -> DatabaseUUIDEncodingStrategy
}
```

See [DatabaseDataDecodingStrategy](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasedatadecodingstrategy/), [DatabaseDateDecodingStrategy](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasedatedecodingstrategy/), [DatabaseDataEncodingStrategy](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasedataencodingstrategy/), [DatabaseDateEncodingStrategy](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasedateencodingstrategy/), and [DatabaseUUIDEncodingStrategy](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databaseuuidencodingstrategy/) to learn about all available strategies.


### The userInfo Dictionary

Your [Codable Records](#codable-records) can be stored in the database, but they may also have other purposes. In this case, you may need to customize their implementations of `Decodable.init(from:)` and `Encodable.encode(to:)`, depending on the context.

The standard way to provide such context is the `userInfo` dictionary. Implement those properties:

```swift
protocol FetchableRecord {
    static var databaseDecodingUserInfo: [CodingUserInfoKey: Any] { get }
}

protocol EncodableRecord {
    static var databaseEncodingUserInfo: [CodingUserInfoKey: Any] { get }
}
```


### Tip: Derive Columns from Coding Keys

Codable types are granted with a [CodingKeys](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types) enum. You can use them to safely define database columns:

```swift
struct Player: Codable {
    var id: Int64
    var name: String
    var score: Int
}

extension Player: FetchableRecord, PersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
}
```

See the [query interface](QueryInterface.md) and [Recommended Practices for Designing Record Types](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/recordrecommendedpractices) for further information.


## Record Comparison

**Records that adopt the [EncodableRecord](#persistablerecord-protocol) protocol can compare against other records, or against previous versions of themselves.**

This helps avoiding costly UPDATE statements when a record has not been edited.

- [The `updateChanges` Methods](#the-updatechanges-methods)
- [The `databaseEquals` Method](#the-databaseequals-method)
- [The `databaseChanges` and `hasDatabaseChanges` Methods](#the-databasechanges-and-hasdatabasechanges-methods)


### The `updateChanges` Methods

The `updateChanges` methods perform a database update of the changed columns only (and does nothing if record has no change).

- `updateChanges(_:from:)`

    This method lets you compare two records:

    ```swift
    if let oldPlayer = try Player.fetchOne(db, id: 42) {
        var newPlayer = oldPlayer
        newPlayer.score = 100
        if try newPlayer.updateChanges(db, from: oldPlayer) {
            print("player was modified, and updated in the database")
        } else {
            print("player was not modified, and database was not hit")
        }
    }
    ```

- `updateChanges(_:modify:)`

    This method lets you update a record in place:

    ```swift
    if var player = try Player.fetchOne(db, id: 42) {
        let modified = try player.updateChanges(db) {
            $0.score = 100
        }
        if modified {
            print("player was modified, and updated in the database")
        } else {
            print("player was not modified, and database was not hit")
        }
    }
    ```

### The `databaseEquals` Method

This method returns whether two records have the same database representation:

```swift
let oldPlayer: Player = ...
var newPlayer: Player = ...
if newPlayer.databaseEquals(oldPlayer) == false {
    try newPlayer.save(db)
}
```


### The `databaseChanges` and `hasDatabaseChanges` Methods

`databaseChanges(from:)` returns a dictionary of differences between two records:

```swift
let oldPlayer = Player(id: 1, name: "Arthur", score: 100)
let newPlayer = Player(id: 1, name: "Arthur", score: 1000)
for (column, oldValue) in try newPlayer.databaseChanges(from: oldPlayer) {
    print("\(column) was \(oldValue)")
}
// prints "score was 100"
```


## Record Customization Options

GRDB records come with many default behaviors, that are designed to fit most situations. Many of those defaults can be customized for your specific needs:

- [Persistence Callbacks](#persistence-callbacks): define what happens when you call a persistence method such as `player.insert(db)`
- [Conflict Resolution](#conflict-resolution): Run `INSERT OR REPLACE` queries, and generally define what happens when a persistence method violates a unique index.
- [Columns Selected by a Request](QueryInterface.md#columns-selected-by-a-request): define which columns are selected by requests such as `Player.fetchAll(db)`.
- [Beyond FetchableRecord](#beyond-fetchablerecord): the FetchableRecord protocol is not the end of the story.

[Codable Records](#codable-records) have a few extra options:

- [JSON Columns](#json-columns): control the format of JSON columns.
- [Column Names Coding Strategies](#column-names-coding-strategies): control how coding keys are turned into column names
- [Date and UUID Coding Strategies](#data-date-and-uuid-coding-strategies): control the format of Date and UUID properties in your Codable records.
- [The userInfo Dictionary](#the-userinfo-dictionary): adapt your Codable implementation for the database.


### Conflict Resolution

**Insertions and updates can create conflicts**: for example, a query may attempt to insert a duplicate row that violates a unique index.

Those conflicts normally end with an error. Yet SQLite let you alter the default behavior, and handle conflicts with specific policies. For example, the `INSERT OR REPLACE` statement handles conflicts with the "replace" policy which replaces the conflicting row instead of throwing an error.

The [five different policies](https://www.sqlite.org/lang_conflict.html) are: abort (the default), replace, rollback, fail, and ignore.

When you want to handle conflicts at the query level, specify a custom `persistenceConflictPolicy` in your type that adopts the PersistableRecord protocol:

```swift
struct Player : MutablePersistableRecord {
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace)
}

// INSERT OR REPLACE INTO player (...) VALUES (...)
try player.insert(db)
```


### Beyond FetchableRecord

**Some GRDB users eventually discover that the [FetchableRecord](#fetchablerecord-protocol) protocol does not fit all situations.** Use cases that are not well handled by FetchableRecord include:

- Your application needs polymorphic row decoding: it decodes some type or another, depending on the values contained in a database row.

- Your application needs to decode rows with a context: each decoded value should be initialized with some extra value that does not come from the database.

Since those use cases are not well handled by FetchableRecord, don't try to implement them on top of this protocol: you'll just fight the framework.


## Examples of Record Definitions

We will show below how to declare a record type for the following database table:

```swift
try dbQueue.write { db in
    try db.create(table: "place") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("title", .text).notNull()
        t.column("isFavorite", .boolean).notNull().defaults(to: false)
        t.column("longitude", .double).notNull()
        t.column("latitude", .double).notNull()
    }
}
```

Each one of the three examples below is correct. You will pick one or the other depending on your personal preferences and the requirements of your application:

<details>
  <summary>Define a Codable struct, and adopt the record protocols you need</summary>

This is the shortest way to define a record type.

See the [Record Protocols Overview](#record-protocols-overview), and [Codable Records](#codable-records) for more information.

```swift
struct Place: Codable {
    var id: Int64?
    var title: String
    var isFavorite: Bool
    private var latitude: CLLocationDegrees
    private var longitude: CLLocationDegrees

    var coordinate: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
}

// SQL generation
extension Place: TableRecord {
    /// The table columns
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let isFavorite = Column(CodingKeys.isFavorite)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
    }
}

// Fetching methods
extension Place: FetchableRecord { }

// Persistence methods
extension Place: MutablePersistableRecord {
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

</details>

<details>
  <summary>Define a plain struct, and adopt the record protocols you need</summary>

See the [Record Protocols Overview](#record-protocols-overview) for more information.

```swift
struct Place {
    var id: Int64?
    var title: String
    var isFavorite: Bool
    var coordinate: CLLocationCoordinate2D
}

// SQL generation
extension Place: TableRecord {
    /// The table columns
    enum Columns {
        static let id = Column("id")
        static let title = Column("title")
        static let isFavorite = Column("isFavorite")
        static let latitude = Column("latitude")
        static let longitude = Column("longitude")
    }
}

// Fetching methods
extension Place: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        isFavorite = row[Columns.isFavorite]
        coordinate = CLLocationCoordinate2D(
            latitude: row[Columns.latitude],
            longitude: row[Columns.longitude])
    }
}

// Persistence methods
extension Place: MutablePersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.isFavorite] = isFavorite
        container[Columns.latitude] = coordinate.latitude
        container[Columns.longitude] = coordinate.longitude
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

</details>

<details>
  <summary>Define a plain struct optimized for fetching performance</summary>

This struct derives its persistence methods from the standard Encodable protocol (see [Codable Records](#codable-records)), but performs optimized row decoding by accessing database columns with numeric indexes.

See the [Record Protocols Overview](#record-protocols-overview) for more information.

```swift
struct Place: Encodable {
    var id: Int64?
    var title: String
    var isFavorite: Bool
    private var latitude: CLLocationDegrees
    private var longitude: CLLocationDegrees

    var coordinate: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
}

// SQL generation
extension Place: TableRecord {
    /// The table columns
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let isFavorite = Column(CodingKeys.isFavorite)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
    }

    /// Arrange the selected columns and lock their order
    static var databaseSelection: [any SQLSelectable] {
        [
            Columns.id,
            Columns.title,
            Columns.favorite,
            Columns.latitude,
            Columns.longitude,
        ]
    }
}

// Fetching methods
extension Place: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        // For high performance, use numeric indexes that match the
        // order of Place.databaseSelection
        id = row[0]
        title = row[1]
        isFavorite = row[2]
        coordinate = CLLocationCoordinate2D(
            latitude: row[3],
            longitude: row[4])
    }
}

// Persistence methods
extension Place: MutablePersistableRecord {
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

</details>


## RecordError

RecordError is thrown by persistence methods when a record cannot be found in the database:

```swift
do {
    try player.update(db)
} catch RecordError.recordNotFound(databaseTableName: let tableName, key: let key) {
    print("No player found with key \(key) in table \(tableName)")
}
```


## RowDecodingError

RowDecodingError is thrown when a record cannot be decoded from a database row:

```swift
do {
    let player = try Player.fetchOne(db, sql: "SELECT ...")
} catch let error as RowDecodingError {
    print(error.description)
}
```

See the [reference](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/rowdecodingerror) for more information.
