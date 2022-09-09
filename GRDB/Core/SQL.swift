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
    /// `SQL.Element` is a component of an `SQL` literal.
    ///
    /// Elements can be qualified with table aliases, and this is how `SQL`
    /// blends well in the query interface. See below how the `createdAt` column
    /// is qualified with the `player` table in the generated SQL, in order to
    /// avoid any conflict with the `team.createdAt` column:
    ///
    ///     func date(_ value: SQLSpecificExpressible) -> SQLExpression {
    ///         // An SQL literal made of three elements:
    ///         // - "DATE(" raw sql string
    ///         // - expression
    ///         // - ")" raw sql string
    ///         SQL("DATE(\(value))").sqlExpression
    ///     }
    ///
    ///     // SELECT player.*, team.*
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId
    ///     // WHERE DATE(player.createdAt) = '2022-08-17'
    ///     let request = Player
    ///         .filter(date(Column("createdAt")) == "2022-08-17")
    ///         .including(required: Player.team)
    enum Element {
        /// A raw SQL literal with eventual arguments.
        case sql(String, StatementArguments = StatementArguments())
        
        /// A subquery.
        case subquery(SQLSubquery)
        
        /// An expression.
        case expression(SQLExpression)
        
        /// A selection.
        case selection(SQLSelection)
        
        /// An ordering.
        case ordering(SQLOrdering)
        
        var isEmpty: Bool {
            switch self {
            case let .sql(sql, _):
                return sql.isEmpty
            default:
                // Subqueries, expressions, selections and orderings are
                // assumed to be non-empty.
                //
                // Nothing prevents the user from creating an ill-formed empty
                // expression, but we don't care about such misuse:
                //
                //      // An ill-formed empty expression
                //      let expression = SQL("").sqlExpression
                //
                //      let sql: SQL = "\(expression)"
                //      sql.isEmpty // false, deal with it ¯\_(ツ)_/¯
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
                /// A raw SQL string can't be qualified with a table alias,
                /// because we can't parse it.
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
    public init(_ expression: some SQLSpecificExpressible) {
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
    ///     func date(_ value: some SQLExpressible) -> SQLExpression {
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
    /// Creates a literal SQL expression.
    ///
    /// Use this property when you need an explicit `SQLSelection`. For example:
    ///
    ///     // SELECT firstName AS givenName, lastName AS familyName FROM player
    ///     let selection = SQL("firstName AS givenName, lastName AS familyName").sqlSelection
    ///     let request = Player.select(selection)
    public var sqlSelection: SQLSelection {
        .literal(self)
    }
}

extension SQL: SQLOrderingTerm {
    /// Creates a literal SQL ordering.
    ///
    /// Use this property when you need an explicit `SQLOrdering`. For example:
    ///
    ///     // SELECT * FROM player ORDER BY name DESC
    ///     let ordering = SQL("name DESC").sqlOrdering
    ///     let request = Player.order(ordering)
    public var sqlOrdering: SQLOrdering {
        .literal(self)
    }
}

extension Sequence where Element == SQL {
    /// Returns the concatenated `SQL` literal of this sequence of literals,
    /// inserting the given raw SQL separator between each element.
    ///
    /// For example:
    ///
    ///     let components: [SQL] = [
    ///         "UPDATE player",
    ///         "SET name = \(name)",
    ///         "WHERE id = \(id)"
    ///     ]
    ///     let query = components.joined(separator: " ")
    ///
    /// - Note: The separator is a raw SQL string, not an SQL literal that
    ///   supports [SQL Interpolation](https://github.com/groue/GRDB.swift/blob/master/Documentation/SQLInterpolation.md).
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
    /// inserting the given raw SQL separator between each element.
    ///
    /// For example:
    ///
    ///     let components: [SQL] = [
    ///         "UPDATE player",
    ///         "SET name = \(name)",
    ///         "WHERE id = \(id)"
    ///     ]
    ///     let query = components.joined(separator: " ")
    ///
    /// - Note: The separator is a raw SQL string, not an SQL literal that
    ///   supports [SQL Interpolation](https://github.com/groue/GRDB.swift/blob/master/Documentation/SQLInterpolation.md).
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
