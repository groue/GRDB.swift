#if GRDBCUSTOMSQLITE || GRDBCIPHER
extension Database {
    /// Validates and minifies a JSON string, with the `JSON` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON(' { "a": [ "test" ] } ') → '{"a":["test"]}'
    /// Database.json(#" { "a": [ "test" ] } "#)
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jmini>
    public static func json(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON", [value.sqlExpression])
    }
    
    /// Creates a JSON array with the `JSON_ARRAY` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_ARRAY(1, 2, 3, 4) → '[1,2,3,4]'
    /// Database.jsonArray(1...4)
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jarray>
    public static func jsonArray<C>(_ values: C) -> SQLExpression
    where C: Collection, C.Element: SQLExpressible
    {
        .function("JSON_ARRAY", values.map(\.sqlExpression.jsonBuilderExpression))
    }
    
    /// Creates a JSON array with the `JSON_ARRAY` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_ARRAY(1, 2, '3', 4) → '[1,2,"3",4]'
    /// Database.jsonArray([1, 2, "3", 4])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jarray>
    public static func jsonArray<C>(_ values: C) -> SQLExpression
    where C: Collection, C.Element == any SQLExpressible
    {
        .function("JSON_ARRAY", values.map(\.sqlExpression.jsonBuilderExpression))
    }
    
    /// The number of elements in a JSON array, as returned by the
    /// `JSON_ARRAY_LENGTH` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_ARRAY_LENGTH('[1,2,3,4]') → 4
    /// Database.jsonArrayLength("[1,2,3,4]")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jarraylen>
    public static func jsonArrayLength(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON_ARRAY_LENGTH", [value.sqlExpression])
    }
    
    /// The number of elements in a JSON array, as returned by the
    /// `JSON_ARRAY_LENGTH` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_ARRAY_LENGTH('{"one":[1,2,3]}', '$.one') → 3
    /// Database.jsonArrayLength(#"{"one":[1,2,3]}"#, atPath: "$.one")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jarraylen>
    ///
    /// - Parameters:
    ///   - value: A JSON array.
    ///   - path: A [JSON path](https://www.sqlite.org/json1.html#path_arguments).
    public static func jsonArrayLength(
        _ value: some SQLExpressible,
        atPath path: some SQLExpressible)
    -> SQLExpression
    {
        .function("JSON_ARRAY_LENGTH", [value.sqlExpression, path.sqlExpression])
    }
    
    /// The `JSON_ERROR_POSITION` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_ERROR_POSITION(info)
    /// Database.jsonErrorPosition(Column("info"))
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jerr>
    public static func jsonErrorPosition(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON_ERROR_POSITION", [value.sqlExpression])
    }
    
    /// The `JSON_EXTRACT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_EXTRACT('{"a":123}', '$.a') → 123
    /// Database.jsonExtract(#"{"a":123}"#, atPath: "$.a")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jex>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - path: A [JSON path](https://www.sqlite.org/json1.html#path_arguments).
    public static func jsonExtract(_ value: some SQLExpressible, atPath path: some SQLExpressible) -> SQLExpression {
        .function("JSON_EXTRACT", [value.sqlExpression, path.sqlExpression])
    }
    
    /// The `JSON_EXTRACT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_EXTRACT('{"a":2,"c":[4,5]}','$.c','$.a') → '[[4,5],2]'
    /// Database.jsonExtract(#"{"a":2,"c":[4,5]}"#, atPaths: ["$.c", "$.a"])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jex>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - paths: A collection of [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    public static func jsonExtract<C>(_ value: some SQLExpressible, atPaths paths: C)
    -> SQLExpression
    where C: Collection, C.Element: SQLExpressible
    {
        .function("JSON_EXTRACT", [value.sqlExpression] + paths.map(\.sqlExpression))
    }
    
    /// The `JSON_INSERT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_INSERT('[1,2,3,4]','$[#]',99) → '[1,2,3,4,99]'
    /// Database.jsonInsert("[1,2,3,4]", ["$[#]": value: 99])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jins>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - assignments: A collection of key/value pairs, where keys are
    ///     [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    public static func jsonInsert<C>(
        _ value: some SQLExpressible,
        _ assignments: C)
    -> SQLExpression
    where C: Collection,
          C.Element == (key: String, value: any SQLExpressible)
    {
        .function("JSON_INSERT", [value.sqlExpression] + assignments.flatMap {
            [$0.key.sqlExpression, $0.value.sqlExpression.jsonBuilderExpression]
        })
    }
    
    /// The `JSON_REPLACE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_REPLACE('{"a":2,"c":4}', '$.a', 99) → '{"a":99,"c":4}'
    /// Database.jsonReplace(#"{"a":2,"c":4}"#, ["$.a": 99])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jins>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - assignments: A collection of key/value pairs, where keys are
    ///     [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    public static func jsonReplace<C>(
        _ value: some SQLExpressible,
        _ assignments: C)
    -> SQLExpression
    where C: Collection,
          C.Element == (key: String, value: any SQLExpressible)
    {
        .function("JSON_REPLACE", [value.sqlExpression] + assignments.flatMap {
            [$0.key.sqlExpression, $0.value.sqlExpression.jsonBuilderExpression]
        })
    }
    
    /// The `JSON_SET` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_SET('{"a":2,"c":4}', '$.a', 99) → '{"a":99,"c":4}'
    /// Database.jsonSet(#"{"a":2,"c":4}"#, ["$.a": 99]])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jins>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - assignments: A collection of key/value pairs, where keys are
    ///     [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    public static func jsonSet<C>(
        _ value: some SQLExpressible,
        _ assignments: C)
    -> SQLExpression
    where C: Collection,
          C.Element == (key: String, value: any SQLExpressible)
    {
        .function("JSON_SET", [value.sqlExpression] + assignments.flatMap {
            [$0.key.sqlExpression, $0.value.sqlExpression.jsonBuilderExpression]
        })
    }
    
    /// Creates a JSON object with the `JSON_OBJECT` SQL function. Pass
    /// key/value pairs with a Swift collection such as a `Dictionary`.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_OBJECT('c', '{"e":5}') → '{"c":"{\"e\":5}"}'
    /// Database.jsonObject([
    ///     "c": #"{"e":5}"#,
    /// ])
    ///
    /// // JSON_OBJECT('c', JSON_OBJECT('e', 5)) → '{"c":{"e":5}}'
    /// Database.jsonObject([
    ///     "c": Database.jsonObject(["e": 5])),
    /// ])
    ///
    /// // JSON_OBJECT('c', JSON('{"e":5}')) → '{"c":{"e":5}}'
    /// Database.jsonObject([
    ///     "c": Database.json(#"{"e":5}"#),
    /// ])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jobj>
    public static func jsonObject<C>(_ elements: C)
    -> SQLExpression
    where C: Collection,
          C.Element == (key: String, value: any SQLExpressible)
    {
        .function("JSON_OBJECT", elements.flatMap {
            [$0.key.sqlExpression, $0.value.sqlExpression.jsonBuilderExpression]
        })
    }
    
    /// The `JSON_PATCH` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_PATCH('{"a":1,"b":2}','{"c":3,"d":4}') → '{"a":1,"b":2,"c":3,"d":4}'
    /// Database.jsonPatch(#"{"a":1,"b":2}"#, #"{"c":3,"d":4}"#)
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jpatch>
    public static func jsonPatch(
        _ value: some SQLExpressible,
        with patch: some SQLExpressible)
    -> SQLExpression
    {
        .function("JSON_PATCH", [value.sqlExpression, patch.sqlExpression])
    }
    
    /// The `JSON_REMOVE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_REMOVE('[0,1,2,3,4]', '$[2]') → '[0,1,3,4]'
    /// Database.jsonRemove("[0,1,2,3,4]", atPath: "$[2]")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jrm>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - paths: A [JSON path](https://www.sqlite.org/json1.html#path_arguments).
    public static func jsonRemove(_ value: some SQLExpressible, atPath path: some SQLExpressible) -> SQLExpression {
        .function("JSON_REMOVE", [value.sqlExpression, path.sqlExpression])
    }
    
    /// The `JSON_REMOVE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_REMOVE('[0,1,2,3,4]', '$[2]','$[0]') → '[1,3,4]'
    /// Database.jsonRemove("[0,1,2,3,4]", atPaths: ["$[2]", "$[0]"])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jrm>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - paths: A collection of [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    public static func jsonRemove<C>(_ value: some SQLExpressible, atPaths paths: C)
    -> SQLExpression
    where C: Collection, C.Element: SQLExpressible
    {
        .function("JSON_REMOVE", [value.sqlExpression] + paths.map(\.sqlExpression))
    }
    
    /// The `JSON_TYPE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_TYPE('{"a":[2,3.5,true,false,null,"x"]}') → 'object'
    /// Database.jsonType(#"{"a":[2,3.5,true,false,null,"x"]}"#)
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jtype>
    public static func jsonType(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON_TYPE", [value.sqlExpression])
    }
    
    /// The `JSON_TYPE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_TYPE('{"a":[2,3.5,true,false,null,"x"]}', '$.a') → 'object'
    /// Database.jsonType(#"{"a":[2,3.5,true,false,null,"x"]}"#, atPath: "$.a")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jtype>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - paths: A [JSON path](https://www.sqlite.org/json1.html#path_arguments).
    public static func jsonType(_ value: some SQLExpressible, atPath path: some SQLExpressible) -> SQLExpression {
        .function("JSON_TYPE", [value.sqlExpression, path.sqlExpression])
    }
    
    /// The `JSON_VALID` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_VALID('{"x":35') → 0
    /// Database.jsonIsValid(#"{"x":35"#)
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jvalid>
    public static func jsonIsValid(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON_VALID", [value.sqlExpression])
    }
    
    /// The `JSON_QUOTE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_QUOTE('[1]') → '"[1]"'
    /// Database.jsonQuote("[1]")
    ///
    /// // JSON_QUOTE(JSON('[1]')) → '[1]'
    /// Database.jsonQuote(Database.json("[1]"))
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jquote>
    public static func jsonQuote(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON_QUOTE", [value.sqlExpression.jsonBuilderExpression])
    }
    
    /// The `JSON_GROUP_ARRAY` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT JSON_GROUP_ARRAY(name) FROM player
    /// Player.select(Database.jsonGroupArray(Column("name")))
    ///
    /// // SELECT JSON_GROUP_ARRAY(name) FILTER (WHERE score > 0) FROM player
    /// Player.select(Database.jsonGroupArray(Column("name"), filter: Column("score") > 0))
    ///
    /// // SELECT JSON_GROUP_ARRAY(name ORDER BY name) FROM player
    /// Player.select(Database.jsonGroupArray(Column("name"), orderBy: Column("name")))
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jgrouparray>
    public static func jsonGroupArray(
        _ value: some SQLExpressible,
        orderBy ordering: (any SQLOrderingTerm)? = nil,
        filter: (any SQLSpecificExpressible)? = nil)
    -> SQLExpression {
        .aggregateFunction(
            "JSON_GROUP_ARRAY",
            [value.sqlExpression.jsonBuilderExpression],
            ordering: ordering?.sqlOrdering,
            filter: filter?.sqlExpression,
            isJSONValue: true)
    }
    
    /// The `JSON_GROUP_OBJECT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT JSON_GROUP_OBJECT(name, score) FROM player
    /// Player.select(Database.jsonGroupObject(
    ///     key: Column("name"),
    ///     value: Column("score")))
    ///
    /// // SELECT JSON_GROUP_OBJECT(name, score) FILTER (WHERE score > 0) FROM player
    /// Player.select(Database.jsonGroupObject(
    ///     key: Column("name"),
    ///     value: Column("score"),
    ///     filter: Column("score") > 0))
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jgrouparray>
    public static func jsonGroupObject(
        key: some SQLExpressible,
        value: some SQLExpressible,
        filter: (any SQLSpecificExpressible)? = nil
    ) -> SQLExpression {
        .aggregateFunction(
            "JSON_GROUP_OBJECT",
            [key.sqlExpression, value.sqlExpression.jsonBuilderExpression],
            filter: filter?.sqlExpression,
            isJSONValue: true)
    }
}
#else
extension Database {
    /// Validates and minifies a JSON string, with the `JSON` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON(' { "a": [ "test" ] } ') → '{"a":["test"]}'
    /// Database.json(#" { "a": [ "test" ] } "#)
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jmini>
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func json(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON", [value.sqlExpression])
    }
    
    /// Creates a JSON array with the `JSON_ARRAY` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_ARRAY(1, 2, 3, 4) → '[1,2,3,4]'
    /// Database.jsonArray(1...4)
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jarray>
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonArray<C>(_ values: C) -> SQLExpression
    where C: Collection, C.Element: SQLExpressible
    {
        .function("JSON_ARRAY", values.map(\.sqlExpression.jsonBuilderExpression))
    }
    
    /// Creates a JSON array with the `JSON_ARRAY` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_ARRAY(1, 2, '3', 4) → '[1,2,"3",4]'
    /// Database.jsonArray([1, 2, "3", 4])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jarray>
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonArray<C>(_ values: C) -> SQLExpression
    where C: Collection, C.Element == any SQLExpressible
    {
        .function("JSON_ARRAY", values.map(\.sqlExpression.jsonBuilderExpression))
    }
    
    /// The number of elements in a JSON array, as returned by the
    /// `JSON_ARRAY_LENGTH` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_ARRAY_LENGTH('[1,2,3,4]') → 4
    /// Database.jsonArrayLength("[1,2,3,4]")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jarraylen>
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonArrayLength(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON_ARRAY_LENGTH", [value.sqlExpression])
    }
    
    /// The number of elements in a JSON array, as returned by the
    /// `JSON_ARRAY_LENGTH` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_ARRAY_LENGTH('{"one":[1,2,3]}', '$.one') → 3
    /// Database.jsonArrayLength(#"{"one":[1,2,3]}"#, atPath: "$.one")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jarraylen>
    ///
    /// - Parameters:
    ///   - value: A JSON array.
    ///   - path: A [JSON path](https://www.sqlite.org/json1.html#path_arguments).
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonArrayLength(
        _ value: some SQLExpressible,
        atPath path: some SQLExpressible)
    -> SQLExpression
    {
        .function("JSON_ARRAY_LENGTH", [value.sqlExpression, path.sqlExpression])
    }
    
    /// The `JSON_ERROR_POSITION` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_ERROR_POSITION(info)
    /// Database.jsonErrorPosition(Column("info"))
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jerr>
    @available(iOS 9999, macOS 9999, tvOS 9999, watchOS 9999, *)
    public static func jsonErrorPosition(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON_ERROR_POSITION", [value.sqlExpression])
    }
    
    /// The `JSON_EXTRACT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_EXTRACT('{"a":123}', '$.a') → 123
    /// Database.jsonExtract(#"{"a":123}"#, atPath: "$.a")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jex>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - path: A [JSON path](https://www.sqlite.org/json1.html#path_arguments).
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonExtract(_ value: some SQLExpressible, atPath path: some SQLExpressible) -> SQLExpression {
        .function("JSON_EXTRACT", [value.sqlExpression, path.sqlExpression])
    }
    
    /// The `JSON_EXTRACT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_EXTRACT('{"a":2,"c":[4,5]}','$.c','$.a') → '[[4,5],2]'
    /// Database.jsonExtract(#"{"a":2,"c":[4,5]}"#, atPaths: ["$.c", "$.a"])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jex>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - paths: A collection of [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonExtract<C>(_ value: some SQLExpressible, atPaths paths: C)
    -> SQLExpression
    where C: Collection, C.Element: SQLExpressible
    {
        .function("JSON_EXTRACT", [value.sqlExpression] + paths.map(\.sqlExpression))
    }
    
    /// The `JSON_INSERT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_INSERT('[1,2,3,4]','$[#]',99) → '[1,2,3,4,99]'
    /// Database.jsonInsert("[1,2,3,4]", ["$[#]": value: 99])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jins>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - assignments: A collection of key/value pairs, where keys are
    ///     [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonInsert<C>(
        _ value: some SQLExpressible,
        _ assignments: C)
    -> SQLExpression
    where C: Collection,
          C.Element == (key: String, value: any SQLExpressible)
    {
        .function("JSON_INSERT", [value.sqlExpression] + assignments.flatMap {
            [$0.key.sqlExpression, $0.value.sqlExpression.jsonBuilderExpression]
        })
    }
    
    /// The `JSON_REPLACE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_REPLACE('{"a":2,"c":4}', '$.a', 99) → '{"a":99,"c":4}'
    /// Database.jsonReplace(#"{"a":2,"c":4}"#, ["$.a": 99])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jins>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - assignments: A collection of key/value pairs, where keys are
    ///     [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonReplace<C>(
        _ value: some SQLExpressible,
        _ assignments: C)
    -> SQLExpression
    where C: Collection,
          C.Element == (key: String, value: any SQLExpressible)
    {
        .function("JSON_REPLACE", [value.sqlExpression] + assignments.flatMap {
            [$0.key.sqlExpression, $0.value.sqlExpression.jsonBuilderExpression]
        })
    }
    
    /// The `JSON_SET` SQL function.
    /// 
    /// For example:
    /// 
    /// ```swift
    /// // JSON_SET('{"a":2,"c":4}', '$.a', 99) → '{"a":99,"c":4}'
    /// Database.jsonSet(#"{"a":2,"c":4}"#, ["$.a": 99]])
    /// ```
    /// 
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jins>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - assignments: A collection of key/value pairs, where keys are
    ///     [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonSet<C>(
        _ value: some SQLExpressible,
        _ assignments: C)
    -> SQLExpression
    where C: Collection,
          C.Element == (key: String, value: any SQLExpressible)
    {
        .function("JSON_SET", [value.sqlExpression] + assignments.flatMap {
            [$0.key.sqlExpression, $0.value.sqlExpression.jsonBuilderExpression]
        })
    }
    
    /// Creates a JSON object with the `JSON_OBJECT` SQL function. Pass
    /// key/value pairs with a Swift collection such as a `Dictionary`.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_OBJECT('c', '{"e":5}') → '{"c":"{\"e\":5}"}'
    /// Database.jsonObject([
    ///     "c": #"{"e":5}"#,
    /// ])
    ///
    /// // JSON_OBJECT('c', JSON_OBJECT('e', 5)) → '{"c":{"e":5}}'
    /// Database.jsonObject([
    ///     "c": Database.jsonObject(["e": 5])),
    /// ])
    ///
    /// // JSON_OBJECT('c', JSON('{"e":5}')) → '{"c":{"e":5}}'
    /// Database.jsonObject([
    ///     "c": Database.json(#"{"e":5}"#),
    /// ])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jobj>
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonObject<C>(_ elements: C)
    -> SQLExpression
    where C: Collection,
          C.Element == (key: String, value: any SQLExpressible)
    {
        .function("JSON_OBJECT", elements.flatMap {
            [$0.key.sqlExpression, $0.value.sqlExpression.jsonBuilderExpression]
        })
    }
    
    /// The `JSON_PATCH` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_PATCH('{"a":1,"b":2}','{"c":3,"d":4}') → '{"a":1,"b":2,"c":3,"d":4}'
    /// Database.jsonPatch(#"{"a":1,"b":2}"#, #"{"c":3,"d":4}"#)
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jpatch>
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonPatch(
        _ value: some SQLExpressible,
        with patch: some SQLExpressible)
    -> SQLExpression
    {
        .function("JSON_PATCH", [value.sqlExpression, patch.sqlExpression])
    }
    
    /// The `JSON_REMOVE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_REMOVE('[0,1,2,3,4]', '$[2]') → '[0,1,3,4]'
    /// Database.jsonRemove("[0,1,2,3,4]", atPath: "$[2]")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jrm>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - paths: A [JSON path](https://www.sqlite.org/json1.html#path_arguments).
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonRemove(_ value: some SQLExpressible, atPath path: some SQLExpressible) -> SQLExpression {
        .function("JSON_REMOVE", [value.sqlExpression, path.sqlExpression])
    }
    
    /// The `JSON_REMOVE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_REMOVE('[0,1,2,3,4]', '$[2]','$[0]') → '[1,3,4]'
    /// Database.jsonRemove("[0,1,2,3,4]", atPaths: ["$[2]", "$[0]"])
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jrm>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - paths: A collection of [JSON paths](https://www.sqlite.org/json1.html#path_arguments).
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonRemove<C>(_ value: some SQLExpressible, atPaths paths: C)
    -> SQLExpression
    where C: Collection, C.Element: SQLExpressible
    {
        .function("JSON_REMOVE", [value.sqlExpression] + paths.map(\.sqlExpression))
    }
    
    /// The `JSON_TYPE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_TYPE('{"a":[2,3.5,true,false,null,"x"]}') → 'object'
    /// Database.jsonType(#"{"a":[2,3.5,true,false,null,"x"]}"#)
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jtype>
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonType(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON_TYPE", [value.sqlExpression])
    }
    
    /// The `JSON_TYPE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_TYPE('{"a":[2,3.5,true,false,null,"x"]}', '$.a') → 'object'
    /// Database.jsonType(#"{"a":[2,3.5,true,false,null,"x"]}"#, atPath: "$.a")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jtype>
    ///
    /// - Parameters:
    ///   - value: A JSON value.
    ///   - paths: A [JSON path](https://www.sqlite.org/json1.html#path_arguments).
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonType(_ value: some SQLExpressible, atPath path: some SQLExpressible) -> SQLExpression {
        .function("JSON_TYPE", [value.sqlExpression, path.sqlExpression])
    }
    
    /// The `JSON_VALID` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_VALID('{"x":35') → 0
    /// Database.jsonIsValid(#"{"x":35"#)
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jvalid>
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonIsValid(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON_VALID", [value.sqlExpression])
    }
    
    /// Returns a valid JSON string with the `JSON_QUOTE` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // JSON_QUOTE('[1]') → '"[1]"'
    /// Database.jsonQuote("[1]")
    ///
    /// // JSON_QUOTE(JSON('[1]')) → '[1]'
    /// Database.jsonQuote(Database.json("[1]"))
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jquote>
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonQuote(_ value: some SQLExpressible) -> SQLExpression {
        .function("JSON_QUOTE", [value.sqlExpression.jsonBuilderExpression])
    }
    
    /// The `JSON_GROUP_ARRAY` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT JSON_GROUP_ARRAY(name) FROM player
    /// Player.select(Database.jsonGroupArray(Column("name")))
    ///
    /// // SELECT JSON_GROUP_ARRAY(name) FILTER (WHERE score > 0) FROM player
    /// Player.select(Database.jsonGroupArray(Column("name"), filter: Column("score") > 0))
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jgrouparray>
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonGroupArray(
        _ value: some SQLExpressible,
        filter: (any SQLSpecificExpressible)? = nil)
    -> SQLExpression {
        .aggregateFunction(
            "JSON_GROUP_ARRAY",
            [value.sqlExpression.jsonBuilderExpression],
            filter: filter?.sqlExpression,
            isJSONValue: true)
    }
    
    /// The `JSON_GROUP_OBJECT` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT JSON_GROUP_OBJECT(name, score) FROM player
    /// Player.select(Database.jsonGroupObject(
    ///     key: Column("name"),
    ///     value: Column("score")))
    ///
    /// // SELECT JSON_GROUP_OBJECT(name, score) FILTER (WHERE score > 0) FROM player
    /// Player.select(Database.jsonGroupObject(
    ///     key: Column("name"),
    ///     value: Column("score"),
    ///     filter: Column("score") > 0))
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/json1.html#jgrouparray>
    @available(iOS 16, macOS 10.15, tvOS 17, watchOS 9, *) // SQLite 3.38+ with exceptions for macOS
    public static func jsonGroupObject(
        key: some SQLExpressible,
        value: some SQLExpressible,
        filter: (any SQLSpecificExpressible)? = nil
    ) -> SQLExpression {
        .aggregateFunction(
            "JSON_GROUP_OBJECT",
            [key.sqlExpression, value.sqlExpression.jsonBuilderExpression],
            filter: filter?.sqlExpression,
            isJSONValue: true)
    }
}
#endif
