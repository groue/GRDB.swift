// MARK: - SelectionRequest

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The protocol for all requests that can refine their selection.
///
/// :nodoc:
public protocol SelectionRequest {
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
    func select(_ selection: [SQLSelectable]) -> Self
}

/// :nodoc:
extension SelectionRequest {
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
        return select(selection)
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
        return select(literal: SQLLiteral(sql: sql, arguments: arguments))
    }
    
    /// Creates a request which selects an SQL *literal*.
    ///
    ///     // SELECT id, email, score + 1000 FROM player
    ///     let bonus = 1000
    ///     var request = Player.all()
    ///     request = request.select(literal: SQLLiteral(sql: """
    ///         id, email, score + ?
    ///         """, arguments: [bonus]))
    ///
    /// With Swift 5, you can safely embed raw values in your SQL queries,
    /// without any risk of syntax errors or SQL injection:
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
    ///         .select(literal: SQLLiteral(sql: "email"))
    public func select(literal sqlLiteral: SQLLiteral) -> Self {
        // NOT TESTED
        return select(SQLSelectionLiteral(literal: sqlLiteral))
    }
}

// MARK: - FilteredRequest

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The protocol for all requests that can be filtered.
///
/// :nodoc:
public protocol FilteredRequest {
    /// Creates a request with the provided *predicate promise* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM player WHERE 1
    ///     var request = Player.all()
    ///     request = request.filter { db in true }
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> Self
    
    /// Creates a request which expects a single result.
    ///
    /// Requests expecting a single result may ignore the second parameter of
    /// the `FetchRequest.prepare(_:forSingleResult:)` method, in order to
    /// produce sharply tailored SQL.
    ///
    /// This method has a default implementation which returns self.
    func expectingSingleResult() -> Self
}

/// :nodoc:
extension FilteredRequest {
    public func expectingSingleResult() -> Self {
        return self
    }
    
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(Column("email") == "arthur@example.com")
    public func filter(_ predicate: SQLExpressible) -> Self {
        return filter { _ in predicate }
    }
    
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    public func filter(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        return filter(literal: SQLLiteral(sql: sql, arguments: arguments))
    }
    
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM player WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(literal: SQLLiteral(sql: """
    ///         email = ?
    ///         """, arguments: ["arthur@example.com"])
    ///
    /// With Swift 5, you can safely embed raw values in your SQL queries,
    /// without any risk of syntax errors or SQL injection:
    ///
    ///     var request = Player.all()
    ///     request = request.filter(literal: "name = \("O'Brien")")
    public func filter(literal sqlLiteral: SQLLiteral) -> Self {
        // NOT TESTED
        return filter(SQLExpressionLiteral(literal: sqlLiteral))
    }

    /// Creates a request that matches nothing.
    ///
    ///     // SELECT * FROM player WHERE 0
    ///     var request = Player.all()
    ///     request = request.none()
    public func none() -> Self {
        return filter(false)
    }
}

// MARK: - TableRequest {

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The protocol for all requests that feed from a database table
///
/// :nodoc:
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

/// :nodoc:
extension TableRequest where Self: FilteredRequest {
    
    /// Creates a request with the provided primary key *predicate*.
    public func filter<PrimaryKeyType: DatabaseValueConvertible>(key: PrimaryKeyType?) -> Self {
        guard let key = key else {
            return none()
        }
        return filter(keys: [key])
    }
    
    /// Creates a request with the provided primary key *predicate*.
    public func filter<Sequence: Swift.Sequence>(keys: Sequence) -> Self where Sequence.Element: DatabaseValueConvertible {
        var request = self
        let keys = Array(keys)
        let makePredicate: (Column) -> SQLExpression
        switch keys.count {
        case 0:
            return none()
        case 1:
            request = request.expectingSingleResult()
            makePredicate = { $0 == keys[0] }
        default:
            makePredicate = { keys.contains($0) }
        }
        
        let databaseTableName = self.databaseTableName
        return request.filter { db in
            let primaryKey = try db.primaryKey(databaseTableName)
            GRDBPrecondition(
                primaryKey.columns.count == 1,
                "Requesting by key requires a single-column primary key in the table \(databaseTableName)")
            return makePredicate(Column(primaryKey.columns[0]))
        }
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    /// When executed, this request raises a fatal error if there is no unique
    /// index on the key columns.
    public func filter(key: [String: DatabaseValueConvertible?]?) -> Self {
        guard let key = key else {
            return none()
        }
        return filter(keys: [key])
    }
    
    /// Creates a request with the provided primary key *predicate*.
    ///
    /// When executed, this request raises a fatal error if there is no unique
    /// index on the key columns.
    public func filter(keys: [[String: DatabaseValueConvertible?]]) -> Self {
        var request = self
        switch keys.count {
        case 0:
            return none()
        case 1:
            request = request.expectingSingleResult()
        default:
            break
        }
        
        let databaseTableName = self.databaseTableName
        return request.filter { db in
            try keys
                .map { key in
                    // Prevent filter(keys: [["foo": 1, "bar": 2]]) where
                    // ("foo", "bar") is not a unique key (primary key or columns of a
                    // unique index)
                    guard let columns = try db.columnsForUniqueKey(key.keys, in: databaseTableName) else {
                        fatalError("table \(databaseTableName) has no unique index on column(s) \(key.keys.sorted().joined(separator: ", "))")
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

/// :nodoc:
extension TableRequest where Self: OrderedRequest {
    /// Creates a request ordered by primary key.
    public func orderByPrimaryKey() -> Self {
        let tableName = self.databaseTableName
        return order { db in
            try db.primaryKey(tableName).columns.map { Column($0) }
        }
    }
}

/// :nodoc:
extension TableRequest where Self: AggregatingRequest {
    /// Creates a request grouped by primary key.
    public func groupByPrimaryKey() -> Self {
        let tableName = self.databaseTableName
        return group { db in
            try db.primaryKey(tableName).columns.map { Column($0) }
        }
    }
}

// MARK: - AggregatingRequest

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The protocol for all requests that can aggregate.
///
/// :nodoc:
public protocol AggregatingRequest {
    /// Creates a request grouped according to *expressions promise*.
    func group(_ expressions: @escaping (Database) throws -> [SQLExpressible]) -> Self
    
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    func having(_ predicate: SQLExpressible) -> Self
}

/// :nodoc:
extension AggregatingRequest {
    /// Creates a request grouped according to *expressions*.
    public func group(_ expressions: [SQLExpressible]) -> Self {
        return group { _ in expressions }
    }
    
    /// Creates a request grouped according to *expressions*.
    public func group(_ expressions: SQLExpressible...) -> Self {
        return group(expressions)
    }
    
    /// Creates a request with a new grouping.
    public func group(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        return group(literal: SQLLiteral(sql: sql, arguments: arguments))
    }
    
    /// Creates a request with a new grouping.
    public func group(literal sqlLiteral: SQLLiteral) -> Self {
        // NOT TESTED
        // This "expression" is not a real expression. We support raw sql which
        // actually contains several expressions:
        //
        //   request = Player.group(sql: "teamId, level")
        //
        // This is why we use the "unsafeLiteral" initializer, so that the
        // SQLExpressionLiteral does not wrap input in parentheses, and
        // generates invalid SQL `GROUP BY (teamId, level)`.
        return group(SQLExpressionLiteral(unsafeLiteral: sqlLiteral))
    }

    /// Creates a request with the provided *sql* added to the
    /// eventual set of already applied predicates.
    public func having(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        return having(literal: SQLLiteral(sql: sql, arguments: arguments))
    }

    /// Creates a request with the provided *sql* added to the
    /// eventual set of already applied predicates.
    public func having(literal sqlLiteral: SQLLiteral) -> Self {
        // NOT TESTED
        return having(SQLExpressionLiteral(literal: sqlLiteral))
    }
}

// MARK: - OrderedRequest

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The protocol for all requests that be ordered.
///
/// :nodoc:
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
}

/// :nodoc:
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
        return order { _ in orderings }
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
        return order { _ in orderings }
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
        return order(literal: SQLLiteral(sql: sql, arguments: arguments))
    }
    
    /// Creates a request sorted according to an SQL *literal*.
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
    public func order(literal sqlLiteral: SQLLiteral) -> Self {
        // NOT TESTED
        // This "expression" is not a real expression. We support raw sql which
        // actually contains several expressions:
        //
        //   request = Player.order(sql: "teamId, level")
        //
        // This is why we use the "unsafeLiteral" initializer, so that the
        // SQLExpressionLiteral does not wrap input in parentheses, and
        // generates invalid SQL `ORDER BY (teamId, level)`.
        return order(SQLExpressionLiteral(unsafeLiteral: sqlLiteral))
    }
}

// MARK: - DerivableRequest

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The base protocol for all requests that can be refined.
///
/// :nodoc:
public protocol DerivableRequest: SelectionRequest, FilteredRequest, OrderedRequest {
    associatedtype RowDecoder
}
