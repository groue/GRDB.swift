SQL Interpolation
=================

**SQL Interpolation**, available in Swift 5, lets you embed values in your SQL queries by wrapping them inside `\(` and `)`:

```swift
let name: String = ...
let id: Int64 = ...
try db.execute(literal: "UPDATE player SET name = \(name) WHERE id = \(id)")
```

SQL interpolation looks and feel just like regular [Swift interpolation]:

```swift
let name = "World"
print("Hello \(name)!") // prints "Hello World!"
```

The difference is that it generates valid SQL which does not suffer from syntax errors or [SQL injection]. For example, you do not need to validate input or process single quotes:

```swift
// Correctly executes UPDATE player SET name = 'O''Brien' WHERE id = 42
let name = "O'Brien"
let id = 42
try db.execute(literal: "UPDATE player SET name = \(name) WHERE id = \(id)")
```

Under the hood, SQL interpolation generates a plain SQL query string, as well as statement arguments. It runs exactly as below:

```swift
try db.execute(sql: "UPDATE player SET name = ? WHERE id = ?", arguments: [name, id])
```

SQL interpolation is handy and safe, but you may also want to build your own raw SQL strings:

- :point_right: For raw SQL strings, use the `sql` argument label:

    ```swift
    // sql: Raw SQL string
    try db.execute(sql: "UPDATE player SET name = ? WHERE id = ?", arguments: [name, id])
    ```

- :point_right: For SQL interpolation, use the `literal` argument label:

    ```swift
    // literal: SQL Interpolation
    try db.execute(literal: "UPDATE player SET name = \(name) WHERE id = \(id)")
    ```


[Swift interpolation]: https://docs.swift.org/swift-book/LanguageGuide/StringsAndCharacters.html#ID292
[SQL injection]: ../README.md#avoiding-sql-injection
