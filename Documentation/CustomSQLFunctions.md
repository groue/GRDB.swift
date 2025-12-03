Custom SQL Functions and Aggregates
====================================

**SQLite lets you define SQL functions and aggregates.**

A custom SQL function or aggregate extends SQLite:

```sql
SELECT reverse(name) FROM player;   -- custom function
SELECT maxLength(name) FROM player; -- custom aggregate
```

- [Custom SQL Functions](#custom-sql-functions)
- [Custom Aggregates](#custom-aggregates)


## Custom SQL Functions

A *function* argument takes an array of [DatabaseValue](SQLiteAPI.md#databasevalue), and returns any valid [value](SQLiteAPI.md#values) (Bool, Int, String, Date, Swift enums, etc.) The number of database values is guaranteed to be *argumentCount*.

SQLite has the opportunity to perform additional optimizations when functions are "pure", which means that their result only depends on their arguments. So make sure to set the *pure* argument to true when possible.

```swift
let reverse = DatabaseFunction("reverse", argumentCount: 1, pure: true) { (values: [DatabaseValue]) in
    // Extract string value, if any...
    guard let string = String.fromDatabaseValue(values[0]) else {
        return nil
    }
    // ... and return reversed string:
    return String(string.reversed())
}
```

You make a function available to a database connection through its configuration:

```swift
var config = Configuration()
config.prepareDatabase { db in
    db.add(function: reverse)
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

try dbQueue.read { db in
    // "oof"
    try String.fetchOne(db, sql: "SELECT reverse('foo')")!
}
```


**Functions can take a variable number of arguments:**

When you don't provide any explicit *argumentCount*, the function can take any number of arguments:

```swift
let averageOf = DatabaseFunction("averageOf", pure: true) { (values: [DatabaseValue]) in
    let doubles = values.compactMap { Double.fromDatabaseValue($0) }
    return doubles.reduce(0, +) / Double(doubles.count)
}
db.add(function: averageOf)

// 2.0
try Double.fetchOne(db, sql: "SELECT averageOf(1, 2, 3)")!
```


**Functions can throw:**

```swift
let sqrt = DatabaseFunction("sqrt", argumentCount: 1, pure: true) { (values: [DatabaseValue]) in
    guard let double = Double.fromDatabaseValue(values[0]) else {
        return nil
    }
    guard double >= 0 else {
        throw DatabaseError(message: "invalid negative number")
    }
    return sqrt(double)
}
db.add(function: sqrt)

// SQLite error 1 with statement `SELECT sqrt(-1)`: invalid negative number
try Double.fetchOne(db, sql: "SELECT sqrt(-1)")!
```


**Use custom functions in the [query interface](QueryInterface.md):**

```swift
// SELECT reverseString("name") FROM player
Player.select { reverseString($0.name) }
```


**GRDB ships with built-in SQL functions that perform unicode-aware string transformations.** See [Unicode](BackupAndUtilities.md#unicode).


## Custom Aggregates

Before registering a custom aggregate, you need to define a type that adopts the `DatabaseAggregate` protocol:

```swift
protocol DatabaseAggregate {
    // Initializes an aggregate
    init()

    // Called at each step of the aggregation
    mutating func step(_ dbValues: [DatabaseValue]) throws

    // Returns the final result
    func finalize() throws -> DatabaseValueConvertible?
}
```

For example:

```swift
struct MaxLength : DatabaseAggregate {
    var maxLength: Int = 0

    mutating func step(_ dbValues: [DatabaseValue]) {
        // At each step, extract string value, if any...
        guard let string = String.fromDatabaseValue(dbValues[0]) else {
            return
        }
        // ... and update the result
        let length = string.count
        if length > maxLength {
            maxLength = length
        }
    }

    func finalize() -> DatabaseValueConvertible? {
        maxLength
    }
}

let maxLength = DatabaseFunction(
    "maxLength",
    argumentCount: 1,
    pure: true,
    aggregate: MaxLength.self)
```

Like [custom SQL Functions](#custom-sql-functions), you make an aggregate function available to a database connection through its configuration:

```swift
var config = Configuration()
config.prepareDatabase { db in
    db.add(function: maxLength)
}
let dbQueue = try DatabaseQueue(path: dbPath, configuration: config)

try dbQueue.read { db in
    // Some Int
    try Int.fetchOne(db, sql: "SELECT maxLength(name) FROM player")!
}
```

The `step` method of the aggregate takes an array of [DatabaseValue](SQLiteAPI.md#databasevalue). This array contains as many values as the *argumentCount* parameter (or any number of values, when *argumentCount* is omitted).

The `finalize` method of the aggregate returns the final aggregated [value](SQLiteAPI.md#values) (Bool, Int, String, Date, Swift enums, etc.).

SQLite has the opportunity to perform additional optimizations when aggregates are "pure", which means that their result only depends on their inputs. So make sure to set the *pure* argument to true when possible.


**Use custom aggregates in the [query interface](QueryInterface.md):**

```swift
// SELECT maxLength("name") FROM player
let request = Player.select { maxLength($0.name) }
try Int.fetchOne(db, request) // Int?
```
