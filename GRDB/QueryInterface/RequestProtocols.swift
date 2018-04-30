// MARK: - SelectionRequest

/// The protocol for all requests that can refine their selection.
public protocol SelectionRequest {
    /// Creates a request with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM players
    ///     var request = Player.all()
    ///     request = request.select([Column("id"), Column("email")])
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM players
    ///     request
    ///         .select([Column("id")])
    ///         .select([Column("email")])
    func select(_ selection: [SQLSelectable]) -> Self
}

extension SelectionRequest {
    /// Creates a request with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM players
    ///     var request = Player.all()
    ///     request = request.select(Column("id"), Column("email"))
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM players
    ///     request
    ///         .select(Column("id"))
    ///         .select(Column("email"))
    public func select(_ selection: SQLSelectable...) -> Self {
        return select(selection)
    }
    
    /// Creates a request with a new net of selected columns.
    ///
    ///     // SELECT id, email FROM players
    ///     var request = Player.all()
    ///     request = request.select(sql: "id, email")
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT email FROM players
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
    ///     // SELECT * FROM players WHERE 1
    ///     var request = Player.all()
    ///     request = request.filter { db in true }
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> Self
}

extension FilteredRequest {
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(Column("email") == "arthur@example.com")
    public func filter(_ predicate: SQLExpressible) -> Self {
        return filter { _ in predicate }
    }
    
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    public func filter(sql: String, arguments: StatementArguments? = nil) -> Self {
        return filter(SQLExpressionLiteral(sql, arguments: arguments))
    }
    
    /// Creates a request that matches nothing.
    ///
    ///     // SELECT * FROM players WHERE 0
    ///     var request = Player.all()
    ///     request = request.none()
    public func none() -> Self {
        return filter(false)
    }
}

// MARK: - TableRequest {

/// The protocol for all requests that feed from a database table
public protocol TableRequest {
    var databaseTableName: String { get }
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
                    guard let orderedColumns = try db.columnsForUniqueKey(key.keys, in: databaseTableName) else {
                        fatalError("table \(databaseTableName) has no unique index on column(s) \(key.keys.sorted().joined(separator: ", "))")
                    }
                    
                    let lowercaseOrderedColumns = orderedColumns.map { $0.lowercased() }
                    return key
                        // Sort key columns in the same order as the unique index
                        .sorted { (kv1, kv2) in
                            let index1 = lowercaseOrderedColumns.index(of: kv1.key.lowercased())!
                            let index2 = lowercaseOrderedColumns.index(of: kv2.key.lowercased())!
                            return index1 < index2
                        }
                        .map { (column, value) in Column(column) == value }
                        .joined(operator: .and)
                }
                .joined(operator: .or)
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
    /// Creates a request with the provided *orderings*.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order([Column("name")])
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     request
    ///         .order([Column("email")])
    ///         .reversed()
    ///         .order([Column("name")])
    func order(_ orderings: [SQLOrderingTerm]) -> Self
    
    /// Creates a request that reverses applied orderings. If no ordering
    /// was applied, the returned request is identical.
    ///
    ///     // SELECT * FROM players ORDER BY name DESC
    ///     var request = Player.all().order(Column("name"))
    ///     request = request.reversed()
    ///
    ///     // SELECT * FROM players
    ///     var request = Player.all()
    ///     request = request.reversed()
    func reversed() -> Self
}

extension OrderedRequest {
    /// Creates a request with the provided *orderings*.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order(Column("name"))
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     request
    ///         .order(Column("email"))
    ///         .reversed()
    ///         .order(Column("name"))
    public func order(_ orderings: SQLOrderingTerm...) -> Self {
        return order(orderings)
    }
    
    /// Creates a request with the provided *sql* used for sorting.
    ///
    ///     // SELECT * FROM players ORDER BY name
    ///     var request = Player.all()
    ///     request = request.order(sql: "name")
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT * FROM players ORDER BY name
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
