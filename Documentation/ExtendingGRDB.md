GRDB Extension Guide
====================

**Some parts of GRDB are extensible, so that you can make it better fit your needs.**

This guide is a step-by-step tour of GRDB extensibility, around a few topics:

- **[Add a value type](#add-a-value-type)**
    
    You'll learn how to turn UIColor into a value type that you can store, fetch, and use in your records:
    
    ```swift
    let rows = try Row.fetchCursor(db, "SELECT name, color FROM clothes")
    while let row = try rows.next() {
        let name: String = row.value(named: "name")
        let color: UIColor = row.value(named: "color")      // <-- New! UIColor as value
    }
    ```

- **[Add an SQLite function or operator](#add-an-sqlite-function-or-operator)**
    
    You'll learn how to add support for the [STRFTIME](https://www.sqlite.org/lang_datefunc.html) function, and the [GLOB](https://www.sqlite.org/lang_expr.html#like) operator:
    
    ```swift
    Books.select(strftime("%Y", Column("publishedDate")))    // <-- New! strftime function
    Books.filter(Column("body").glob("*Moby-Dick*"))         // <-- New! glob method
    ```

- **[Add a new kind of SQLite expression](#add-a-new-kind-of-sqlite-expression)**
    
    You'll learn how to add support for [CAST expressions](https://www.sqlite.org/lang_expr.html#castexpr):
    
    ```swift
    let jsonString = Column("jsonString")
    let request = Books.select(cast(jsonString, as: .blob)) // <-- New! cast function
    let rows = try Row.fetchCursor(db, request)
    while let row = try rows.next() {
        let data = row.dataNoCopy(atIndex: 0)
    }
    ```

- **Extend the query interface requests**
    
    You may need to extend the [query interface requests](../../../#requests) so that their SELECT queries could embed recursive clauses, table joins, etc.
    
    Pull requests are welcome. Open issues if you have questions.
    
    Meanwhile, you can build your own [custom requests](../../../#custom-requests).

- **[Add a custom FTS5 full-text tokenizer](FTS5Tokenizers.md)**
    
    Custom tokenizers can leverage extra full-text features such as synonyms or stop words.

- **Support a new kind of SQL query**
    
    For example, you may need to generate SQL triggers, or create specific kinds of virtual tables.
    
    Pull requests are welcome. Open issues if you have questions.


## Add a Value Type

**All value types adopt the [DatabaseValueConvertible protocol](../../../#custom-value-types).**

```swift
protocol DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue { get }
    
    /// Returns a value initialized from databaseValue, if possible.
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self?
}
```

The `databaseValue` property returns [DatabaseValue](../../../#databasevalue), a type that wraps the five values supported by SQLite: NULL, Int64, Double, String and Data. Since DatabaseValue has no public initializer, use `DatabaseValue.null`, or another type that already adopts the protocol: `1.databaseValue`, `"foo".databaseValue`, etc. Conversion to DatabaseValue *must not* fail.

The `fromDatabaseValue()` factory method returns an instance of your custom type if the databaseValue contains a suitable value. If the databaseValue does not contain a suitable value, such as "foo" for Date, `fromDatabaseValue` *must* return nil (GRDB will interpret this nil result as a conversion error, and react accordingly).

**What does the DatabaseValueConvertible protocol bring to a type like UIColor?**

Well, you will be able to use UIColor like all other [value types](../../../#values) (Bool, Int, String, Date, Swift enums, etc.):

- Use UIColor as [statement arguments](../../../#executing-updates):
    
    ```swift
    try db.execute(
        "INSERT INTO clothes (name, color) VALUES (?, ?)",
        arguments: ["Shirt", UIColor.red])
    ```
    
- UIColor can be [extracted from rows](../../../#column-values):
    
    ```swift
    let rows = try Row.fetchCursor(db, "SELECT * FROM clothes")
    while let row = try rows.next() {
        let name: String = row.value(named: "name")
        let color: UIColor = row.value(named: "color")
    }
    ```
    
- UIColor can be [directly fetched](../../../#value-queries):
    
    ```swift
    let colors = try UIColor.fetchAll(db, "SELECT DISTINCT color FROM clothes")  // [UIColor]
    ```
    
- Use UIColor in [Records](../../../#records):
    
    ```swift
    class ClothingItem : Record {
        var name: String
        var color: UIColor
        
        required init(row: Row) {
            name = row.value(named: "name")
            color = row.value(named: "color")
            super.init(row: row)
        }
        
        override var persistentDictionary: [String: DatabaseValueConvertible?] {
            return ["name": name, "color": color]
        }
    }
    ```
    
- Use UIColor in the [query interface](../../../#the-query-interface):
    
    ```swift
    let redClothes = try ClothingItem.filter(colorColumn == UIColor.red).fetchAll(db)
    ```

**Let's have UIColor adopt DatabaseValueConvertible**

In order to preserve as most information as possible, we'll archive UIColor as a data blob using the NSCoding protocol. But YMMV.

```swift
extension UIColor : DatabaseValueConvertible {
    
    /// Encode UIColor as a data blob
    var databaseValue: DatabaseValue {
        // Use NSKeyedArchiver to build Data
        let data = NSKeyedArchiver.archivedData(withRootObject: self)
        
        // Data is already DatabaseValueConvertible
        return data.databaseValue
    }
    
    /// Returns a UIColor if databaseValue contains suitable data, and
    /// nil otherwise.
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Self? {
        // Only Data blobs can contain a UIColor
        guard let data = Data.fromDatabaseValue(databaseValue) else {
            return nil
        }
        
        // We're looking for an archived object
        guard let color = NSKeyedUnarchiver.unarchiveObject(with: data) else {
            return nil
        }
        
        // The cast function will return nil if the unarchived object doesn't
        // have the correct type
        return cast(color)   // Converts Any to Self?
    }
}
```

Use the `cast` utility function when you want *non-final classes* to implement DatabaseValueConvertible. It avoids compiler errors that are not easy to deal with. Note that final classes and value types won't need it.

```swift
// Workaround Swift inconvenience around factories methods of non-final classes
func cast<T, U>(_ value: T) -> U? {
    return value as? U
}
```


## Add an SQLite Function or Operator

**When an SQLite [function](https://www.sqlite.org/lang_corefunc.html) or [operator](https://www.sqlite.org/lang_expr.html) is missing from GRDB**, this usually means that there hasn't been a [feature request](http://github.com/groue/GRDB.swift/issues) yet.

But you don't have to wait: you can extend GRDB and the query interface to add support for the missing syntax element (and eventually submit a pull request later).

Let's remind our goal: we'll add the [STRFTIME](https://www.sqlite.org/lang_datefunc.html) function, and the [GLOB](https://www.sqlite.org/lang_expr.html#like) operator.

Their SQL usage is the following:

```sql
-- Publication years of books
SELECT STRFTIME('%Y', publishedOn) FROM books;
-- Books that talk about Moby Dick
SELECT * FROM books WHERE body GLOB '*Moby-Dick*';
```

Translated in the query interface, this gives:

```swift
Books.select(strftime("%Y", Column("publishedDate")))
Books.filter(Column("body").glob("*Moby-Dick*"))
```

`strftime` is a top-level Swift function because this is how GRDB usually imports SQLite functions which do not have matching standard Swift counterpart, like AVG, LEGNTH, SUM. It helps the Swift code looking like SQL when it is relevant.

In the same fashion, we expose the GLOB SQL operator as the `glob` Swift method, just because `value.glob(pattern)` reads like `value GLOB pattern`.

Whenever you import a SQL feature to Swift, you'll have to decide: should you preserve the SQL look and feel, or adopt a well-established swiftism? It's really up to you.


### STRFTIME

The [STRFTIME](https://www.sqlite.org/lang_datefunc.html) SQL function accepts many arguments. We'll simplify it to `strftime(format, date)`, so that we can write:

```sql
// Publication years of books
// SELECT STRFTIME('%Y', publishedOn) FROM books
Books.select(strftime("%Y", Column("publishedDate")))
```

The signature of the Swift `strftime` function is:

```swift
func strftime(_ format: String, _ date: SQLSpecificExpressible) -> SQLExpression
```

SQLSpecificExpressible and SQLExpression are types of the [query interface](../../../#the-query-interface) that you do not usually see. We have moved down one floor, closer to the SQL guts of GRDB. We'll see more new types and protocols below.

The return value is SQLExpression. All GRDB functions and operators that build [query interface expressions](../../../#expressions) return values of this type. It represents actual [SQLite expressions](https://www.sqlite.org/lang_expr.html).

SQLExpression is a protocol, so that you can build your own [custom expressions](#add-a-new-kind-of-sqlite-expression). But GRDB ships with a variety of [built-in expressions](#built-in-expressions) that are ready-made, and here we'll use SQLExpressionFunction that is dedicated to function calls:

```swift
struct SQLExpressionFunction : SQLExpression {
    /// Creates an SQL function call
    ///
    ///     // ABS(-1)
    ///     SQLExpressionFunction(.abs, arguments: -1)
    init(_ functionName: SQLFunctionName, arguments: SQLExpressible...)
}
```

So here is the code that defines our `strftime` function:

```swift
// Add a SQLFunctionName just like we add NSNotification.Name since
// the release of Swift 3.
extension SQLFunctionName {
    /// The `STRFTIME` SQL function
    static let strftime = SQLFunctionName("STRFTIME")
}

/// Returns an expression that evaluates the `STRFTIME` SQL function.
///
///     // STRFTIME('%Y', date)
///     strftime("%Y", Column("date"))
func strftime(_ format: String, _ date: SQLSpecificExpressible) -> SQLExpression {
    return SQLExpressionFunction(.strftime, arguments: format, date)
}
```

The `strftime` function is now complete, ready to be used. We haven't yet described the SQLSpecificExpressible type of the `date` argument:

SQLSpecificExpressible is the protocol for all types that can be turned into a SQL expression, but types like Int, Date, or UIColor that exist outside of GRDB and the query interface. Having `strftime` accept a SQLSpecificExpressible date prevents it from polluting the global space. It is *specific* to GRDB:

```swift
strftime("%Y", Date())               // Compiler error
strftime("%Y", Column("date"))       // SQLExpression: STRFTIME('%Y', date)
```

You may want to compare it to another protocol, SQLExpressible, which will be described [below](#add-a-new-kind-of-sqlite-expression), when we add support for CAST SQL expressions.

> :point_up: **Note**: whenever you extend GRDB with a Swift function, method, or operator, you should generally make sure that its signature contains at least one GRDB-specific type. In the `strftime` function, it is the SQLSpecificExpressible protocol.


### GLOB

For the [GLOB](https://www.sqlite.org/lang_expr.html#like) operator, we want to define the glob Swift method:

```swift
// Books that talk about Moby Dick
// SELECT * FROM books WHERE body GLOB '*Moby-Dick*'
Books.filter(Column("body").glob("*Moby-Dick*"))
```

This time we can't use the SQLExpressionFunction type, because it can't generate the SQL for a binary operator. Instead, we'll use another [built-in expression](#built-in-expressions), SQLExpressionBinary:

```swift
struct SQLExpressionBinary : SQLExpression {
    /// Creates an expression made of two expressions joined with a binary operator.
    ///
    ///     // length * width
    ///     SQLExpressionBinary(.multiply, Column("length"), Column("width"))
    init(_ op: SQLBinaryOperator, _ lhs: SQLExpressible, _ rhs: SQLExpressible)
}
```

Now we have to find the signature of our Swift method. The GLOB operator accepts any value on both sides. However, what kind of Swift code should we accept?

```swift
// 1) body GLOB '*Moby-Dick*' -- Yes, of course
Column("body").glob("*Moby-Dick*")
// 2) body GLOB pattern -- Sure, why not?
Column("body").glob(Column("pattern"))
// 3) 'Some Swift String' GLOB pattern - Not sure, but OK
"Some Swift String".glob(Column("pattern"))
// 4) 'Some Swift String' GLOB 'Another Swift String' -- NO
"Some Swift String".glob("Another Swift String")
```

We don't want the form 4, because this is an unacceptable pollution of the Swift global namespace. A good GRDB extension limits its scope to database-related code.

We thus have two overloaded definitions of the `glob` method:

```swift
extension SQLSpecificExpressible {
    func glob(_ pattern: SQLExpressible) -> SQLExpression
}
extension SQLExpressible {
    func glob(_ pattern: SQLSpecificExpressible) -> SQLExpression
}
```

SQLExpressible is the protocol for all types that can be turned into a SQL expression. This includes all expressions, and all [value types](../../../#values) (including String).

SQLSpecificExpressible is a sub protocol of SQLExpressible protocol, restricted to all types that can be turned into a SQL expression, but types like Int, Date, or String that exist outside of GRDB and the query interface.

By extending both, we can define the GLOB operators for any pair that contains at least one type that is specific to GRDB - and leave the global Swift space clean.

The final implementation follows:

```swift
// Add a SQLBinaryOperator just like we add NSNotification.Name since
// the release of Swift 3.
extension SQLBinaryOperator {
    /// The `GLOB` binary operator
    static let glob = SQLBinaryOperator("GLOB")
}

extension SQLSpecificExpressible {
    /// Returns an SQL `GLOB` expression.
    ///
    ///     // body GLOB '*Moby-Dick*'
    ///     Column("body").glob("*Moby-Dick*")
    func glob(_ pattern: SQLExpressible) -> SQLExpression {
        return SQLExpressionBinary(.glob, self, pattern)
    }
}

extension SQLExpressible {
    /// Returns an SQL `GLOB` expression.
    ///
    ///     // 'Some Swift String' GLOB pattern
    ///     "Some Swift String".glob(Column("pattern"))
    func glob(_ pattern: SQLSpecificExpressible) -> SQLExpression {
        return SQLExpressionBinary(.glob, self, pattern)
    }
}
```


### Built-in Expressions

When you extend GRDB with a new function, method, or operator that generates an [SQL expression](https://www.sqlite.org/lang_expr.html), you have to return a value the adopts the SQLExpression protocol.

We have already seen in our [previous](#strftime) [examples](#glob) two concrete types that generate SQL function calls and binary operators: SQLExpressionFunction and SQLExpressionBinary.

This section of the documentation lists all built-in expressions. Adding a custom SQLExpression type will be documented [below](#add-a-new-kind-of-sqlite-expression).


#### Column and DatabaseValue

The [Column](../../../#the-query-interface) type from the query interface, and [DatabaseValue](../../../#databasevalue), the type that wraps the five values supported by SQLite (NULL, Int64, Double, String and Data) are expressions. They are rather trivial, and it is unlikely that you use them in your GRDB extensions.


#### SQLExpressionLiteral

Use SQLExpressionLiteral when you need to go fast:

```swift
struct SQLExpressionLiteral : SQLExpression {
    /// Creates an SQL literal expression.
    ///
    ///     SQLExpressionLiteral("1 + 2")
    ///     SQLExpressionLiteral("? + ?", arguments: [1, 2])
    init(_ sql: String, arguments: StatementArguments? = nil)
}
```

For an example of use, see the [Add a new kind of SQLite expression](#add-a-new-kind-of-sqlite-expression) chapter.


#### SQLExpressionUnary

SQLExpressionUnary builds an expression by prefixing another expression with an unary operator:

```swift
struct SQLExpressionUnary : SQLExpression {
    /// Creates an expression made of an unary operator and
    /// an operand expression.
    ///
    ///     // NOT favorite
    ///     SQLExpressionUnary(.not, Column("favorite"))
    init(_ op: SQLUnaryOperator, _ value: SQLExpressible)
}
```

You add missing SQLite unary operators by extending SQLUnaryOperator:

```swift
extension SQLUnaryOperator {
    /// The `+` unary operator
    static let plus = SQLUnaryOperator("+", needsRightSpace: false)
}
```


#### SQLExpressionBinary

SQLExpressionBinary builds an expression by joining two expressions with a binary operator:

```swift
struct SQLExpressionBinary : SQLExpression {
    /// Creates an expression made of two expressions joined with a binary operator.
    ///
    ///     // length * width
    ///     SQLExpressionBinary(.multiply, Column("length"), Column("width"))
    init(_ op: SQLBinaryOperator, _ lhs: SQLExpressible, _ rhs: SQLExpressible)
}
```

You add missing SQLite binary operators by extending SQLBinaryOperator:

```swift
extension SQLBinaryOperator {
    /// The `GLOB` binary operator
    static let glob = SQLBinaryOperator("GLOB")
}
```


#### SQLExpressionFunction

SQLExpressionFunction builds an SQL function call:

```swift
struct SQLExpressionFunction : SQLExpression {
    /// Creates an SQL function call
    ///
    ///     // ABS(-1)
    ///     SQLExpressionFunction(.abs, arguments: -1)
    init(_ functionName: SQLFunctionName, arguments: SQLExpressible...)
}
```

You add missing SQLite function names by extending SQLFunctionName:

```swift
extension SQLFunctionName {
    /// The `STRFTIME` SQL function
    static let strftime = SQLFunctionName("STRFTIME")
}
```


#### The IN Operator

Build a `value IN (...)` expression from any sequence of [values](../../../#values):

```swift
// SQLExpression: id IN (1, 2, 3)
[1,2,3].contains(Column("id"))

// SQLExpression: id NOT IN (1, 2, 3)
![1,2,3].contains(Column("id"))
```

The most general way to generate an `IN` operator is from any value that adopts the [SQLCollection](http://cocoadocs.org/docsets/GRDB.swift/0.99.0/Protocols/SQLCollection.html) protocol, like the [query interface requests](../../../#requests):

```swift
let request = Person.select(Column("id"))

// SQLExpression: in IN (SELECT id FROM persons)
request.contains(Column("id"))
```


#### The BETWEEN Operator

Build a `value BETWEEN min AND max` expression from Swift ranges:

```swift
// SQLExpression: id BETWEEN 1 AND 10
1...10.contains(Column("id")
```


#### The EXISTS Operator

Build a `EXISTS(...)` expression from any value that adopts the [SQLSelectQuery](http://cocoadocs.org/docsets/GRDB.swift/0.99.0/Protocols/SQLSelectQuery.html) protocol, like the [query interface requests](../../../#requests):

```swift
let request = Person.all()

// SQLExpression: EXISTS(SELECT * FROM persons)
request.exists()
```


#### The COUNT Function

Build a `COUNT(...)` expression from the [count](http://cocoadocs.org/docsets/GRDB.swift/0.99.0/Functions.html) and [count(distinct:)](http://cocoadocs.org/docsets/GRDB.swift/0.99.0/Functions.html) functions:

```swift
// SQLExpression: COUNT(email)
count(Column("email"))

// SQLExpression: COUNT(DISTINCT email)
count(distinct: Column("email"))
```


#### The COLLATE Operator

Build a `expression COLLATE collation` expression with the `collating` method:

```swift
// SQLExpression: name = 'Arthur' COLLATE NOCASE
Column("name").collating(.nocase) == "Arthur"
```


## Add a New Kind of SQLite Expression

GRDB does not have built-in support for the full range of the SQLite [expression grammar](https://www.sqlite.org/lang_expr.html).

For example, [CAST expressions](https://www.sqlite.org/lang_expr.html#castexpr) are not ready-made. They can be useful, though: a CAST expression can efficiently convert json strings to UTF-8 data blobs for you:

```sql
SELECT CAST(jsonString AS BLOB) FROM books
```

We'll add below a Swift `cast` function:

```swift
let request = Books.select(cast(Column("jsonString"), as: .blob))
let jsonDatas = try Data.fetchAll(db, request) // [Data]
```

`cast` is a top-level Swift function because this is how GRDB usually imports SQLite features which do not have matching standard Swift counterpart. It helps the Swift code looking like SQL when it is relevant. But YMMV.

The signature of the `cast` function is:

```swift
func cast(_ value: SQLExpressible, as type: Database.ColumnType) -> SQLExpression
```

Database.ColumnType is a String-based enumeration of all database column types (.integer, .text, .blob, etc.) You have already used if you have [created tables](../../../#create-tables) using the query interface.

The return type SQLExpression is the type returned by all GRDB functions and operators that build [query interface expressions](../../../#expressions).

SQLExpression is a protocol. But GRDB ships with a variety of [built-in expressions](#built-in-expressions) that are ready-made, so that you generally don't have to write your custom expression type. Here we need something new. So we'll use the most versatile of all, SQLExpressionLiteral:

```swift
struct SQLExpressionLiteral : SQLExpression {
    /// Creates an SQL literal expression.
    ///
    ///     SQLExpressionLiteral("1 + 2")
    ///     SQLExpressionLiteral("? + ?", arguments: [1, 2])
    init(_ sql: String, arguments: StatementArguments? = nil)
}
```

Here is the code that defines our `cast` function:


```swift
func cast(_ value: SQLExpressible, as type: Database.ColumnType) -> SQLExpression {
    // Turn the value into a literal expression
    let literal: SQLExpressionLiteral = value.sqlExpression.literal
    
    // Build our "CAST(value AS type)" sql snippet
    let sql = "CAST(\(literal.sql) AS \(type.rawValue))"
    
    // And return a new literal expression, preserving input arguments
    return SQLExpressionLiteral(sql, arguments: literal.arguments)
}
```

We haven't yet described the SQLExpressible type of the `value` argument:

SQLExpressible is the protocol for all types that can be turned into a SQL expression. This includes all [value types](../../../#values) (Bool, Int, String, Date, Swift enums, etc.):

```swift
cast("foo", as: .blob)          // SQLExpression: CAST('foo' AS BLOB)
cast(Column("name"), as: .blob) // SQLExpression: CAST(name AS BLOB)
```

You may want to compare it to another protocol, SQLSpecificExpressible, which has been described [above](#strftime), when we were adding support for the STRFTIME SQL function.

> :point_up: **Note**: whenever you extend GRDB with a Swift function, method, or operator, you should generally make sure that its signature contains at least one GRDB-specific type. In the `cast` function, it is Database.ColumnType.

**If SQLExpressionLiteral reveals too limited for your purpose**, you may have to implement a new type that adopts the [SQLExpression](http://cocoadocs.org/docsets/GRDB.swift/0.99.0/Protocols/SQLExpression.html) protocol.
