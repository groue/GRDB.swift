import Foundation

// MARK: - TypedRequest

/// The protocol for all requests that know how database rows should
/// be interpreted.
public protocol TypedRequest<RowDecoder> {
    /// The type that can decode database rows.
    ///
    /// In the request below, it is Player:
    ///
    ///     let request = Player.all()
    associatedtype RowDecoder
}

// MARK: - SelectionRequest

/// The protocol for all requests that can refine their selection.
public protocol SelectionRequest {
    /// Creates a request which selects *selection promise*.
    ///
    ///     // SELECT id, email FROM player
    ///     var request = Player.all()
    ///     request = request.selectWhenConnected { db in [Column("id"), Column("email") })
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM player
    ///     request
    ///         .selectWhenConnected { db in [Column("id")] }
    ///         .selectWhenConnected { db in [Column("email")] }
    func selectWhenConnected(_ selection: @escaping (Database) throws -> [any SQLSelectable]) -> Self
    
    /// Creates a request which appends *selection promise*.
    ///
    ///     // SELECT id, email, name FROM player
    ///     var request = Player.all()
    ///     request = request
    ///         .select([Column("id"), Column("email")])
    ///         .annotatedWhenConnected(with: { db in [Column("name")] })
    func annotatedWhenConnected(with selection: @escaping (Database) throws -> [any SQLSelectable]) -> Self
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
    public func select(_ selection: [any SQLSelectable]) -> Self {
        selectWhenConnected { _ in selection }
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
    public func select(_ selection: any SQLSelectable...) -> Self {
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
    public func annotated(with selection: [any SQLSelectable]) -> Self {
        annotatedWhenConnected(with: { _ in selection })
    }
    
    /// Creates a request which appends *selection*.
    ///
    ///     // SELECT id, email, name FROM player
    ///     var request = Player.all()
    ///     request = request
    ///         .select([Column("id"), Column("email")])
    ///         .annotated(with: Column("name"))
    public func annotated(with selection: any SQLSelectable...) -> Self {
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
    ///     request = request.filterWhenConnected { db in true }
    func filterWhenConnected(_ predicate: @escaping (Database) throws -> any SQLExpressible) -> Self
}

extension FilteredRequest {
    // Accept SQLSpecificExpressible instead of SQLExpressible, so that we
    // prevent the `Player.filter(42)` misuse.
    // See https://github.com/groue/GRDB.swift/pull/864
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(Column("email") == "arthur@example.com")
    public func filter(_ predicate: some SQLSpecificExpressible) -> Self {
        filterWhenConnected { _ in predicate }
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
        filterWhenConnected { _ in false }
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

extension TableRequest where Self: FilteredRequest, Self: TypedRequest {
    
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE ... id = 1
    ///     let request = try Player...filter(key: 1)
    ///
    /// - parameter key: A primary key
    public func filter(key: some DatabaseValueConvertible) -> Self {
        if key.databaseValue.isNull {
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
        // In order to encode keys in the database, we perform a runtime check
        // for EncodableRecord, and look for a customized encoding strategy.
        // Such dynamic dispatch is unusual in GRDB, but static dispatch
        // (customizing TableRequest where RowDecoder: EncodableRecord) would
        // make it impractical to define `filter(id:)`, `fetchOne(_:key:)`,
        // `deleteAll(_:ids:)` etc.
        if let recordType = RowDecoder.self as? any EncodableRecord.Type {
            if Sequence.Element.self == Date.self || Sequence.Element.self == Optional<Date>.self {
                let strategy = recordType.databaseDateEncodingStrategy
                let keys = keys.compactMap { ($0 as! Date?).flatMap(strategy.encode)?.databaseValue }
                return filter(rawKeys: keys)
            } else if Sequence.Element.self == UUID.self || Sequence.Element.self == Optional<UUID>.self {
                let strategy = recordType.databaseUUIDEncodingStrategy
                let keys = keys.map { ($0 as! UUID?).map(strategy.encode)?.databaseValue }
                return filter(rawKeys: keys)
            }
        }
        
        return filter(rawKeys: keys)
    }
    
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE ... id IN (1, 2, 3)
    ///     let request = try Player...filter(rawKeys: [1, 2, 3])
    ///
    /// - parameter keys: A collection of primary keys
    func filter<Keys>(rawKeys: Keys) -> Self
    where Keys: Sequence, Keys.Element: DatabaseValueConvertible
    {
        // Don't bother removing NULLs. We'd lose CPU cycles, and this does not
        // change the SQLite results anyway.
        let expressions = rawKeys.map {
            $0.databaseValue.sqlExpression
        }
        
        if expressions.isEmpty {
            // Don't hit the database
            return none()
        }
        
        let databaseTableName = self.databaseTableName
        return filterWhenConnected { db in
            let primaryKey = try db.primaryKey(databaseTableName)
            GRDBPrecondition(
                primaryKey.columns.count == 1,
                "Requesting by key requires a single-column primary key in the table \(databaseTableName)")
            return SQLCollection.array(expressions).contains(Column(primaryKey.columns[0]).sqlExpression)
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
    public func filter(key: [String: (any DatabaseValueConvertible)?]?) -> Self {
        guard let key else {
            return none()
        }
        return filter(keys: [key])
    }
    
    /// Creates a request filtered by unique key.
    ///
    ///     // SELECT * FROM player WHERE ... email = 'arthur@example.com' AND ...
    ///     let request = try Player...filter(keys: [["email": "arthur@example.com"], ...])
    ///
    /// When executed, this request raises a fatal error if there is no unique
    /// index on the key columns.
    ///
    /// - parameter keys: A collection of unique keys
    public func filter(keys: [[String: (any DatabaseValueConvertible)?]]) -> Self {
        if keys.isEmpty {
            return none()
        }
        
        let databaseTableName = self.databaseTableName
        return filterWhenConnected { db in
            try keys
                .map { key in
                    // Prevent filter(keys: [["foo": 1, "bar": 2]]) where
                    // ("foo", "bar") do not contain a unique key (primary key
                    // or unique index).
                    guard let columns = try db.columnsForUniqueKey(key.keys, in: databaseTableName) else {
                        fatalError("""
                            table \(databaseTableName) has no unique key on column(s) \
                            \(key.keys.sorted().joined(separator: ", "))
                            """)
                    }
                    
                    let lowercaseColumns = columns.map { $0.lowercased() }
                    return key
                        // Preserve ordering of columns in the unique index
                        .sorted { (kv1, kv2) in
                            guard let index1 = lowercaseColumns.firstIndex(of: kv1.key.lowercased()) else {
                                // We allow extra columns which are not in the unique key
                                // Put them last in the query
                                return false
                            }
                            guard let index2 = lowercaseColumns.firstIndex(of: kv2.key.lowercased()) else {
                                // We allow extra columns which are not in the unique key
                                // Put them last in the query
                                return true
                            }
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
      Self: TypedRequest,
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
    public func filter<IDS>(ids: IDS) -> Self
    where IDS: Collection, IDS.Element == RowDecoder.ID
    {
        filter(keys: ids)
    }
}

extension TableRequest where Self: OrderedRequest {
    /// Creates a request ordered by primary key.
    public func orderByPrimaryKey() -> Self {
        let tableName = self.databaseTableName
        return orderWhenConnected { db in
            try db.primaryKey(tableName).columns.map(SQLExpression.column)
        }
    }
}

extension TableRequest where Self: AggregatingRequest {
    /// Creates a request grouped by primary key.
    public func groupByPrimaryKey() -> Self {
        let tableName = self.databaseTableName
        return groupWhenConnected { db in
            let primaryKey = try db.primaryKey(tableName)
            if let rowIDColumn = primaryKey.rowIDColumn {
                // Prefer the user-provided name of the rowid:
                //
                //  // CREATE TABLE player (id INTEGER PRIMARY KEY, ...)
                //  // SELECT * FROM player GROUP BY id
                //  Player.all().groupByPrimaryKey()
                return [Column(rowIDColumn)]
            } else if primaryKey.tableHasRowID {
                // Prefer the rowid
                //
                //  // CREATE TABLE player (uuid TEXT NOT NULL PRIMARY KEY, ...)
                //  // SELECT * FROM player GROUP BY rowid
                //  Player.all().groupByPrimaryKey()
                return [.rowID]
            } else {
                // WITHOUT ROWID table: group by primary key columns
                //
                //  // CREATE TABLE player (uuid TEXT NOT NULL PRIMARY KEY, ...) WITHOUT ROWID
                //  // SELECT * FROM player GROUP BY uuid
                //  Player.all().groupByPrimaryKey()
                return primaryKey.columns.map { Column($0) }
            }
        }
    }
}

// MARK: - AggregatingRequest

/// The protocol for all requests that can aggregate.
public protocol AggregatingRequest {
    /// Creates a request grouped according to *expressions promise*.
    func groupWhenConnected(_ expressions: @escaping (Database) throws -> [any SQLExpressible]) -> Self
    
    /// Creates a request with the provided *predicate promise* added to the
    /// eventual set of already applied predicates.
    func havingWhenConnected(_ predicate: @escaping (Database) throws -> any SQLExpressible) -> Self
}

extension AggregatingRequest {
    /// Creates a request grouped according to *expressions*.
    public func group(_ expressions: [any SQLExpressible]) -> Self {
        groupWhenConnected { _ in expressions }
    }
    
    /// Creates a request grouped according to *expressions*.
    public func group(_ expressions: any SQLExpressible...) -> Self {
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
    public func having(_ predicate: some SQLExpressible) -> Self {
        havingWhenConnected { _ in predicate }
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
    ///         .orderWhenConnected{ _ in [Column("email")] }
    ///         .reversed()
    ///         .orderWhenConnected{ _ in [Column("name")] }
    func orderWhenConnected(_ orderings: @escaping (Database) throws -> [any SQLOrderingTerm]) -> Self
    
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
    public func order(_ orderings: any SQLOrderingTerm...) -> Self {
        orderWhenConnected { _ in orderings }
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
    public func order(_ orderings: [any SQLOrderingTerm]) -> Self {
        orderWhenConnected { _ in orderings }
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
public protocol JoinableRequest<RowDecoder>: TypedRequest, _JoinableRequest { }

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

extension JoinableRequest where Self: SelectionRequest {
    /// Creates a request which appends *columns of an associated record* to
    /// the current selection.
    ///
    ///     // SELECT player.*, team.color
    ///     // FROM player LEFT JOIN team ...
    ///     let teamColor = Player.team.select(Column("color"))
    ///     let request = Player.all().annotated(withOptional: teamColor)
    ///
    /// This method performs the same SQL request as `including(optional:)`.
    /// The difference is in the shape of Decodable records that decode such
    /// a request: the associated columns can be decoded at the same level as
    /// the main record:
    ///
    ///     struct PlayerWithTeamColor: FetchableRecord, Decodable {
    ///         var player: Player
    ///         var color: String?
    ///     }
    ///     let players = try dbQueue.read { db in
    ///         try request
    ///             .asRequest(of: PlayerWithTeamColor.self)
    ///             .fetchAll(db)
    ///     }
    ///
    /// Note: this is a convenience method. You can build the same request with
    /// `TableAlias`, `annotated(with:)`, and `joining(optional:)`:
    ///
    ///     let teamAlias = TableAlias()
    ///     let request = Player.all()
    ///         .annotated(with: teamAlias[Column("color")])
    ///         .joining(optional: Player.team.aliased(teamAlias))
    public func annotated<A: Association>(withOptional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        // TODO: find a way to prefix the selection with the association key
        let alias = TableAlias()
        let selection = association._sqlAssociation.destination.relation.selectionPromise
        return self
            .joining(optional: association.aliased(alias))
            .annotatedWhenConnected(with: { db in
                try selection.resolve(db).map { selection in
                    selection.qualified(with: alias)
                }
            })
    }
    
    /// Creates a request which appends *columns of an associated record* to
    /// the current selection.
    ///
    ///     // SELECT player.*, team.color
    ///     // FROM player JOIN team ...
    ///     let teamColor = Player.team.select(Column("color"))
    ///     let request = Player.all().annotated(withRequired: teamColor)
    ///
    /// This method performs the same SQL request as `including(required:)`.
    /// The difference is in the shape of Decodable records that decode such
    /// a request: the associated columns can be decoded at the same level as
    /// the main record:
    ///
    ///     struct PlayerWithTeamColor: FetchableRecord, Decodable {
    ///         var player: Player
    ///         var color: String
    ///     }
    ///     let players = try dbQueue.read { db in
    ///         try request
    ///             .asRequest(of: PlayerWithTeamColor.self)
    ///             .fetchAll(db)
    ///     }
    ///
    /// Note: this is a convenience method. You can build the same request with
    /// `TableAlias`, `annotated(with:)`, and `joining(required:)`:
    ///
    ///     let teamAlias = TableAlias()
    ///     let request = Player.all()
    ///         .annotated(with: teamAlias[Column("color")])
    ///         .joining(required: Player.team.aliased(teamAlias))
    public func annotated<A: Association>(withRequired association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        // TODO: find a way to prefix the selection with the association key
        let selection = association._sqlAssociation.destination.relation.selectionPromise
        let alias = TableAlias()
        return self
            .joining(required: association.aliased(alias))
            .annotatedWhenConnected(with: { db in
                try selection.resolve(db).map { selection in
                    selection.qualified(with: alias)
                }
            })
    }
}

// MARK: - DerivableRequest

/// The base protocol for all requests that can be refined.
public protocol DerivableRequest<RowDecoder>: AggregatingRequest, FilteredRequest,
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

// Association aggregates don't require all DerivableRequest abilities. The
// minimum set of requirements is:
//
// - AggregatingRequest, for the GROUP BY and HAVING clauses
// - TableRequest, for grouping by primary key
// - JoinableRequest, for joining associations
// - SelectionRequest, for annotating the selection
//
// It is just that extending DerivableRequest is simpler. We want the user to
// use aggregates on QueryInterfaceRequest and associations: both conform to
// DerivableRequest already.
extension DerivableRequest {
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
    ///     // SELECT team.*, COUNT(DISTINCT player.id) AS playerCount
    ///     // FROM team LEFT JOIN player ...
    ///     var request = Team.all()
    ///     request = request.annotated(with: Team.players.count)
    public func annotated(with aggregates: AssociationAggregate<RowDecoder>...) -> Self {
        annotated(with: aggregates)
    }
    
    /// Creates a request which appends *aggregates* to the current selection.
    ///
    ///     // SELECT team.*, COUNT(DISTINCT player.id) AS playerCount
    ///     // FROM team LEFT JOIN player ...
    ///     var request = team.all()
    ///     request = request.annotated(with: [Team.players.count])
    public func annotated(with aggregates: [AssociationAggregate<RowDecoder>]) -> Self {
        aggregates.reduce(self) { request, aggregate in
            request.annotated(with: aggregate)
        }
    }
    
    /// Creates a request which appends the provided aggregate *predicate* to
    /// the eventual set of already applied predicates.
    ///
    ///     // SELECT team.*
    ///     // FROM team LEFT JOIN player ...
    ///     // HAVING COUNT(DISTINCT player.id) = 0
    ///     var request = Team.all()
    ///     request = request.having(Team.players.isEmpty)
    public func having(_ predicate: AssociationAggregate<RowDecoder>) -> Self {
        var request = self
        let expression = predicate.prepare(&request)
        return request.having(expression)
    }
}
