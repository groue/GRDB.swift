// MARK: - SelectionRequest

/// The protocol for all requests that can refine their selection.
public protocol SelectionRequest {
    /// Creates a request which selects *selection promise*.
    ///
    ///     // SELECT id, email FROM player
    ///     var request = Player.all()
    ///     request = request.select { db in [Column("id"), Column("email") })
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM player
    ///     request
    ///         .select { db in [Column("id")] }
    ///         .select { db in [Column("email")] }
    func select(_ selection: @escaping (Database) throws -> [SQLSelectable]) -> Self
    
    /// Creates a request which appends *selection promise*.
    ///
    ///     // SELECT id, email, name FROM player
    ///     var request = Player.all()
    ///     request = request
    ///         .select([Column("id"), Column("email")])
    ///         .annotated(with: { db in [Column("name")] })
    func annotated(with selection: @escaping (Database) throws -> [SQLSelectable]) -> Self
}

extension SelectionRequest {
    /// Creates a request which selects *selection*.
    ///
    ///     // SELECT id, email FROM player
    ///     var request = Player.all()
    ///     request = request.select([Column("id"), Column("email")])
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM player
    ///     request
    ///         .select([Column("id")])
    ///         .select([Column("email")])
    public func select(_ selection: [SQLSelectable]) -> Self {
        select { _ in selection }
    }
    
    /// Creates a request which selects *selection*.
    ///
    ///     // SELECT id, email FROM player
    ///     var request = Player.all()
    ///     request = request.select(Column("id"), Column("email"))
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM player
    ///     request
    ///         .select(Column("id"))
    ///         .select(Column("email"))
    public func select(_ selection: SQLSelectable...) -> Self {
        select(selection)
    }
    
    /// Creates a request which selects *sql*.
    ///
    ///     // SELECT id, email FROM player
    ///     var request = Player.all()
    ///     request = request.select(sql: "id, email")
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM player
    ///     request
    ///         .select(sql: "id")
    ///         .select(sql: "email")
    public func select(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        select(SQL(sql: sql, arguments: arguments))
    }
    
    /// Creates a request which selects an SQL *literal*.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     // SELECT id, email, score + 1000 FROM player
    ///     let bonus = 1000
    ///     var request = Player.all()
    ///     request = request.select(literal: """
    ///         id, email, score + \(bonus)
    ///         """)
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM player
    ///     request
    ///         .select(...)
    ///         .select(literal: "email")
    public func select(literal sqlLiteral: SQL) -> Self {
        // NOT TESTED
        select(sqlLiteral)
    }
    
    /// Creates a request which appends *selection*.
    ///
    ///     // SELECT id, email, name FROM player
    ///     var request = Player.all()
    ///     request = request
    ///         .select([Column("id"), Column("email")])
    ///         .annotated(with: [Column("name")])
    public func annotated(with selection: [SQLSelectable]) -> Self {
        annotated(with: { _ in selection })
    }
    
    /// Creates a request which appends *selection*.
    ///
    ///     // SELECT id, email, name FROM player
    ///     var request = Player.all()
    ///     request = request
    ///         .select([Column("id"), Column("email")])
    ///         .annotated(with: Column("name"))
    public func annotated(with selection: SQLSelectable...) -> Self {
        annotated(with: selection)
    }
}

// MARK: - FilteredRequest

/// The protocol for all requests that can be filtered.
public protocol FilteredRequest {
    /// Creates a request with the provided *predicate promise* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM player WHERE 1
    ///     var request = Player.all()
    ///     request = request.filter { db in true }
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> Self
}

extension FilteredRequest {
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM player WHERE 0
    ///     var request = Player.all()
    ///     request = request.filter(false)
    @available(*, deprecated, message: "Did you mean filter(id:) or filter(key:)? If not, prefer filter(value.databaseValue) instead. See also none().") // swiftlint:disable:this line_length
    public func filter(_ predicate: SQLExpressible) -> Self {
        filter { _ in predicate }
    }
    
    // Accept SQLSpecificExpressible instead of SQLExpressible, so that we
    // prevent the `Player.filter(42)` misuse.
    // See https://github.com/groue/GRDB.swift/pull/864
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(Column("email") == "arthur@example.com")
    public func filter(_ predicate: SQLSpecificExpressible) -> Self {
        filter { _ in predicate }
    }
    
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    public func filter(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        filter(SQL(sql: sql, arguments: arguments))
    }
    
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    /// Literals allow you to safely embed raw values in your SQL, without any
    /// risk of syntax errors or SQL injection:
    ///
    ///     // SELECT * FROM player WHERE name = 'O''Brien'
    ///     let name = "O'Brien"
    ///     var request = Player.all()
    ///     request = request.filter(literal: "email = \(email)")
    public func filter(literal sqlLiteral: SQL) -> Self {
        // NOT TESTED
        filter(sqlLiteral)
    }
    
    /// Creates a request that matches nothing.
    ///
    ///     // SELECT * FROM player WHERE 0
    ///     var request = Player.all()
    ///     request = request.none()
    public func none() -> Self {
        filter { _ in false }
    }
}

// MARK: - TableRequest

/// The protocol for all requests that feed from a database table
public protocol TableRequest {
    /// The name of the database table
    var databaseTableName: String { get }
    
    /// Creates a request that allows you to define expressions that target
    /// a specific database table.
    ///
    /// In the example below, the "team.avgScore < player.score" condition in
    /// the ON clause could be not achieved without table aliases.
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     // SELECT player.*, team.*
    ///     // JOIN team ON ... AND team.avgScore < player.score
    ///     let playerAlias = TableAlias()
    ///     let request = Player
    ///         .all()
    ///         .aliased(playerAlias)
    ///         .including(required: Player.team.filter(Column("avgScore") < playerAlias[Column("score")])
    func aliased(_ alias: TableAlias) -> Self
}

extension TableRequest where Self: FilteredRequest {
    
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE ... id = 1
    ///     let request = try Player...filter(key: 1)
    ///
    /// - parameter key: A primary key
    public func filter<PrimaryKeyType: DatabaseValueConvertible>(key: PrimaryKeyType?) -> Self {
        guard let key = key else {
            return none()
        }
        return filter(keys: [key])
    }
    
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE ... id IN (1, 2, 3)
    ///     let request = try Player...filter(keys: [1, 2, 3])
    ///
    /// - parameter keys: A collection of primary keys
    public func filter<Sequence: Swift.Sequence>(keys: Sequence)
    -> Self
    where Sequence.Element: DatabaseValueConvertible
    {
        let keys = Array(keys)
        if keys.isEmpty {
            return none()
        }
        
        let databaseTableName = self.databaseTableName
        return filter { db in
            let primaryKey = try db.primaryKey(databaseTableName)
            GRDBPrecondition(
                primaryKey.columns.count == 1,
                "Requesting by key requires a single-column primary key in the table \(databaseTableName)")
            return keys.contains(Column(primaryKey.columns[0]))
        }
    }
    
    /// Creates a request filtered by unique key.
    ///
    ///     // SELECT * FROM player WHERE ... email = 'arthur@example.com'
    ///     let request = try Player...filter(key: ["email": "arthur@example.com"])
    ///
    /// When executed, this request raises a fatal error if there is no unique
    /// index on the key columns.
    ///
    /// - parameter key: A unique key
    public func filter(key: [String: DatabaseValueConvertible?]?) -> Self {
        guard let key = key else {
            return none()
        }
        return filter(keys: [key])
    }
    
    /// Creates a request filtered by unique key.
    ///
    ///     // SELECT * FROM player WHERE ... email = 'arthur@example.com' OR ...
    ///     let request = try Player...filter(keys: [["email": "arthur@example.com"], ...])
    ///
    /// When executed, this request raises a fatal error if there is no unique
    /// index on the key columns.
    ///
    /// - parameter keys: A collection of unique keys
    public func filter(keys: [[String: DatabaseValueConvertible?]]) -> Self {
        if keys.isEmpty {
            return none()
        }
        
        let databaseTableName = self.databaseTableName
        return filter { db in
            try keys
                .map { key in
                    // Prevent filter(keys: [["foo": 1, "bar": 2]]) where
                    // ("foo", "bar") is not a unique key (primary key or columns of a
                    // unique index)
                    guard let columns = try db.columnsForUniqueKey(key.keys, in: databaseTableName) else {
                        fatalError("""
                            table \(databaseTableName) has no unique index on column(s) \
                            \(key.keys.sorted().joined(separator: ", "))
                            """)
                    }
                    
                    let lowercaseColumns = columns.map { $0.lowercased() }
                    return key
                        // Preserve ordering of columns in the unique index
                        .sorted { (kv1, kv2) in
                            let index1 = lowercaseColumns.firstIndex(of: kv1.key.lowercased())!
                            let index2 = lowercaseColumns.firstIndex(of: kv2.key.lowercased())!
                            return index1 < index2
                        }
                        .map { (column, value) in Column(column) == value }
                        .joined(operator: .and)
                }
                .joined(operator: .or)
        }
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension TableRequest
where Self: FilteredRequest,
      Self: JoinableRequest, // for RowDecoder
      RowDecoder: Identifiable,
      RowDecoder.ID: DatabaseValueConvertible
{
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE ... id = 1
    ///     let request = try Player...filter(id: 1)
    ///
    /// - parameter id: A primary key
    public func filter(id: RowDecoder.ID) -> Self {
        filter(key: id)
    }
    
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE ... id IN (1, 2, 3)
    ///     let request = try Player...filter(ids: [1, 2, 3])
    ///
    /// - parameter ids: A collection of primary keys
    public func filter<Collection: Swift.Collection>(ids: Collection)
    -> Self
    where Collection.Element == RowDecoder.ID
    {
        filter(keys: ids)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension TableRequest
where Self: FilteredRequest,
      Self: JoinableRequest, // for RowDecoder
      RowDecoder: Identifiable,
      RowDecoder.ID: _OptionalProtocol,
      RowDecoder.ID.Wrapped: DatabaseValueConvertible
{
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE ... id = 1
    ///     let request = try Player...filter(id: 1)
    ///
    /// - parameter id: A primary key
    public func filter(id: RowDecoder.ID.Wrapped) -> Self {
        filter(key: id)
    }
    
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE ... id IN (1, 2, 3)
    ///     let request = try Player...filter(ids: [1, 2, 3])
    ///
    /// - parameter ids: A collection of primary keys
    public func filter<Collection: Swift.Collection>(ids: Collection)
    -> Self
    where Collection.Element == RowDecoder.ID.Wrapped
    {
        filter(keys: ids)
    }
}

extension TableRequest where Self: OrderedRequest {
    /// Creates a request ordered by primary key.
    public func orderByPrimaryKey() -> Self {
        let tableName = self.databaseTableName
        return order { db in
            try db.primaryKey(tableName).columns.map(SQLExpression.column)
        }
    }
}

extension TableRequest where Self: AggregatingRequest {
    /// Creates a request grouped by primary key.
    public func groupByPrimaryKey() -> Self {
        let tableName = self.databaseTableName
        return group { db in
            let primaryKey = try db.primaryKey(tableName)
            if let rowIDColumn = primaryKey.rowIDColumn {
                // Prefer the user-provided name of the rowid
                return [Column(rowIDColumn)]
            } else if primaryKey.tableHasRowID {
                // Prefer the rowid
                return [Column.rowID]
            } else {
                // WITHOUT ROWID table: group by primary key columns
                return primaryKey.columns.map { Column($0) }
            }
        }
    }
}

// MARK: - AggregatingRequest

/// The protocol for all requests that can aggregate.
public protocol AggregatingRequest {
    /// Creates a request grouped according to *expressions promise*.
    func group(_ expressions: @escaping (Database) throws -> [SQLExpressible]) -> Self
    
    /// Creates a request with the provided *predicate promise* added to the
    /// eventual set of already applied predicates.
    func having(_ predicate: @escaping (Database) throws -> SQLExpressible) -> Self
}

extension AggregatingRequest {
    /// Creates a request grouped according to *expressions*.
    public func group(_ expressions: [SQLExpressible]) -> Self {
        group { _ in expressions }
    }
    
    /// Creates a request grouped according to *expressions*.
    public func group(_ expressions: SQLExpressible...) -> Self {
        group(expressions)
    }
    
    /// Creates a request with a new grouping.
    public func group(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        group(SQL(sql: sql, arguments: arguments))
    }
    
    /// Creates a request with a new grouping.
    public func group(literal sqlLiteral: SQL) -> Self {
        // NOT TESTED
        group(sqlLiteral)
    }
    
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    public func having(_ predicate: SQLExpressible) -> Self {
        having { _ in predicate }
    }
    
    /// Creates a request with the provided *sql* added to the
    /// eventual set of already applied predicates.
    public func having(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        having(SQL(sql: sql, arguments: arguments))
    }
    
    /// Creates a request with the provided SQL *literal* added to the
    /// eventual set of already applied predicates.
    public func having(literal sqlLiteral: SQL) -> Self {
        // NOT TESTED
        having(sqlLiteral)
    }
}

// MARK: - OrderedRequest

/// The protocol for all requests that can be ordered.
public protocol OrderedRequest {
    /// Creates a request with the provided *orderings promise*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order { _ in [Column("name")] }
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     request
    ///         .order{ _ in [Column("email")] }
    ///         .reversed()
    ///         .order{ _ in [Column("name")] }
    func order(_ orderings: @escaping (Database) throws -> [SQLOrderingTerm]) -> Self
    
    /// Creates a request that reverses applied orderings.
    ///
    ///     // SELECT * FROM player ORDER BY name DESC
    ///     var request = Player.all().order(Column("name"))
    ///     request = request.reversed()
    ///
    /// If no ordering was applied, the returned request is identical.
    ///
    ///     // SELECT * FROM player
    ///     var request = Player.all()
    ///     request = request.reversed()
    func reversed() -> Self
    
    /// Creates a request without any ordering.
    ///
    ///     // SELECT * FROM player
    ///     var request = Player.all().order(Column("name"))
    ///     request = request.unordered()
    func unordered() -> Self
}

extension OrderedRequest {
    /// Creates a request with the provided *orderings*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order(Column("name"))
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     request
    ///         .order(Column("email"))
    ///         .reversed()
    ///         .order(Column("name"))
    public func order(_ orderings: SQLOrderingTerm...) -> Self {
        order { _ in orderings }
    }
    
    /// Creates a request with the provided *orderings*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order(Column("name"))
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     request
    ///         .order(Column("email"))
    ///         .reversed()
    ///         .order(Column("name"))
    public func order(_ orderings: [SQLOrderingTerm]) -> Self {
        order { _ in orderings }
    }
    
    /// Creates a request sorted according to *sql*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order(sql: "name")
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     request
    ///         .order(sql: "email")
    ///         .order(sql: "name")
    public func order(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        order(SQL(sql: sql, arguments: arguments))
    }
    
    /// Creates a request sorted according to an SQL *literal*.
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order(literal: "name")
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM player ORDER BY name
    ///     request
    ///         .order(literal: "email")
    ///         .order(literal: "name")
    public func order(literal sqlLiteral: SQL) -> Self {
        // NOT TESTED
        order(sqlLiteral)
    }
}

// MARK: - JoinableRequest

/// Implementation details of `JoinableRequest`.
///
/// :nodoc:
public protocol _JoinableRequest {
    /// Creates a request that prefetches an association.
    func _including(all association: _SQLAssociation) -> Self
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned request does not
    /// require that the associated database table contains a matching row.
    func _including(optional association: _SQLAssociation) -> Self
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned request requires
    /// that the associated database table contains a matching row.
    func _including(required association: _SQLAssociation) -> Self
    
    /// Creates a request that joins an association. The columns of the
    /// associated record are not selected. The returned request does not
    /// require that the associated database table contains a matching row.
    func _joining(optional association: _SQLAssociation) -> Self
    
    /// Creates a request that joins an association. The columns of the
    /// associated record are not selected. The returned request requires
    /// that the associated database table contains a matching row.
    func _joining(required association: _SQLAssociation) -> Self
}

/// The protocol for all requests that can be associated.
public protocol JoinableRequest: _JoinableRequest {
    /// The record type that can be associated to.
    ///
    /// In the request below, it is Book:
    ///
    ///     let request = Book.all()
    ///
    /// In the `belongsTo` association below, it is Author:
    ///
    ///     struct Book: TableRecord {
    ///         // BelongsToAssociation<Book, Author>
    ///         static let author = belongsTo(Author.self)
    ///     }
    associatedtype RowDecoder
}

extension JoinableRequest {
    /// Creates a request that prefetches an association.
    public func including<A: AssociationToMany>(all association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        _including(all: association._sqlAssociation)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned request does not
    /// require that the associated database table contains a matching row.
    public func including<A: Association>(optional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        _including(optional: association._sqlAssociation)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned request requires
    /// that the associated database table contains a matching row.
    public func including<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        _including(required: association._sqlAssociation)
    }
    
    /// Creates a request that joins an association. The columns of the
    /// associated record are not selected. The returned request does not
    /// require that the associated database table contains a matching row.
    public func joining<A: Association>(optional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        _joining(optional: association._sqlAssociation)
    }
    
    /// Creates a request that joins an association. The columns of the
    /// associated record are not selected. The returned request requires
    /// that the associated database table contains a matching row.
    public func joining<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        _joining(required: association._sqlAssociation)
    }
}

// MARK: - DerivableRequest

/// The base protocol for all requests that can be refined.
public protocol DerivableRequest: AggregatingRequest, FilteredRequest,
                                  JoinableRequest, OrderedRequest,
                                  SelectionRequest, TableRequest
{
    /// Creates a request which returns distinct rows.
    ///
    ///     // SELECT DISTINCT * FROM player
    ///     var request = Player.all()
    ///     request = request.distinct()
    ///
    ///     // SELECT DISTINCT name FROM player
    ///     var request = Player.select(Column("name"))
    ///     request = request.distinct()
    func distinct() -> Self
    
    /// Creates a request which fetches *limit* rows, starting at *offset*.
    ///
    ///     // SELECT * FROM player LIMIT 10 OFFSET 20
    ///     var request = Player.all()
    ///     request = request.limit(10, offset: 20)
    ///
    /// Any previous limit is replaced.
    ///
    /// - warning: Avoid to call this method on associations: it is unlikely it
    ///   does what you expect it to do. Only call it on requests.
    ///
    /// :nodoc:
    func limit(_ limit: Int, offset: Int?) -> Self
    
    /// Returns a request which embeds the common table expression.
    ///
    /// If a common table expression with the same table name had already been
    /// embedded, it is replaced by the new one.
    ///
    /// For example, you can build a request that fetches all chats with their
    /// latest message:
    ///
    ///     let latestMessageRequest = Message
    ///         .annotated(with: max(Column("date")))
    ///         .group(Column("chatID"))
    ///
    ///     let latestMessageCTE = CommonTableExpression(
    ///         named: "latestMessage",
    ///         request: latestMessageRequest)
    ///
    ///     let latestMessage = Chat.association(
    ///         to: latestMessageCTE,
    ///         on: { chat, latestMessage in
    ///             chat[Column("id")] == latestMessage[Column("chatID")]
    ///         })
    ///
    ///     // WITH latestMessage AS
    ///     //   (SELECT *, MAX(date) FROM message GROUP BY chatID)
    ///     // SELECT chat.*, latestMessage.*
    ///     // FROM chat
    ///     // LEFT JOIN latestMessage ON chat.id = latestMessage.chatID
    ///     let request = Chat.all()
    ///         .with(latestMessageCTE)
    ///         .including(optional: latestMessage)
    func with<RowDecoder>(_ cte: CommonTableExpression<RowDecoder>) -> Self
}

extension DerivableRequest {
    /// Creates a request which fetches *limit* rows.
    ///
    ///     // SELECT * FROM player LIMIT 1
    ///     var request = Player.all()
    ///     request = request.limit(1)
    ///
    /// Any previous limit is replaced.
    ///
    /// - warning: Avoid to call this method on associations: it is unlikely it
    ///   does what you expect it to do. Only call it on requests.
    ///
    /// :nodoc:
    public func limit(_ limit: Int) -> Self {
        self.limit(limit, offset: nil)
    }
    
    private func annotated(with aggregate: AssociationAggregate<RowDecoder>) -> Self {
        var request = self
        let expression = aggregate.prepare(&request)
        if let key = aggregate.key {
            return request.annotated(with: expression.forKey(key))
        } else {
            return request.annotated(with: expression)
        }
    }
    
    /// Creates a request which appends *aggregates* to the current selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.id) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.all()
    ///     request = request.annotated(with: Player.books.count)
    public func annotated(with aggregates: AssociationAggregate<RowDecoder>...) -> Self {
        annotated(with: aggregates)
    }
    
    /// Creates a request which appends *aggregates* to the current selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.id) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.all()
    ///     request = request.annotated(with: [Player.books.count])
    public func annotated(with aggregates: [AssociationAggregate<RowDecoder>]) -> Self {
        aggregates.reduce(self) { request, aggregate in
            request.annotated(with: aggregate)
        }
    }
    
    /// Creates a request which appends the provided aggregate *predicate* to
    /// the eventual set of already applied predicates.
    ///
    ///     // SELECT player.*
    ///     // FROM player LEFT JOIN book ...
    ///     // HAVING COUNT(DISTINCT book.id) = 0
    ///     var request = Player.all()
    ///     request = request.having(Player.books.isEmpty)
    public func having(_ predicate: AssociationAggregate<RowDecoder>) -> Self {
        var request = self
        let expression = predicate.prepare(&request)
        return request.having(expression)
    }
}
