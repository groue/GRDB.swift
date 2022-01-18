/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
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
    /// SQL arguments.
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

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A TableAlias identifies a table in a request.
public class TableAlias: Hashable {
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
    
    /// Creates a TableAlias, suitable for qualifying requests or associations.
    ///
    /// For example:
    ///
    ///     // The request for all books published after their author has died
    ///     //
    ///     // SELECT book.*
    ///     // FROM book
    ///     // JOIN author ON author.id = book.authorId
    ///     // WHERE book.publishDate >= author.deathDate
    ///     let authorAlias = TableAlias()
    ///     let request = Book
    ///         .joining(required: Book.author.aliased(authorAlias))
    ///         .filter(Column("publishDate") >= authorAlias[Column("deathDate")])
    ///
    /// When the alias is given a name, this name is guaranteed to be used as
    /// the table alias in the SQL query:
    ///
    ///     // SELECT book.*
    ///     // FROM book
    ///     // JOIN author a ON a.id = book.authorId
    ///     // WHERE book.publishDate >= a.deathDate
    ///     let authorAlias = TableAlias(name: "a")
    ///     let request = Book
    ///         .joining(required: Book.author.aliased(authorAlias))
    ///         .filter(Column("publishDate") >= authorAlias[Column("deathDate")])
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
            if let userName = userName {
                // rename
                assert(base.userName == nil || base.userName == userName)
                base.setUserName(userName)
            }
            self.impl = .proxy(base)
        case let .table(tableName: tableName, userName: userName):
            assert(tableName == base.tableName)
            if let userName = userName {
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
            if let userName = userName, let otherUserName = otherUserName, userName != otherUserName {
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
    
    /// Returns a qualified value that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ selectable: SQLSelectable) -> SQLSelection {
        selectable.sqlSelection.qualified(with: self)
    }
    
    /// Returns a qualified expression that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ expression: SQLSpecificExpressible & SQLSelectable & SQLOrderingTerm) -> SQLExpression {
        expression.sqlExpression.qualified(with: self)
    }
    
    /// Returns a qualified ordering that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ ordering: SQLOrderingTerm) -> SQLOrdering {
        ordering.sqlOrdering.qualified(with: self)
    }
    
    /// Returns a qualified columnn that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ column: String) -> SQLExpression {
        .qualifiedColumn(column, self)
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// An expression that evaluates to true if the record referred by this
    /// `TableAlias` exists.
    ///
    /// For example, here is how filter books and only keep those that are not
    /// associated to any author:
    ///
    ///     let books: [Book] = try dbQueue.read { db in
    ///         let authorAlias = TableAlias()
    ///         let request = Book
    ///             .joining(optional: Book.author.aliased(authorAlias))
    ///             .filter(!authorAlias.exists)
    ///         return try request.fetchAll(db)
    ///     }
    public var exists: SQLExpression {
        SQLExpression.qualifiedExists(self)
    }
    
    /// :nodoc:
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(root))
    }
    
    /// :nodoc:
    public static func == (lhs: TableAlias, rhs: TableAlias) -> Bool {
        ObjectIdentifier(lhs.root) == ObjectIdentifier(rhs.root)
    }
}

extension Array where Element == TableAlias {
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
