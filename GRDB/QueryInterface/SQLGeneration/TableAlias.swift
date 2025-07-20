/// `TableAliasBase` is the base class of `TableAlias`.
///
/// See <https://github.com/groue/GRDB.swift/blob/master/Documentation/AssociationsBasics.md#table-aliases> for more information and examples.
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
public class TableAliasBase: @unchecked Sendable {
    // This Sendable conformance is transient. TableAlias IS NOT really Sendable.
    // TODO: Make TableAlias really Sendable
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
        case proxy(TableAliasBase)
    }
    
    private var impl: Impl
    
    /// Resolve all proxies
    private var root: TableAliasBase {
        if case .proxy(let base) = impl {
            return base.root
        } else {
            return self
        }
    }
    
    // exposed to SQLGenerationContext
    var identityName: String {
        userName ?? tableName
    }
    
    // exposed to SQLGenerationContext
    var hasUserName: Bool {
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
    init(name: String? = nil) {
        self.impl = .undefined(userName: name)
    }
    
    init(tableName: String, userName: String? = nil) {
        self.impl = .table(tableName: tableName, userName: userName)
    }
    
    func becomeProxy(of base: TableAliasBase) {
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
    func merged(with other: TableAliasBase) -> TableAliasBase? {
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
}

extension TableAliasBase: Equatable {
    public static func == (lhs: TableAliasBase, rhs: TableAliasBase) -> Bool {
        ObjectIdentifier(lhs.root) == ObjectIdentifier(rhs.root)
    }
}

extension TableAliasBase: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(root))
    }
}

extension TableAliasBase {
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
    /// struct Author: TableRecord {
    ///     enum Columns {
    ///         static let name = Column("name")
    ///     }
    /// }
    ///
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    ///
    ///     enum Columns {
    ///         static let title = Column("title")
    ///     }
    /// }
    ///
    /// // SELECT book.*
    /// // FROM book
    /// // JOIN author ON author.id = book.authorId
    /// // ORDER BY author.name, book.title
    /// let authorAlias = TableAlias<Author>()
    /// let request = Book
    ///     .joining(required: Book.author.aliased(authorAlias))
    ///     .order { [authorAlias.name, $0.title] }
    /// ```
    public subscript(_ expression: some SQLSpecificExpressible & SQLSelectable & SQLOrderingTerm) -> SQLExpression {
        expression.sqlExpression.qualified(with: self)
    }
    
    public subscript(_ expression: some SQLJSONExpressible &
                     SQLSpecificExpressible &
                     SQLSelectable &
                     SQLOrderingTerm)
    -> AnySQLJSONExpressible
    {
        AnySQLJSONExpressible(sqlExpression: expression.sqlExpression.qualified(with: self))
    }
    
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
}

// MARK: - TableAlias

/// A TableAlias identifies a table in a request.
///
/// See <https://github.com/groue/GRDB.swift/blob/master/Documentation/AssociationsBasics.md#table-aliases> for more information and examples.
///
/// - note: [**🔥 EXPERIMENTAL**](https://github.com/groue/GRDB.swift/blob/master/README.md#what-are-experimental-features)
///
/// ## Topics
///
/// ## Supporting Types
///
/// - ``TableAliasBase``
@dynamicMemberLookup
public final class TableAlias<RowDecoder>: TableAliasBase, @unchecked Sendable {
    init(tableName: String, userName: String? = nil)
    where RowDecoder == Void
    {
        super.init(tableName: tableName, userName: userName)
    }
    
    init(root: TableAliasBase) {
        super.init()
        becomeProxy(of: root)
    }
    
    /// Creates an anonymous TableAlias.
    ///
    /// When the alias is given a name, this name is guaranteed to be used as
    /// the table alias in the SQL query:
    ///
    /// ```swift
    /// // SELECT p.* FROM player p
    /// let alias = TableAlias(name: "p")
    /// let request = Player.all().aliased(alias)
    /// ```
    ///
    /// Anonymous aliases do not provide convenience access to table
    /// columns, unlike record aliases. See ``TableAlias`` for
    /// more information.
    public init(name: String? = nil)
    where RowDecoder == Void
    {
        super.init(name: name)
    }
    
    /// Creates a TableAlias for the specified record type.
    ///
    /// When the alias is given a name, this name is guaranteed to be used as
    /// the table alias in the SQL query:
    ///
    /// ```swift
    /// // SELECT p.* FROM player p
    /// let alias = TableAlias<Player>(name: "p")
    /// let request = Player.all().aliased(alias)
    /// ```
    public init(
        name: String? = nil,
        for record: RowDecoder.Type = RowDecoder.self
    ) {
        super.init(name: name)
    }
}

extension TableAlias {
    /// A boolean SQL expression indicating whether this alias refers to some
    /// rows, or not.
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
    ///     let authorAlias = TableAlias<Author>()
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

extension TableAlias where RowDecoder: TableRecord {
    public typealias DatabaseComponents = RowDecoder.DatabaseComponents
    
    /// Returns a result column that refers to the aliased table.
    public subscript<T>(
        dynamicMember keyPath: KeyPath<DatabaseComponents, T>
    ) -> SQLSelection
    where T: SQLSelectable
    {
        self[RowDecoder.databaseComponents[keyPath: keyPath]]
    }
    
    /// Returns an SQL expression that refers to the aliased table.
    ///
    /// For example, let's sort books by author name first, and then by title:
    ///
    /// ```swift
    /// struct Author: TableRecord {
    ///     enum Columns {
    ///         static let name = Column("name")
    ///     }
    /// }
    ///
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    ///
    ///     enum Columns {
    ///         static let title = Column("title")
    ///     }
    /// }
    ///
    /// // SELECT book.*
    /// // FROM book
    /// // JOIN author ON author.id = book.authorId
    /// // ORDER BY author.name, book.title
    /// let authorAlias = TableAlias<Author>()
    /// let request = Book
    ///     .joining(required: Book.author.aliased(authorAlias))
    ///     .order { [authorAlias.name, $0.title] }
    /// ```
    public subscript<T>(
        dynamicMember keyPath: KeyPath<DatabaseComponents, T>
    ) -> SQLExpression
    where T: SQLSpecificExpressible &
    SQLSelectable &
    SQLOrderingTerm
    {
        self[RowDecoder.databaseComponents[keyPath: keyPath]]
    }
    
    public subscript<T>(
        dynamicMember keyPath: KeyPath<DatabaseComponents, T>
    ) -> AnySQLJSONExpressible
    where T: SQLJSONExpressible &
    SQLSpecificExpressible &
    SQLSelectable &
    SQLOrderingTerm
    {
        self[RowDecoder.databaseComponents[keyPath: keyPath]]
    }
    
    public subscript<T>(
        dynamicMember keyPath: KeyPath<DatabaseComponents, T>
    ) -> SQLOrdering
    where T: SQLOrderingTerm {
        self[RowDecoder.databaseComponents[keyPath: keyPath]]
    }
}
