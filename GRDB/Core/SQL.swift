/// `SQL` helps you build SQL literal with
/// [SQL Interpolation](https://github.com/groue/GRDB.swift/blob/master/Documentation/SQLInterpolation.md).
///
/// For example:
///
///     try dbQueue.write { db in
///         let name: String = ...
///         let id: Int64 = ...
///         let query: SQL = "UPDATE player SET name = \(name) WHERE id = \(id)"
///         try db.execute(literal: query)
///     }
public struct SQL {
    /// `SQL` is an array of elements which can be qualified with table
    /// aliases. This is how `SQL` can blend well in the query interface.
    enum Element {
        // Can't be qualified with a table alias
        case sql(String, StatementArguments = StatementArguments())
        // Does not need to be qualified with a table alias
        case subquery(SQLSubquery)
        // Cases below can be qualified with a table alias
        case expression(SQLExpression)
        case selection(SQLSelection)
        case ordering(SQLOrdering)
        
        var isEmpty: Bool {
            switch self {
            case let .sql(sql, _):
                return sql.isEmpty
            default:
                return false
            }
        }
        
        fileprivate func sql(_ context: SQLGenerationContext) throws -> String {
            switch self {
            case let .sql(sql, arguments):
                if context.append(arguments: arguments) == false {
                    // We don't know how to look for `?` in sql and
                    // replace them with literals.
                    fatalError("Not implemented: turning an SQL parameter into an SQL literal value")
                }
                return sql
            case let .subquery(subquery):
                return try subquery.sql(context)
            case let .expression(expression):
                return try expression.sql(context)
            case let .selection(selection):
                return try selection.sql(context)
            case let .ordering(ordering):
                return try ordering.sql(context)
            }
        }
        
        fileprivate func qualified(with alias: TableAlias) -> Element {
            switch self {
            case .sql:
                // Can't qualify raw SQL string
                return self
            case .subquery:
                // Subqueries don't need table alias
                return self
            case let .expression(expression):
                return .expression(expression.qualified(with: alias))
            case let .selection(selection):
                return .selection(selection.qualified(with: alias))
            case let .ordering(ordering):
                return .ordering(ordering.qualified(with: alias))
            }
        }
    }
    
    private(set) var elements: [Element]
    
    init(elements: [Element]) {
        self.elements = elements
    }
    
    /// Creates an `SQL` literal from a plain SQL string, and
    /// eventual arguments.
    ///
    /// For example:
    ///
    ///     let query = SQL(
    ///         sql: "UPDATE player SET name = ? WHERE id = ?",
    ///         arguments: [name, id])
    public init(sql: String, arguments: StatementArguments = StatementArguments()) {
        self.init(elements: [.sql(sql, arguments)])
    }
    
    /// Creates an `SQL` literal from an SQL expression.
    ///
    /// For example:
    ///
    ///     let columnLiteral = SQL(Column("username"))
    ///     let suffixLiteral = SQL("@example.com".databaseValue)
    ///     let emailLiteral = [columnLiteral, suffixLiteral].joined(separator: " || ")
    ///     let request = User.select(emailLiteral.sqlExpression)
    ///     let emails = try String.fetchAll(db, request)
    public init(_ expression: SQLSpecificExpressible) {
        self.init(elements: [.expression(expression.sqlExpression)])
    }
    
    /// Returns true if this literal generates an empty SQL string
    public var isEmpty: Bool {
        elements.allSatisfy(\.isEmpty)
    }
    
    /// Turn a `SQL` literal into raw SQL and arguments.
    ///
    /// - parameter db: A database connection.
    /// - returns: A tuple made of a raw SQL string, and statement arguments.
    public func build(_ db: Database) throws -> (sql: String, arguments: StatementArguments) {
        let context = SQLGenerationContext(db)
        let sql = try self.sql(context)
        return (sql: sql, arguments: context.arguments)
    }
    
    /// Returns the literal SQL string given an SQL generation context.
    func sql(_ context: SQLGenerationContext) throws -> String {
        try elements.map { try $0.sql(context) }.joined()
    }
    
    func qualified(with alias: TableAlias) -> SQL {
        SQL(elements: elements.map { $0.qualified(with: alias) })
    }
}

extension SQL {
    /// Returns the `SQL` literal produced by the concatenation of two literals.
    ///
    ///     let name = "O'Brien"
    ///     let selection: SQL = "SELECT * FROM player "
    ///     let condition: SQL = "WHERE name = \(name)"
    ///     let query = selection + condition
    public static func + (lhs: SQL, rhs: SQL) -> SQL {
        var result = lhs
        result += rhs
        return result
    }
    
    /// Appends an `SQL` literal to the receiver.
    ///
    ///     let name = "O'Brien"
    ///     var query: SQL = "SELECT * FROM player "
    ///     query += "WHERE name = \(name)"
    public static func += (lhs: inout SQL, rhs: SQL) {
        lhs.elements += rhs.elements
    }
    
    /// Appends an `SQL` literal to the receiver.
    ///
    ///     let name = "O'Brien"
    ///     var query: SQL = "SELECT * FROM player "
    ///     query.append(literal: "WHERE name = \(name)")
    public mutating func append(literal sqlLiteral: SQL) {
        self += sqlLiteral
    }
    
    /// Appends a plain SQL string to the receiver, and eventual arguments.
    ///
    ///     let name = "O'Brien"
    ///     var query: SQL = "SELECT * FROM player "
    ///     query.append(sql: "WHERE name = ?", arguments: [name])
    public mutating func append(sql: String, arguments: StatementArguments = StatementArguments()) {
        self += SQL(sql: sql, arguments: arguments)
    }
}

extension SQL: SQLSpecificExpressible {
    /// Creates a literal SQL expression.
    ///
    /// Use this property when you need an explicit `SQLExpression`.
    /// For example:
    ///
    ///     func date(_ value: SQLExpressible) -> SQLExpression {
    ///         SQL("DATE(\(value))").sqlExpression
    ///     }
    ///
    ///     // SELECT * FROM "player" WHERE DATE("createdAt") = '2020-01-23'
    ///     let createdAt = Column("createdAt")
    ///     let request = Player.filter(date(createdAt) == "2020-01-23")
    public var sqlExpression: SQLExpression {
        .literal(self)
    }
}

extension SQL: SQLSelectable {
    public var sqlSelection: SQLSelection {
        .literal(self)
    }
}

extension SQL: SQLOrderingTerm {
    public var sqlOrdering: SQLOrdering {
        .literal(self)
    }
}

extension Sequence where Element == SQL {
    /// Returns the concatenated `SQL` literal of this sequence of literals,
    /// inserting the given separator between each element.
    ///
    ///     let components: [SQL] = [
    ///         "UPDATE player",
    ///         "SET name = \(name)",
    ///         "WHERE id = \(id)"
    ///     ]
    ///     let query = components.joined(separator: " ")
    public func joined(separator: String = "") -> SQL {
        if separator.isEmpty {
            return SQL(elements: flatMap(\.elements))
        } else {
            return SQL(elements: Array(map(\.elements).joined(separator: CollectionOfOne(.sql(separator)))))
        }
    }
}

extension Collection where Element == SQL {
    /// Returns the concatenated `SQL` literal of this collection of literals,
    /// inserting the given SQL separator between each element.
    ///
    ///     let components: [SQL] = [
    ///         "UPDATE player",
    ///         "SET name = \(name)",
    ///         "WHERE id = \(id)"
    ///     ]
    ///     let query = components.joined(separator: " ")
    public func joined(separator: String = "") -> SQL {
        if separator.isEmpty {
            return SQL(elements: flatMap(\.elements))
        } else {
            return SQL(elements: Array(map(\.elements).joined(separator: CollectionOfOne(.sql(separator)))))
        }
    }
}

// MARK: - ExpressibleByStringInterpolation

extension SQL: ExpressibleByStringInterpolation {
    /// :nodoc
    public init(unicodeScalarLiteral: String) {
        self.init(sql: unicodeScalarLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(extendedGraphemeClusterLiteral: String) {
        self.init(sql: extendedGraphemeClusterLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(stringLiteral: String) {
        self.init(sql: stringLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(stringInterpolation sqlInterpolation: SQLInterpolation) {
        self.init(elements: sqlInterpolation.elements)
    }
}
