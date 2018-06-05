// MARK: - SelectionRequest

/// The protocol for all requests that can refine their selection.
public protocol SelectionRequest {
    /// Creates a request with a new set of selected columns.
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

extension SelectionRequest {
    /// Creates a request with a new set of selected columns.
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
    
    /// Creates a request with a new set of selected columns.
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
    public func select(sql: String, arguments: StatementArguments? = nil) -> Self {
        return select(SQLSelectionLiteral(sql, arguments: arguments))
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
    public func filter(sql: String, arguments: StatementArguments? = nil) -> Self {
        return filter(SQLExpressionLiteral(sql, arguments: arguments))
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
    
    /// Creates a request with the provided primary key *predicate*.
    public func filter<PrimaryKeyType: DatabaseValueConvertible>(key: PrimaryKeyType?) -> Self {
        guard let key = key else {
            return none()
        }
        return filter(keys: [key])
    }
    
    /// Creates a request with the provided primary key *predicate*.
    public func filter<Sequence: Swift.Sequence>(keys: Sequence) -> Self where Sequence.Element: DatabaseValueConvertible {
        let keys = Array(keys)
        let makePredicate: (Column) -> SQLExpression
        switch keys.count {
        case 0:
            return none()
        case 1:
            makePredicate = { $0 == keys[0] }
        default:
            makePredicate = { keys.contains($0) }
        }
        
        let databaseTableName = self.databaseTableName
        return filter { db in
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
        guard !keys.isEmpty else {
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
                        fatalError("table \(databaseTableName) has no unique index on column(s) \(key.keys.sorted().joined(separator: ", "))")
                    }
                    
                    let lowercaseColumns = columns.map { $0.lowercased() }
                    return key
                        // Preserve ordering of columns in the unique index
                        .sorted { (kv1, kv2) in
                            let index1 = lowercaseColumns.index(of: kv1.key.lowercased())!
                            let index2 = lowercaseColumns.index(of: kv2.key.lowercased())!
                            return index1 < index2
                        }
                        .map { (column, value) in Column(column) == value }
                        .joined(operator: .and)
                }
                .joined(operator: .or)
        }
    }
}

extension TableRequest where Self: OrderedRequest {
    /// Creates a request ordered by primary key.
    public func orderByPrimaryKey() -> Self {
        let tableName = self.databaseTableName
        return order { db in
            try db.primaryKey(tableName).columns.map { Column($0) }
        }
    }
}

// MARK: - AggregatingRequest

/// The protocol for all requests that can aggregate.
public protocol AggregatingRequest {
    /// Creates a request grouped according to *expressions*.
    func group(_ expressions: [SQLExpressible]) -> Self
    
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    func having(_ predicate: SQLExpressible) -> Self
}

extension AggregatingRequest {
    /// Creates a request grouped according to *expressions*.
    public func group(_ expressions: SQLExpressible...) -> Self {
        return group(expressions)
    }
    
    /// Creates a request with a new grouping.
    public func group(sql: String, arguments: StatementArguments? = nil) -> Self {
        // This "expression" is not a real expression. We support raw sql which
        // actually contains several expressions:
        //
        //   request = Player.group(sql: "teamId, level")
        //
        // This is why we use the "unsafe" flag, so that the SQLExpressionLiteral
        // does not output its safe wrapping parenthesis, and generates
        // invalid SQL.
        var expression = SQLExpressionLiteral(sql, arguments: arguments)
        expression.unsafeRaw = true
        return group(expression)
    }
    
    /// Creates a request with the provided *sql* added to the
    /// eventual set of already applied predicates.
    public func having(sql: String, arguments: StatementArguments? = nil) -> Self {
        return having(SQLExpressionLiteral(sql, arguments: arguments))
    }
}

// MARK: - OrderedRequest

/// The protocol for all requests that be ordered.
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
    
    /// Creates a request with the provided *sql* used for sorting.
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
    public func order(sql: String, arguments: StatementArguments? = nil) -> Self {
        // This "expression" is not a real expression. We support raw sql which
        // actually contains several expressions:
        //
        //   request = Player.order(sql: "teamId, level")
        //
        // This is why we use the "unsafe" flag, so that the SQLExpressionLiteral
        // does not output its safe wrapping parenthesis, and generates
        // invalid SQL.
        var expression = SQLExpressionLiteral(sql, arguments: arguments)
        expression.unsafeRaw = true
        return order([expression])
    }
}

// MARK: - DerivableRequest

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The base protocol for all requests that can be refined.
public protocol DerivableRequest: SelectionRequest, FilteredRequest, OrderedRequest {
    associatedtype RowDecoder
}
