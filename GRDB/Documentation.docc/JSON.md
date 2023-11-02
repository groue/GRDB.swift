# JSON Support

Store and use JSON values in SQLite databases.

## Overview

SQLite and GRDB can store and fetch JSON values in database columns. Starting iOS 16+, macOS 10.15+, tvOS 17+, and watchOS 9+, JSON values can be manipulated at the database level.

## Store and fetch JSON values

### JSON columns in the database schema

It is recommended to store JSON values in text columns. In the example below, we create a ``Database/ColumnType/jsonText`` column with ``Database/create(table:options:body:)``:

```swift
try db.create(table: "player") { t in
    t.primaryKey("id", .text)
    t.column("name", .text).notNull()
    t.column("address", .jsonText).notNull() // A JSON column
}
```

> Note: `.jsonText` and `.text` are equivalent, because both build a TEXT column in SQL. Yet the former better describes the intent of the column.
>
> Note: SQLite JSON functions and operators are [documented](https://www.sqlite.org/json1.html#interface_overview) to throw errors if any of their arguments are binary blobs. That's the reason why it is recommended to store JSON as text.

> Tip: When an application performs queries on values embedded inside JSON columns, indexes can help performance:
>
> ```swift
> // CREATE INDEX "player_on_country" 
> // ON "player"("address" ->> 'country')
> try db.create(
>     index: "player_on_country",
>     on: "player",
>     expressions: [
>         JSONColumn("address")["country"],
>     ])
>
> // SELECT * FROM player
> // WHERE "address" ->> 'country' = 'DE'
> let germanPlayers = try Player
>     .filter(JSONColumn("address")["country"] == "DE")
>     .fetchAll(db)
> ```

### Strict and flexible JSON schemas

[Codable Records](https://github.com/groue/GRDB.swift/blob/master/README.md#codable-records) handle both strict and flexible JSON schemas.

**For strict schemas**, use `Codable` properties. They will be stored as JSON strings in the database:

```swift
struct Address: Codable {
    var street: String
    var city: String
    var country: String
}

struct Player: Codable {
    var id: String
    var name: String

    // Stored as a JSON string
    // {"street": "...", "city": "...",  "country": "..."} 
    var address: Address
}

extension Player: FetchableRecord, PersistableRecord { }
```

**For flexible schemas**, use `String` or `Data` properties.

In the specific case of `Data` properties, it is recommended to store them as text in the database, because SQLite JSON functions and operators are [documented](https://www.sqlite.org/json1.html#interface_overview) to throw errors if any of their arguments are binary blobs. This encoding is automatic with ``DatabaseDataEncodingStrategy/text``:

```swift
// JSON String property
struct Player: Codable {
    var id: String
    var name: String
    var address: String // JSON string
}

extension Player: FetchableRecord, PersistableRecord { }

// JSON Data property, saved as text in the database
struct Team: Codable {
    var id: String
    var color: String
    var info: Data // JSON UTF8 data
}

extension Team: FetchableRecord, PersistableRecord {
    // Support SQLite JSON functions and operators
    // by storing JSON data as database text:
    static let databaseDataEncodingStrategy = DatabaseDataEncodingStrategy.text
}
```

## Manipulate JSON values at the database level

[SQLite JSON functions and operators](https://www.sqlite.org/json1.html) are available starting iOS 16+, macOS 10.15+, tvOS 17+, and watchOS 9+.

Functions such as `JSON`, `JSON_EXTRACT`, `JSON_PATCH` and others are available as static methods on `Database`: ``Database/json(_:)``, ``Database/jsonExtract(_:atPath:)``, ``Database/jsonPatch(_:with:)``, etc.

See the full list below.

## JSON table-valued functions

The JSON table-valued functions `json_each` and `json_tree` are not supported.

## Topics

### JSON Values

- ``SQLJSONExpressible``
- ``JSONColumn``

### Access JSON subcomponents, and query JSON values, at the SQL level

The `->` and `->>` SQL operators are available on the ``SQLJSONExpressible`` protocol.

- ``Database/jsonArrayLength(_:)``
- ``Database/jsonArrayLength(_:atPath:)``
- ``Database/jsonExtract(_:atPath:)``
- ``Database/jsonExtract(_:atPaths:)``
- ``Database/jsonType(_:)``
- ``Database/jsonType(_:atPath:)``

### Build new JSON values at the SQL level

- ``Database/json(_:)``
- ``Database/jsonArray(_:)-8xxe3``
- ``Database/jsonArray(_:)-469db``
- ``Database/jsonObject(_:)``
- ``Database/jsonQuote(_:)``
- ``Database/jsonGroupArray(_:filter:)``
- ``Database/jsonGroupObject(key:value:filter:)``

### Modify JSON values at the SQL level

- ``Database/jsonInsert(_:_:)``
- ``Database/jsonPatch(_:with:)``
- ``Database/jsonReplace(_:_:)``
- ``Database/jsonRemove(_:atPath:)``
- ``Database/jsonRemove(_:atPaths:)``
- ``Database/jsonSet(_:_:)``

### Validate JSON values at the SQL level

- ``Database/jsonErrorPosition(_:)``
- ``Database/jsonIsValid(_:)``
