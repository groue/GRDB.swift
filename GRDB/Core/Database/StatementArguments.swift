/// An instance of `StatementArguments` provides the values for argument
/// placeholders in a prepared `Statement`.
///
/// Argument placeholders can take several forms in SQL queries (see
/// <https://www.sqlite.org/lang_expr.html#varparam> for more information):
///
/// - `?NNN` (e.g. `?2`): the NNN-th argument (starts at 1)
/// - `?`: the N-th argument, where N is one greater than the largest argument
///    number already assigned
/// - `:AAAA` (e.g. `:name`): named argument
/// - `@AAAA` (e.g. `@name`): named argument
/// - `$AAAA` (e.g. `$name`): named argument
///
/// All forms are supported,  but GRDB does not allow to distinguish between
/// the `:AAAA`, `@AAAA`, and `$AAAA` syntaxes. You are encouraged to write
/// named arguments with a colon prefix: `:name`.
///
/// ## Positional Arguments
///
/// To fill question marks placeholders, feed `StatementArguments` with an array:
///
/// ```swift
/// try db.execute(
///     sql: "INSERT INTO player (name, score) VALUES (?, ?)",
///     arguments: StatementArguments(["Arthur", 41]))
///
/// // Array literals are automatically converted:
/// try db.execute(
///     sql: "INSERT INTO player (name, score) VALUES (?, ?)",
///     arguments: ["Arthur", 41])
/// ```
///
/// ## Named Arguments
///
/// To fill named arguments, feed `StatementArguments` with a dictionary:
///
/// ```swift
/// try db.execute(
///     sql: "INSERT INTO player (name, score) VALUES (:name, :score)",
///     arguments: StatementArguments(["name": "Arthur", "score": 41]))
///
/// // Dictionary literals are automatically converted:
/// try db.execute(
///     sql: "INSERT INTO player (name, score) VALUES (:name, :score)",
///     arguments: ["name": "Arthur", "score": 41])
/// ```
///
/// ## Concatenating Arguments
///
/// Several arguments can be concatenated and mixed with the
/// ``append(contentsOf:)`` method and the `+`, `&+`, `+=` operators:
///
/// ```swift
/// var arguments: StatementArguments = ["Arthur"]
/// arguments += [41]
/// try db.execute(
///     sql: "INSERT INTO player (name, score) VALUES (?, ?)",
///     arguments: arguments)
/// ```
///
/// The `+` and `+=` operators consider that overriding named arguments is a
/// programmer error:
///
/// ```swift
/// var arguments: StatementArguments = ["name": "Arthur"]
///
/// // fatal error: already defined statement argument: name
/// arguments += ["name": "Barbara"]
/// ```
///
/// On the other side, `&+` and ``append(contentsOf:)`` allow overriding
/// named arguments:
///
/// ```swift
/// var arguments: StatementArguments = ["name": "Arthur"]
/// arguments = arguments &+ ["name": "Barbara"]
///
/// // Prints ["name": "Barbara"]
/// print(arguments)
/// ```
///
/// ## Mixed Arguments
///
/// It is possible to mix named and positional arguments. Yet this is usually
/// confusing, and it is best to avoid this practice:
///
/// ```swift
/// let sql = "SELECT ?2 AS two, :foo AS foo, ?1 AS one, :foo AS foo2, :bar AS bar"
/// var arguments: StatementArguments = [1, 2, "bar"] + ["foo": "foo"]
/// let row = try Row.fetchOne(db, sql: sql, arguments: arguments)!
///
/// // Prints [two:2 foo:"foo" one:1 foo2:"foo" bar:"bar"]
/// print(row)
/// ```
///
/// Mixed arguments exist as a support for requests like the following:
///
/// ```swift
/// let players = try Player
///     .filter(sql: "team = :team", arguments: ["team": "Blue"])
///     .filter(sql: "score > ?", arguments: [1000])
///     .fetchAll(db)
/// ```
public struct StatementArguments: Hashable {
    private(set) var values: [DatabaseValue]
    private(set) var namedValues: [String: DatabaseValue]
    
    public var isEmpty: Bool {
        values.isEmpty && namedValues.isEmpty
    }
    
    
    // MARK: Empty Arguments
    
    /// Creates an empty `StatementArguments`.
    public init() {
        values = .init()
        namedValues = .init()
    }
    
    // MARK: Positional Arguments
    
    /// Creates a `StatementArguments` from a sequence of values.
    ///
    /// For example:
    ///
    /// ```swift
    /// let values: [(any DatabaseValueConvertible)?] = ["foo", 1, nil]
    /// db.execute(sql: "INSERT ... (?,?,?)", arguments: StatementArguments(values))
    /// ```
    public init<S>(_ sequence: S)
    where S: Sequence, S.Element == (any DatabaseValueConvertible)?
    {
        values = sequence.map { $0?.databaseValue ?? .null }
        namedValues = .init()
    }
    
    /// Creates a `StatementArguments` from a sequence of values.
    ///
    /// For example:
    ///
    /// ```swift
    /// let values: [String] = ["foo", "bar"]
    /// db.execute(sql: "INSERT ... (?,?)", arguments: StatementArguments(values))
    /// ```
    public init<S>(_ sequence: S)
    where S: Sequence, S.Element: DatabaseValueConvertible
    {
        values = sequence.map(\.databaseValue)
        namedValues = .init()
    }
    
    /// Creates a `StatementArguments` from an array.
    ///
    /// The result is nil unless all array elements conform to the
    /// ``DatabaseValueConvertible`` protocol.
    public init?(_ array: [Any]) {
        var values = [(any DatabaseValueConvertible)?]()
        for value in array {
            guard let dbValue = DatabaseValue(value: value) else {
                return nil
            }
            values.append(dbValue)
        }
        self.init(values)
    }
    
    private mutating func set(databaseValues: [DatabaseValue]) {
        self.values = databaseValues
        namedValues.removeAll(keepingCapacity: true)
    }
    
    // MARK: Named Arguments
    
    /// Creates a `StatementArguments` of named arguments from a dictionary.
    ///
    /// For example:
    ///
    /// ```swift
    /// let values: [String: (any DatabaseValueConvertible)?] = ["firstName": nil, "lastName": "Miller"]
    /// db.execute(sql: "INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
    /// ```
    public init(_ dictionary: [String: (any DatabaseValueConvertible)?]) {
        namedValues = dictionary.mapValues { $0?.databaseValue ?? .null }
        values = .init()
    }
    
    /// Creates a `StatementArguments` of named arguments from a sequence of
    /// (key, value) pairs.
    public init<S>(_ sequence: S)
    where S: Sequence, S.Element == (String, (any DatabaseValueConvertible)?)
    {
        namedValues = .init(minimumCapacity: sequence.underestimatedCount)
        for (key, value) in sequence {
            namedValues[key] = value?.databaseValue ?? .null
        }
        values = .init()
    }
    
    /// Creates a `StatementArguments` from a dictionary.
    ///
    /// The result is nil unless all dictionary keys are strings, and values
    /// adopt DatabaseValueConvertible.
    ///
    /// - parameter dictionary: A dictionary.
    public init?(_ dictionary: [AnyHashable: Any]) {
        var initDictionary = [String: (any DatabaseValueConvertible)?]()
        for (key, value) in dictionary {
            guard let columnName = key as? String else {
                return nil
            }
            guard let dbValue = DatabaseValue(value: value) else {
                return nil
            }
            initDictionary[columnName] = dbValue
        }
        self.init(initDictionary)
    }
    
    
    // MARK: Adding arguments
    
    /// Appends statement arguments.
    ///
    /// Positional arguments are concatenated:
    ///
    /// ```swift
    /// var arguments: StatementArguments = [1]
    /// arguments.append(contentsOf: [2, 3])
    ///
    /// // Prints [1, 2, 3]
    /// print(arguments)
    /// ```
    ///
    /// Named arguments are inserted or updated:
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1]
    /// arguments.append(contentsOf: ["bar": 2])
    ///
    /// // Prints ["foo": 1, "bar": 2]
    /// print(arguments)
    /// ```
    ///
    /// Named arguments that were replaced, if any, are returned:
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1, "bar": 2]
    /// let replacedValues = arguments.append(contentsOf: ["foo": 3])
    ///
    /// // Prints ["foo": 3, "bar": 2]
    /// print(arguments)
    ///
    /// // Prints ["foo": 1]
    /// print(replacedValues)
    /// ```
    ///
    /// You can mix named and positional arguments (see the documentation of
    /// the ``StatementArguments`` type for more information about
    /// mixed arguments):
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1]
    /// arguments.append(contentsOf: [2, 3])
    ///
    /// // Prints ["foo": 1, 2, 3]
    /// print(arguments)
    /// ```
    public mutating func append(contentsOf arguments: StatementArguments) -> [String: DatabaseValue] {
        var replacedValues: [String: DatabaseValue] = [:]
        values.append(contentsOf: arguments.values)
        for (name, value) in arguments.namedValues {
            if let replacedValue = namedValues.updateValue(value, forKey: name) {
                replacedValues[name] = replacedValue
            }
        }
        return replacedValues
    }
    
    /// Creates a new `StatementArguments` by extending the left-hand size
    /// arguments with the right-hand side arguments.
    ///
    /// Positional arguments are concatenated:
    ///
    /// ```swift
    /// let arguments: StatementArguments = [1] + [2, 3]
    ///
    /// // Prints [1, 2, 3]
    /// print(arguments)
    /// ```
    ///
    /// Named arguments are inserted:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] + ["bar": 2]
    ///
    /// // Prints ["foo": 1, "bar": 2]
    /// print(arguments)
    /// ```
    ///
    /// If the arguments on the right-hand side has named parameters that are
    /// already defined on the left, a fatal error is raised:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] + ["foo": 2]
    /// // fatal error: already defined statement argument: foo
    /// ```
    ///
    /// This fatal error can be avoided with the &+ operator, or the
    /// ``append(contentsOf:)`` method.
    ///
    /// You can mix named and positional arguments (see the documentation of
    /// the ``StatementArguments`` type for more information about
    /// mixed arguments):
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] + [2, 3]
    ///
    /// // Prints ["foo": 1, 2, 3]
    /// print(arguments)
    /// ```
    public static func + (lhs: StatementArguments, rhs: StatementArguments) -> StatementArguments {
        var lhs = lhs
        lhs += rhs
        return lhs
    }
    
    /// Creates a new `StatementArguments` by extending the left-hand size
    /// arguments with the right-hand side arguments.
    ///
    /// Positional arguments are concatenated:
    ///
    /// ```swift
    /// let arguments: StatementArguments = [1] &+ [2, 3]
    ///
    /// // Prints [1, 2, 3]
    /// print(arguments)
    /// ```
    ///
    /// Named arguments are inserted or updated:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] &+ ["bar": 2]
    ///
    /// // Prints ["foo": 1, "bar": 2]
    /// print(arguments)
    /// ```
    ///
    /// If a named arguments is defined in both arguments, the right-hand
    /// side wins:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] &+ ["foo": 2]
    ///
    /// // Prints ["foo": 2]
    /// print(arguments)
    /// ```
    ///
    /// You can mix named and positional arguments (see the documentation of
    /// the ``StatementArguments`` type for more information about
    /// mixed arguments):
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["foo": 1] &+ [2, 3]
    /// // Prints ["foo": 1, 2, 3]
    /// print(arguments)
    /// ```
    public static func &+ (lhs: StatementArguments, rhs: StatementArguments) -> StatementArguments {
        var lhs = lhs
        _ = lhs.append(contentsOf: rhs)
        return lhs
    }
    
    /// Extends the left-hand size arguments with the right-hand side arguments.
    ///
    /// Positional arguments are concatenated:
    ///
    /// ```swift
    /// var arguments: StatementArguments = [1]
    /// arguments += [2, 3]
    ///
    /// // Prints [1, 2, 3]
    /// print(arguments)
    /// ```
    ///
    /// Named arguments are inserted:
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1]
    /// arguments += ["bar": 2]
    ///
    /// // Prints ["foo": 1, "bar": 2]
    /// print(arguments)
    /// ```
    ///
    /// If the arguments on the right-hand side has named parameters that are
    /// already defined on the left, a fatal error is raised:
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1]
    ///
    /// // fatal error: already defined statement argument: foo
    /// arguments += ["foo": 2]
    /// ```
    ///
    /// This fatal error can be avoided with the &+ operator, or the
    /// ``append(contentsOf:)`` method.
    ///
    /// You can mix named and positional arguments (see the documentation of
    /// the ``StatementArguments`` type for more information about
    /// mixed arguments):
    ///
    /// ```swift
    /// var arguments: StatementArguments = ["foo": 1]
    /// arguments.append(contentsOf: [2, 3])
    ///
    /// // Prints ["foo": 1, 2, 3]
    /// print(arguments)
    /// ```
    public static func += (lhs: inout StatementArguments, rhs: StatementArguments) {
        let replacedValues = lhs.append(contentsOf: rhs)
        GRDBPrecondition(
            replacedValues.isEmpty,
            "already defined statement argument: \(replacedValues.keys.joined(separator: ", "))")
    }
    
    
    // MARK: Not Public
    
    mutating func extractBindings(
        forStatement statement: Statement,
        allowingRemainingValues: Bool)
    throws -> [DatabaseValue]
    {
        var iterator = values.makeIterator()
        var consumedValuesCount = 0
        let bindings = try statement.sqliteArgumentNames.map { argumentName -> DatabaseValue in
            if let argumentName {
                if let dbValue = namedValues[argumentName] {
                    return dbValue
                } else if let value = iterator.next() {
                    consumedValuesCount += 1
                    return value
                } else {
                    throw DatabaseError(
                        resultCode: .SQLITE_MISUSE,
                        message: "missing statement argument: \(argumentName)",
                        sql: statement.sql)
                }
            } else if let value = iterator.next() {
                consumedValuesCount += 1
                return value
            } else {
                throw DatabaseError(
                    resultCode: .SQLITE_MISUSE,
                    message: "wrong number of statement arguments: \(values.count)",
                    sql: statement.sql)
            }
        }
        if !allowingRemainingValues && iterator.next() != nil {
            throw DatabaseError(
                resultCode: .SQLITE_MISUSE,
                message: "wrong number of statement arguments: \(values.count)",
                sql: statement.sql)
        }
        if consumedValuesCount == values.count {
            values.removeAll()
        } else {
            values = Array(values[consumedValuesCount...])
        }
        return bindings
    }
}

extension StatementArguments: ExpressibleByArrayLiteral {
    /// Creates a `StatementArguments` from an array literal.
    ///
    /// For example:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["Arthur", 41]
    /// try db.execute(
    ///     sql: "INSERT INTO player (name, score) VALUES (?, ?)"
    ///     arguments: arguments)
    /// ```
    public init(arrayLiteral elements: (any DatabaseValueConvertible)?...) {
        self.init(elements)
    }
}

extension StatementArguments: ExpressibleByDictionaryLiteral {
    /// Creates a `StatementArguments` from a dictionary literal.
    ///
    /// For example:
    ///
    /// ```swift
    /// let arguments: StatementArguments = ["name": "Arthur", "score": 41]
    /// try db.execute(
    ///     sql: "INSERT INTO player (name, score) VALUES (:name, :score)"
    ///     arguments: arguments)
    /// ```
    public init(dictionaryLiteral elements: (String, (any DatabaseValueConvertible)?)...) {
        self.init(elements)
    }
}

extension StatementArguments: CustomStringConvertible {
    public var description: String {
        let valuesDescriptions = values.map(\.description)
        let namedValuesDescriptions = namedValues.map { (key, value) in
            "\(String(reflecting: key)): \(value)"
        }
        return "[" + (namedValuesDescriptions + valuesDescriptions).joined(separator: ", ") + "]"
    }
}

extension StatementArguments: Sendable { }
