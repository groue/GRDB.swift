# ``GRDB/DatabaseValueConvertible``

A type that can convert itself into and out of a database value.

## Overview

A `DatabaseValueConvertible` type supports conversion to and from database values (null, integers, doubles, strings, and blobs). `DatabaseValueConvertible` is adopted by `Bool`, `Int`, `String`, `Date`, etc.

> Note: Types that converts to and from multiple columns in a database row must not conform to the `DatabaseValueConvertible` protocol. Those types are called **record types**, and should conform to record protocols instead. See <doc:QueryInterface>.

## Conforming to the DatabaseValueConvertible Protocol

To conform to `DatabaseValueConvertible`, implement the two requirements ``fromDatabaseValue(_:)-21zzv`` and ``databaseValue-1ob9k``. Do not customize the ``fromMissingColumn()-7iamp`` requirement. Do not customize the conformance of `Optional`: it is built-in when the wrapped type is itself `DatabaseValueConvertible`.

It is important that the implementation of `fromDatabaseValue` returns nil if the type can not be decoded from the raw database value. This nil value will have GRDB throw a decoding error accordingly.

For example:

```swift
struct EvenInteger {
    let value: Int // Guaranteed even

    init?(_ value: Int) {
        guard value.isMultiple(of: 2) else {
            return nil // Not an even number
        }
        self.value = value
    }
}

extension EvenInteger: DatabaseValueConvertible {
    var databaseValue: DatabaseValue {
        value.databaseValue
    }

    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let value = Int.fromDatabaseValue(dbValue) else {
            return nil // Not an integer
        }
        return EvenInteger(value) // Nil if not even
    }
}
```

### Built-in RawRepresentable support

`DatabaseValueConvertible` implementation is ready-made for `RawRepresentable` types whose raw value is itself `DatabaseValueConvertible`, such as enums:

```swift
enum Grape: String {
    case chardonnay, merlot, riesling
}

// Empty DatabaseValueConvertible adoption is enough
extension Grape: DatabaseValueConvertible { }
```

### Built-in Codable support

`DatabaseValueConvertible` is also ready-made for `Codable` types, which are automatically coded and decoded from JSON arrays and objects:

```swift
struct Color: Codable {
    var r: Double
    var g: Double
    var b: Double
}

// Encodes and decodes `Color` as a JSON object in the database:
extension Color: DatabaseValueConvertible { }
```

By default, such codable value types are encoded and decoded with the standard [JSONDecoder](https://developer.apple.com/documentation/foundation/jsondecoder) and [JSONEncoder](https://developer.apple.com/documentation/foundation/jsonencoder). `Data` values are handled with the `.base64` strategy, `Date` with the `.millisecondsSince1970` strategy, and non conforming floats with the `.throw` strategy.

In order to customize the JSON format, provide a custom implementation of the `DatabaseValueConvertible` requirements.

### Adding support for the Tagged library

[Tagged](https://github.com/pointfreeco/swift-tagged) is a popular library that makes it possible to enhance the type-safety of our programs with dedicated wrappers around basic types. For example:

```swift
import Tagged

struct Player: Identifiable {
    // Player.ID can not be mismatched with Team.ID or Award.ID, even
    // though they all wrap strings.
    typealias ID = Tagged<Player, String>
    var id: ID
    var name: String
    var score: Int
}
```

Applications that use both Tagged and GRDB will want to add those lines somewhere:

```swift
import GRDB
import Tagged

extension Tagged: SQLExpressible where RawValue: SQLExpressible { }
extension Tagged: StatementBinding where RawValue: StatementBinding { }
extension Tagged: DatabaseValueConvertible where RawValue: DatabaseValueConvertible { }
```

This makes it possible to use `Tagged` values in all the expected places:

```swift
let id: Player.ID = ...
let player = try Player.find(db, id: id)
```

## Optimized Values

For extra performance, custom value types can conform to both `DatabaseValueConvertible` and ``StatementColumnConvertible``. This extra protocol grants raw access to the [low-level C SQLite interface](https://www.sqlite.org/c3ref/column_blob.html) when decoding values.

For example:

```swift
extension EvenInteger: StatementColumnConvertible {
    init?(sqliteStatement: SQLiteStatement, index: CInt) {
        let int64 = sqlite3_column_int64(sqliteStatement, index)
        guard let value = Int(exactly: int64) else {
            return nil // Does not fit Int (probably a 32-bit architecture)
        }
        self.init(value) // Nil if not even
    }
}
```

> Note: Standard collections `Array`, `Set`, and `Dictionary` do not conform to `DatabaseValueConvertible`, on purpose. You won't be able to directly fetch or store arrays, sets, or dictionaries as JSON database values.
>
> Standard collections get free JSON support when they are embedded as properties of `Codable` record types, though: see <doc:QueryInterface>.
>
> It is not advised to consider the absence of those conformances as a lack, and add `DatabaseValueConvertible` conformance to those collection types in your application. This would litter JSON values in unexpected places, and foster misuse. For example, it is better when the code below *does not compile*:
>
> ```swift
> // MISUSE: if Array would conform to DatabaseValueConvertible, this
> // code would compile, and run the incorrect SQLite query
> // `SELECT ... WHERE id IN ('[1,2,3]')`, instead of the expected
> // `SELECT ... WHERE id IN (1, 2, 3)`.
> let ids = [1, 2, 3]
> let players = try Player.fetchAll(db, sql: """
>     SELECT * FROM player WHERE id IN (?)
>     """, arguments: [ids])
> ```
>
> Correct and fostered versions of the code above are:
>
> ```swift
> // CORRECT (explicit SQLite arguments):
> let ids = [1, 2, 3]
> let questionMarks = databaseQuestionMarks(count: ids.count) // "?,?,?"
> let players = try Player.fetchAll(db, sql: """
>     SELECT * FROM player WHERE id IN (\(questionMarks))
>     """, arguments: StatementArguments(ids))
>
> // CORRECT (SQL interpolation):
> let ids = [1, 2, 3]
> let request: SQLRequest<Player> = """
>     SELECT * FROM player WHERE id IN \(ids)
>     """
> let players = try request.fetchAll(db)
> ```

## Topics

### Creating a Value

- ``fromDatabaseValue(_:)-21zzv``
- ``fromMissingColumn()-7iamp``

### Accessing the DatabaseValue

- ``databaseValue-1ob9k``

### Fetching Values from Raw SQL

- ``fetchCursor(_:sql:arguments:adapter:)-6elcz``
- ``fetchAll(_:sql:arguments:adapter:)-1cqyb``
- ``fetchSet(_:sql:arguments:adapter:)-5jene``
- ``fetchOne(_:sql:arguments:adapter:)-qvqp``

### Fetching Values from a Prepared Statement

- ``fetchCursor(_:arguments:adapter:)-4l6af``
- ``fetchAll(_:arguments:adapter:)-3abuc``
- ``fetchSet(_:arguments:adapter:)-6y54n``
- ``fetchOne(_:arguments:adapter:)-3d7ax``

### Fetching Values from a Request

- ``fetchCursor(_:_:)-8q4r6``
- ``fetchAll(_:_:)-9hkqs``
- ``fetchSet(_:_:)-1foke``
- ``fetchOne(_:_:)-o6yj``

### Supporting Types

- ``DatabaseValueCursor``
- ``StatementBinding``
