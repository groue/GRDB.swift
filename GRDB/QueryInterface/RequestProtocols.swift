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
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(Column("email") == "arthur@example.com")
    func filter(_ predicate: SQLExpressible) -> Self
    
    /// Creates a request that matches nothing.
    ///
    ///     // SELECT * FROM players WHERE 0
    ///     var request = Player.all()
    ///     request = request.none()
    func none() -> Self
}

extension FilteredRequest {
    /// Creates a request with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    ///
    ///     // SELECT * FROM players WHERE email = 'arthur@example.com'
    ///     var request = Player.all()
    ///     request = request.filter(sql: "email = ?", arguments: ["arthur@example.com"])
    public func filter(sql: String, arguments: StatementArguments? = nil) -> Self {
        return filter(SQLExpressionLiteral(sql, arguments: arguments))
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
