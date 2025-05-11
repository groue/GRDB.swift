/// SQLGenerationContext supports SQL generation:
///
/// - It provides a database connection during SQL generation, for any purpose
///   such as schema introspection.
///
/// - It provides unique table aliases in order to disambiguates table names
///   and columns.
///
/// - It gathers SQL arguments in order to prevent SQL injection.
final class SQLGenerationContext {
    private enum Parent {
        case none(db: Database, argumentsSink: StatementArgumentsSink)
        case context(SQLGenerationContext)
    }
    
    /// A database connection.
    var db: Database {
        switch parent {
        case let .none(db: db, argumentsSink: _): return db
        case let .context(context): return context.db
        }
    }
    
    /// All gathered arguments
    var arguments: StatementArguments { argumentsSink.arguments }
    
    /// Access to the database connection, the arguments sink, ctes, and resolved
    /// names of table aliases from outer contexts (useful in case of
    /// subquery generation).
    private let parent: Parent
    
    /// The arguments sink which prevents SQL injection.
    private var argumentsSink: StatementArgumentsSink {
        switch parent {
        case let .none(db: _, argumentsSink: argumentsSink): return argumentsSink
        case let .context(context): return context.argumentsSink
        }
    }
    
    private let resolvedNames: [TableAliasBase: String]
    private let ownAliases: Set<TableAliasBase>
    private let ownCTEs: [String: SQLCTE]
    
    /// Creates a generation context.
    ///
    /// - parameter db: A database connection.
    /// - parameter argumentsSink: An arguments sink.
    /// - parameter aliases: An array of table aliases to disambiguate.
    /// - parameter ctes: An dictionary of available CTEs.
    init(
        _ db: Database,
        argumentsSink: StatementArgumentsSink = StatementArgumentsSink(),
        aliases: [TableAliasBase] = [],
        ctes: OrderedDictionary<String, SQLCTE> = [:])
    {
        self.parent = .none(db: db, argumentsSink: argumentsSink)
        self.resolvedNames = aliases.resolvedNames
        self.ownAliases = Set(aliases)
        self.ownCTEs = Dictionary(uniqueKeysWithValues: ctes.lazy.map { ($0.lowercased(), $1) })
    }
    
    /// Creates a generation context.
    ///
    /// - parameter parent: A parent context.
    /// - parameter aliases: An array of table aliases to disambiguate.
    /// - parameter ctes: An dictionary of available CTEs.
    private init(
        parent: SQLGenerationContext,
        aliases: [TableAliasBase],
        ctes: OrderedDictionary<String, SQLCTE>)
    {
        self.parent = .context(parent)
        self.resolvedNames = aliases.resolvedNames
        self.ownAliases = Set(aliases)
        self.ownCTEs = Dictionary(uniqueKeysWithValues: ctes.lazy.map { ($0.lowercased(), $1) })
    }
    
    /// Returns a generation context suitable for subqueries.
    func subqueryContext(
        aliases: [TableAliasBase] = [],
        ctes: OrderedDictionary<String, SQLCTE> = [:]) -> SQLGenerationContext
    {
        SQLGenerationContext(parent: self, aliases: aliases, ctes: ctes)
    }
    
    /// Returns whether arguments could be appended.
    ///
    /// A false result means that the generation context does not support
    /// SQL arguments, and `?` placeholders are not supported.
    /// This happens, for example, when we are creating tables:
    ///
    ///     // CREATE TABLE player (
    ///     //   name TEXT DEFAULT 'Anonymous' -- String literal instead of ?
    ///     // )
    ///     let defaultName = "Anonymous"
    ///     try db.create(table: "player") { t in
    ///         t.column(literal: "name TEXT DEFAULT \(defaultName)")
    ///     }
    ///
    /// A false result is turned into a fatal error when the user uses
    /// SQL arguments at unsupported locations:
    ///
    ///     // Fatal error:
    ///     // Not implemented: turning an SQL parameter into an SQL literal value
    ///     let defaultName = "Anonymous"
    ///     let literal = SQL(sql: "name TEXT DEFAULT ?", arguments: [defaultName])
    ///     try db.create(table: "player") { t in
    ///         t.column(literal: literal)
    ///     }
    func append(arguments: StatementArguments) -> Bool {
        argumentsSink.append(arguments: arguments)
    }
    
    /// May be nil, when a qualifier is not needed:
    ///
    /// WHERE <qualifier>.column == 1
    /// SELECT <qualifier>.*
    ///
    /// WHERE column == 1
    /// SELECT *
    func qualifier(for alias: TableAliasBase) -> String? {
        if alias.hasUserName {
            return alias.identityName
        }
        if !ownAliases.contains(alias) {
            return resolvedName(for: alias)
        }
        if ownAliases.count > 1 {
            return resolvedName(for: alias)
        }
        return nil
    }
    
    /// WHERE <resolvedName> MATCH pattern
    func resolvedName(for alias: TableAliasBase) -> String {
        if let name = resolvedNames[alias] {
            return name
        }
        switch parent {
        case .none:
            return alias.identityName
        case let .context(context):
            return context.resolvedName(for: alias)
        }
    }
    
    /// FROM tableName <alias>
    func aliasName(for alias: TableAliasBase) -> String? {
        let resolvedName = self.resolvedName(for: alias)
        if resolvedName != alias.tableName {
            return resolvedName
        }
        return nil
    }
    
    /// Return the number of columns in the table or CTE identified
    /// by `tableName`.
    ///
    /// - parameter tableName: The table name.
    /// - parameter excludedColumns: The eventual set of excluded columns.
    func columnCount(
        in tableName: String,
        excluding excludedColumns: Set<CaseInsensitiveIdentifier>
    ) throws -> Int {
        if let cte = ownCTEs[tableName.lowercased()] {
            if excludedColumns.isEmpty {
                return try cte.columnCount(db)
            } else {
                fatalError("Not implemented: counting CTE columns with excluded columns")
            }
        }
        switch parent {
        case let .context(context):
            return try context.columnCount(in: tableName, excluding: excludedColumns)
        case let .none(db: db, argumentsSink: _):
            if excludedColumns.isEmpty {
                return try db.columns(in: tableName).count
            } else {
                return try db
                    .columns(in: tableName)
                    .filter { !excludedColumns.contains(CaseInsensitiveIdentifier(rawValue: $0.name)) }
                    .count
            }
        }
    }
    
    /// Return the names of the columns in the table or CTE identified
    /// by `tableName`.
    ///
    /// - parameter tableName: The table name.
    func columnNames(in tableName: String) throws -> [String] {
        if ownCTEs[tableName.lowercased()] != nil {
            fatalError("Not implemented: extracing CTE column names")
        }
        switch parent {
        case let .context(context):
            return try context.columnNames(in: tableName)
        case let .none(db: db, argumentsSink: _):
            return try db.columns(in: tableName).map(\.name)
        }
    }
}

/// A class that gathers statement arguments, and can be shared between
/// several SQLGenerationContext.
class StatementArgumentsSink {
    private(set) var arguments: StatementArguments
    private let rawSQL: Bool
    
    // This non-Sendable instance can be used from multiple threads
    // concurrently, because it never modifies its `arguments`
    // mutable state.
    /// A sink which turns all argument values into SQL literals.
    ///
    /// The `"WHERE name = \("O'Brien")"` SQL literal is turned into the
    /// `WHERE name = 'O''Brien'` SQL.
    nonisolated(unsafe) static let literalValues = StatementArgumentsSink(rawSQL: true)
    
    private init(rawSQL: Bool) {
        self.arguments = []
        self.rawSQL = rawSQL
    }
    
    /// A sink which turns all argument values into `?` SQL parameters.
    ///
    /// The `"WHERE name = \("O'Brien")"` SQL literal is turned into the
    /// `WHERE name = ?` SQL.
    convenience init() {
        self.init(rawSQL: false)
    }
    
    // fileprivate so that SQLGenerationContext.append(arguments:) is the only
    // available api.
    /// Returns false for SQLGenerationContext.rawSQLContext
    fileprivate func append(arguments: StatementArguments) -> Bool {
        if arguments.isEmpty {
            return true
        }
        if rawSQL {
            return false
        }
        self.arguments += arguments
        return true
    }
}

extension [TableAliasBase] {
    /// Resolve ambiguities in aliases' names.
    fileprivate var resolvedNames: [TableAliasBase: String] {
        // It is a programmer error to reuse the same TableAlias for
        // multiple tables.
        //
        //      // Don't do that
        //      let alias = TableAlias()
        //      let request = Book
        //          .including(required: Book.author.aliased(alias)...)
        //          .including(required: Book.author.aliased(alias)...)
        GRDBPrecondition(count == Set(self).count, "A TableAlias most not be used to refer to multiple tables")
        
        let groups = Dictionary(grouping: self) {
            $0.identityName.lowercased()
        }
        
        var uniqueLowercaseNames: Set<String> = []
        var ambiguousGroups: [[TableAliasBase]] = []
        
        for (lowercaseName, group) in groups {
            if group.count > 1 {
                // It is a programmer error to reuse the same alias for multiple tables
                GRDBPrecondition(
                    group.countElements(where: \.hasUserName) < 2,
                    "ambiguous alias: \(group[0].identityName)")
                ambiguousGroups.append(group)
            } else {
                uniqueLowercaseNames.insert(lowercaseName)
            }
        }
        
        var resolvedNames: [TableAliasBase: String] = [:]
        for group in ambiguousGroups {
            var index = 1
            for alias in group {
                if alias.hasUserName { continue }
                let radical = alias.identityName.digitlessRadical
                var resolvedName: String
                repeat {
                    resolvedName = "\(radical)\(index)"
                    index += 1
                } while uniqueLowercaseNames.contains(resolvedName.lowercased())
                uniqueLowercaseNames.insert(resolvedName.lowercased())
                resolvedNames[alias] = resolvedName
            }
        }
        return resolvedNames
    }
}
