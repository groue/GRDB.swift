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
    
    private let resolvedNames: [TableAlias: String]
    private let ownAliases: Set<TableAlias>
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
        aliases: [TableAlias] = [],
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
        aliases: [TableAlias],
        ctes: OrderedDictionary<String, SQLCTE>)
    {
        self.parent = .context(parent)
        self.resolvedNames = aliases.resolvedNames
        self.ownAliases = Set(aliases)
        self.ownCTEs = Dictionary(uniqueKeysWithValues: ctes.lazy.map { ($0.lowercased(), $1) })
    }
    
    /// Returns a generation context suitable for subqueries.
    func subqueryContext(
        aliases: [TableAlias] = [],
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
    func qualifier(for alias: TableAlias) -> String? {
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
    func resolvedName(for alias: TableAlias) -> String {
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
    func aliasName(for alias: TableAlias) -> String? {
        let resolvedName = self.resolvedName(for: alias)
        if resolvedName != alias.tableName {
            return resolvedName
        }
        return nil
    }
    
    func columnCount(in tableName: String) throws -> Int {
        if let cte = ownCTEs[tableName.lowercased()] {
            return try cte.columnCount(db)
        }
        switch parent {
        case let .context(context):
            return try context.columnCount(in: tableName)
        case let .none(db: db, argumentsSink: _):
            return try db.columns(in: tableName).count
        }
    }
}

/// A class that gathers statement arguments, and can be shared between
/// several SQLGenerationContext.
class StatementArgumentsSink {
    private(set) var arguments: StatementArguments
    private let rawSQL: Bool
    
    /// A sink which does not accept any arguments.
    static let forRawSQL = StatementArgumentsSink(rawSQL: true)
    
    private init(rawSQL: Bool) {
        self.arguments = []
        self.rawSQL = rawSQL
    }
    
    /// A sink which accepts arguments
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

// MARK: - TableAlias

/// A TableAlias identifies a table in a request.
///
/// See ``TableRequest/aliased(_:)`` for more information and examples.
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
public class TableAlias {
    private enum Impl {
        /// A TableAlias is undefined when it is created by the GRDB user:
        ///
        ///     let alias = TableAlias()
        ///     let alias = TableAlias(name: "custom")
        case undefined(userName: String?)
        
        /// A TableAlias is a table when explicitly specified:
        ///
        ///     let alias = TableAlias(tableName: "player")
        ///
        /// Or when it qualifies a request that wasn't qualified yet (in which
        /// case it turns from undefined to a table):
        ///
        ///     // SELECT custom.* FROM player custom
        ///     let alias = TableAlias(name: "custom")
        ///     let request = Player.all().aliased(alias)
        case table(tableName: String, userName: String?)
        
        /// A TableAlias can be a proxy for another table alias. Two different
        /// instances for the same table identifier:
        ///
        ///     // Pointless example: make alias2 a proxy for alias1
        ///     let alias1 = TableAlias()
        ///     let alias2 = TableAlias()
        ///     Player.all()
        ///         .aliased(alias1)
        ///         .aliased(alias2)
        ///
        /// Proxies are useful because queries get implicit aliases as soon
        /// as they are joined with associations. In the example below,
        /// customAlias becomes a proxy for the request's implicit alias, which
        /// gets a custom name. This allows implicit and user aliases to merge
        /// into a single "table identifier" that matches the user's expectations:
        ///
        ///     // SELECT custom.*, team.*
        ///     // FROM player custom
        ///     // JOIN team ON taem.id = custom.teamId
        ///     // WHERE custom.name = 'Arthur'
        ///     let customAlias = TableAlias(name: "custom")
        ///     let request = Player
        ///         .including(required: Player.team)
        ///         .filter(sql: "custom.name = 'Arthur'")
        ///         .aliased(customAlias)
        case proxy(TableAlias)
    }
    
    private var impl: Impl
    
    /// Resolve all proxies
    private var root: TableAlias {
        if case .proxy(let base) = impl {
            return base.root
        } else {
            return self
        }
    }
    
    // exposed to SQLGenerationContext
    fileprivate var identityName: String {
        userName ?? tableName
    }
    
    // exposed to SQLGenerationContext
    fileprivate var hasUserName: Bool {
        userName != nil
    }
    
    var tableName: String {
        switch impl {
        case .undefined:
            // Likely a GRDB bug
            fatalError("Undefined alias has no table name")
        case .table(tableName: let tableName, userName: _):
            return tableName
        case .proxy(let base):
            return base.tableName
        }
    }
    
    private var userName: String? {
        switch impl {
        case .undefined(let userName):
            return userName
        case .table(tableName: _, userName: let userName):
            return userName
        case .proxy(let base):
            return base.userName
        }
    }
    
    /// Creates a TableAlias.
    ///
    /// When the alias is given a name, this name is guaranteed to be used as
    /// the table alias in the SQL query:
    ///
    /// ```swift
    /// // SELECT p.* FROM player p
    /// let alias = TableAlias(name: "p")
    /// let request = Player.all().aliased(alias)
    /// ```
    public init(name: String? = nil) {
        self.impl = .undefined(userName: name)
    }
    
    init(tableName: String, userName: String? = nil) {
        self.impl = .table(tableName: tableName, userName: userName)
    }
    
    func becomeProxy(of base: TableAlias) {
        if self === base {
            return
        }
        
        switch impl {
        case let .undefined(userName):
            if let userName {
                // rename
                assert(base.userName == nil || base.userName == userName)
                base.setUserName(userName)
            }
            self.impl = .proxy(base)
        case let .table(tableName: tableName, userName: userName):
            assert(tableName == base.tableName)
            if let userName {
                // rename
                assert(base.userName == nil || base.userName == userName)
                base.setUserName(userName)
            }
            self.impl = .proxy(base)
        case let .proxy(selfBase):
            selfBase.becomeProxy(of: base)
        }
    }
    
    /// Returns nil if aliases can't be merged (conflict in tables, aliases...)
    func merged(with other: TableAlias) -> TableAlias? {
        if self === other {
            return self
        }
        
        let root = self.root
        let otherRoot = other.root
        switch (root.impl, otherRoot.impl) {
        case let (.table(tableName: tableName, userName: userName),
                  .table(tableName: otherTableName, userName: otherUserName)):
            guard tableName == otherTableName else {
                // can't merge
                return nil
            }
            if let userName, let otherUserName, userName != otherUserName {
                // can't merge
                return nil
            }
            root.becomeProxy(of: otherRoot)
            return otherRoot
        default:
            // can't merge
            return nil
        }
    }
    
    private func setUserName(_ userName: String) {
        switch impl {
        case .undefined:
            self.impl = .undefined(userName: userName)
        case .table(tableName: let tableName, userName: _):
            self.impl = .table(tableName: tableName, userName: userName)
        case .proxy(let base):
            base.setUserName(userName)
        }
    }
    
    func setTableName(_ tableName: String) {
        switch impl {
        case .undefined(let userName):
            self.impl = .table(tableName: tableName, userName: userName)
        case .table(tableName: let initialTableName, userName: _):
            // It is a programmer error to reuse the same TableAlias for
            // multiple tables.
            //
            //      // Don't do that
            //      let alias = TableAlias()
            //      let books = Book.aliased(alias)...
            //      let authors = Author.aliased(alias)...
            GRDBPrecondition(
                tableName.lowercased() == initialTableName.lowercased(),
                "A TableAlias most not be used to refer to multiple tables")
        case .proxy(let base):
            base.setTableName(tableName)
        }
    }
    
    /// Returns a result column that refers to the aliased table.
    public subscript(_ selectable: some SQLSelectable) -> SQLSelection {
        // TODO: test
        selectable.sqlSelection.qualified(with: self)
    }
    
    /// Returns an SQL expression that refers to the aliased table.
    ///
    /// For example, let's sort books by author name first, and then by title:
    ///
    /// ```swift
    /// // SELECT book.*
    /// // FROM book
    /// // JOIN author ON author.id = book.authorId
    /// // ORDER BY author.name, book.title
    /// let authorAlias = TableAlias()
    /// let request = Book
    ///     .joining(required: Book.author.aliased(authorAlias))
    ///     .order(authorAlias[Column("name")], Column("title"))
    /// ```
    public subscript(_ expression: some SQLSpecificExpressible & SQLSelectable & SQLOrderingTerm) -> SQLExpression {
        expression.sqlExpression.qualified(with: self)
    }
    
    /// Returns an SQL ordering term that refers to the aliased table.
    ///
    /// For example, let's sort books by author name first, and then by title:
    ///
    /// ```swift
    /// // SELECT book.*
    /// // FROM book
    /// // JOIN author ON author.id = book.authorId
    /// // ORDER BY author.name ASC, book.title ASC
    /// let authorAlias = TableAlias()
    /// let request = Book
    ///     .joining(required: Book.author.aliased(authorAlias))
    ///     .order(authorAlias[Column("name").asc], Column("title").asc)
    /// ```
    public subscript(_ ordering: some SQLOrderingTerm) -> SQLOrdering {
        ordering.sqlOrdering.qualified(with: self)
    }
    
    /// Returns an SQL column that refers to the aliased table.
    ///
    /// For example, let's sort books by author name first, and then by title:
    ///
    /// ```swift
    /// // SELECT book.*
    /// // FROM book
    /// // JOIN author ON author.id = book.authorId
    /// // ORDER BY author.name, book.title
    /// let authorAlias = TableAlias()
    /// let request = Book
    ///     .joining(required: Book.author.aliased(authorAlias))
    ///     .order(authorAlias["name"], Column("title"))
    /// ```
    public subscript(_ column: String) -> SQLExpression {
        .qualifiedColumn(column, self)
    }
    
    /// A boolean SQL expression indicating whether this alias refers to some
    /// rows, or not.
    ///
    /// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
    ///
    /// In the example below, we only fetch books that are not associated to
    /// any author:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord { }
    /// struct Book: TableRecord, FetchableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let authorAlias = TableAlias()
    ///     let request = Book
    ///         .joining(optional: Book.author.aliased(authorAlias))
    ///         .filter(!authorAlias.exists)
    ///     let books = try request.fetchAll(db)
    /// }
    /// ```
    public var exists: SQLExpression {
        SQLExpression.qualifiedExists(self)
    }
}

extension TableAlias: Equatable {
    public static func == (lhs: TableAlias, rhs: TableAlias) -> Bool {
        ObjectIdentifier(lhs.root) == ObjectIdentifier(rhs.root)
    }
}

extension TableAlias: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(root))
    }
}

extension [TableAlias] {
    /// Resolve ambiguities in aliases' names.
    fileprivate var resolvedNames: [TableAlias: String] {
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
        var ambiguousGroups: [[TableAlias]] = []
        
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
        
        var resolvedNames: [TableAlias: String] = [:]
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
