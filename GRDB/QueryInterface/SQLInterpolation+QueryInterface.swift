extension SQLInterpolation {
    
    // MARK: - TableRecord
    
    /// Appends the table name of the record type.
    ///
    ///     // SELECT * FROM player
    ///     let request: SQLRequest<Player> = "SELECT * FROM \(Player.self)"
    public mutating func appendInterpolation(_ table: (some TableRecord).Type) {
        appendLiteral(table.databaseTableName.quotedDatabaseIdentifier)
    }
    
    /// Appends the table name of the record type.
    ///
    ///     // SELECT * FROM player
    ///     let request: SQLRequest<Player> = "SELECT * FROM \(Player.self)"
    @_disfavoredOverload
    public mutating func appendInterpolation(_ table: any TableRecord.Type) {
        appendLiteral(table.databaseTableName.quotedDatabaseIdentifier)
    }
    
    /// Appends the table name.
    ///
    ///     // SELECT * FROM player
    ///     let playerTable = Table("player")
    ///     let request: SQLRequest<Player> = "SELECT * FROM \(playerTable)"
    @_disfavoredOverload
    public mutating func appendInterpolation<T>(_ table: Table<T>) {
        appendLiteral(table.tableName.quotedDatabaseIdentifier)
    }
    
    /// Appends the table name of the record.
    ///
    ///     // INSERT INTO player ...
    ///     let player: Player = ...
    ///     let request: SQLRequest<Player> = "INSERT INTO \(tableOf: player) ..."
    public mutating func appendInterpolation(tableOf record: some TableRecord) {
        appendInterpolation(type(of: record))
    }
    
    /// Appends the table name of the record.
    ///
    ///     // INSERT INTO player ...
    ///     let player: Player = ...
    ///     let request: SQLRequest<Player> = "INSERT INTO \(tableOf: player) ..."
    @_disfavoredOverload
    public mutating func appendInterpolation(tableOf record: any TableRecord) {
        appendInterpolation(type(of: record))
    }
    
    /// Appends the selection of the record type.
    ///
    ///     // SELECT * FROM player
    ///     let player: Player = ...
    ///     let request: SQLRequest<Player> = "SELECT \(columnsOf: Player.self) FROM player"
    ///
    ///     // SELECT p.* FROM player p
    ///     let player: Player = ...
    ///     let request: SQLRequest<Player> = "SELECT \(columnsOf: Player.self, tableAlias: "p") FROM player p"
    public mutating func appendInterpolation(columnsOf recordType: (some TableRecord).Type, tableAlias: String? = nil) {
        let alias = TableAlias(name: tableAlias ?? recordType.databaseTableName)
        elements.append(contentsOf: recordType.databaseSelection
                            .map { CollectionOfOne(.selection($0.sqlSelection.qualified(with: alias))) }
                            .joined(separator: CollectionOfOne(.sql(", "))))
    }
    
    // MARK: - SQLSelectable
    
    /// Appends the selectable SQL.
    ///
    ///     // SELECT * FROM player
    ///     let request: SQLRequest<Player> = """
    ///         SELECT \(AllColumns()) FROM player
    ///         """
    public mutating func appendInterpolation(_ selection: some SQLSelectable) {
        elements.append(.selection(selection.sqlSelection))
    }
    
    /// Appends the selectable SQL, or NULL if it is nil.
    ///
    ///     // SELECT * FROM player
    ///     let request: SQLRequest<Player> = """
    ///         SELECT \(AllColumns()) FROM player
    ///         """
    @_disfavoredOverload
    public mutating func appendInterpolation(_ selection: (any SQLSelectable)?) {
        if let selection {
            elements.append(.selection(selection.sqlSelection))
        } else {
            appendLiteral("NULL")
        }
    }
    
    // MARK: - SQLOrderingTerm
    
    /// Appends the ordering SQL.
    ///
    ///     // SELECT name FROM player ORDER BY name DESC
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player ORDER BY \(Column("name").desc)
    ///         """
    public mutating func appendInterpolation(_ orderingTerm: some SQLOrderingTerm) {
        elements.append(.ordering(orderingTerm.sqlOrdering))
    }
    
    /// Appends the ordering SQL.
    ///
    ///     // SELECT name FROM player ORDER BY name DESC
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player ORDER BY \(Column("name").desc)
    ///         """
    @_disfavoredOverload
    public mutating func appendInterpolation(_ orderingTerm: any SQLOrderingTerm) {
        elements.append(.ordering(orderingTerm.sqlOrdering))
    }
    
    // MARK: - SQLExpressible
    
    /// Appends the expression SQL.
    ///
    ///     // SELECT name FROM player
    ///     let request: SQLRequest<String> = """
    ///         SELECT \(Column("name")) FROM player
    ///         """
    public mutating func appendInterpolation(_ expressible: some SQLExpressible
                                                               & SQLSelectable
                                                               & SQLOrderingTerm)
    {
        elements.append(.expression(expressible.sqlExpression))
    }
    
    /// Appends the expression SQL, or NULL if it is nil.
    ///
    ///     // SELECT name FROM player
    ///     let request: SQLRequest<String> = """
    ///         SELECT \(Column("name")) FROM player
    ///         """
    @_disfavoredOverload
    public mutating func appendInterpolation(_ expressible: (any SQLExpressible)?) {
        if let expressible {
            elements.append(.expression(expressible.sqlExpression))
        } else {
            appendLiteral("NULL")
        }
    }
    
    // MARK: - CodingKey
    
    /// Appends the name of the coding key.
    ///
    ///     // SELECT name FROM player
    ///     let request: SQLRequest<String> = "
    ///         SELECT \(CodingKey.name) FROM player
    ///         """
    public mutating func appendInterpolation(_ key: some CodingKey) {
        appendInterpolation(Column(key.stringValue))
    }
    
    /// Appends the name of the coding key.
    ///
    ///     // SELECT name FROM player
    ///     let request: SQLRequest<String> = "
    ///         SELECT \(CodingKey.name) FROM player
    ///         """
    public mutating func appendInterpolation(_ key: some CodingKey
                                                       & SQLExpressible
                                                       & SQLSelectable
                                                       & SQLOrderingTerm)
    {
        appendInterpolation(Column(key.stringValue))
    }
    
    /// Appends the name of the coding key.
    ///
    ///     // SELECT name FROM player
    ///     let request: SQLRequest<String> = "
    ///         SELECT \(CodingKey.name) FROM player
    ///         """
    @_disfavoredOverload
    public mutating func appendInterpolation(_ key: any CodingKey) {
        appendInterpolation(Column(key.stringValue))
    }
    
    // MARK: - FetchRequest
    
    /// Appends the request SQL (not wrapped inside parentheses).
    ///
    ///     let subquery = Player.select(max(Column("score")))
    ///     // or
    ///     let subQuery: SQLRequest<Int> = "SELECT MAX(score) FROM player"
    ///
    ///     // SELECT name FROM player WHERE score = (SELECT MAX(score) FROM player)
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE score = (\(subquery))
    ///         """
    public mutating func appendInterpolation(_ subquery: some SQLSubqueryable
                                                            & SQLExpressible
                                                            & SQLSelectable
                                                            & SQLOrderingTerm)
    {
        elements.append(.subquery(subquery.sqlSubquery))
    }
    
    // MARK: - Sequence
    
    /// Appends a sequence of expressions, wrapped in parentheses.
    ///
    ///     // SELECT * FROM player WHERE id IN (?,?,?)
    ///     let ids = [1, 2, 3]
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE id IN \(ids)
    ///         """
    ///
    /// If the sequence is empty, an empty subquery is appended:
    ///
    ///     // SELECT * FROM player WHERE id IN (SELECT NULL WHERE NULL)
    ///     let ids: [Int] = []
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE id IN \(ids)
    ///         """
    public mutating func appendInterpolation<S>(_ sequence: S)
    where S: Sequence, S.Element: SQLExpressible
    {
        let e: [SQL.Element] = sequence.map { .expression($0.sqlExpression) }
        if e.isEmpty {
            appendLiteral("(SELECT NULL WHERE NULL)")
        } else {
            appendLiteral("(")
            elements.append(contentsOf: e.map(CollectionOfOne.init(_:)).joined(separator: CollectionOfOne(.sql(","))))
            appendLiteral(")")
        }
    }
    
    /// Appends a sequence of expressions, wrapped in parentheses.
    ///
    ///     // SELECT * FROM player WHERE a IN (b, c + 2)
    ///     let expressions = [Column("b"), Column("c") + 2]
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE a IN \(expressions)
    ///         """
    ///
    /// If the sequence is empty, an empty subquery is appended:
    ///
    ///     // SELECT * FROM player WHERE a IN (SELECT NULL WHERE NULL)
    ///     let expressions: [SQLExpression] = []
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE a IN \(expressions)
    ///         """
    public mutating func appendInterpolation<S>(_ sequence: S)
    where S: Sequence, S.Element == any SQLExpressible
    {
        appendInterpolation(sequence.lazy.map(\.sqlExpression))
    }
    
    // When a value is both an expression and a sequence of expressions,
    // favor the expression side. Use case: Foundation.Data interpolation.
    public mutating func appendInterpolation<S>(_ expressible: S)
    where S: SQLExpressible, S: Sequence, S.Element: SQLExpressible
    {
        elements.append(.expression(expressible.sqlExpression))
    }
    
    // MARK: - Common Table Expressions
    
    /// Appends the table name of the common table expression.
    ///
    ///     // WITH "cte" AS (...) SELECT * FROM "cte"
    ///     let cte = CommonTableExpression(named: "cte", ...)
    ///     let request: SQLRequest<Row> = """
    ///         WITH \(definitionFor: cte) SELECT * FROM \(cte)
    ///         """
    public mutating func appendInterpolation(_ cte: CommonTableExpression<some Any>) {
        elements.append(.sql(cte.tableName.quotedDatabaseIdentifier))
    }
    
    /// Appends the definition of the common table expression.
    ///
    ///     // WITH "cte" AS (...) SELECT * FROM "cte"
    ///     let cte = CommonTableExpression(named: "cte", ...)
    ///     let request: SQLRequest<Row> = """
    ///         WITH \(definitionFor: cte) SELECT * FROM \(cte)
    ///         """
    public mutating func appendInterpolation(definitionFor cte: CommonTableExpression<some Any>) {
        elements.append(.sql(cte.tableName.quotedDatabaseIdentifier))
        
        if let columns = cte.cte.columns, !columns.isEmpty {
            let columnsSQL = "("
                + columns.map(\.quotedDatabaseIdentifier).joined(separator: ", ")
                + ")"
            elements.append(.sql(columnsSQL))
        }
        
        elements.append(.sql(" AS ("))
        elements.append(.subquery(cte.cte.sqlSubquery))
        elements.append(.sql(")"))
    }
    
    // MARK: - Collations
    
    /// Appends the name of the collation.
    ///
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player
    ///         ORDER BY name COLLATING \(DatabaseCollation.localizedCaseInsensitiveCompare)
    ///         """
    public mutating func appendInterpolation(_ collation: DatabaseCollation) {
        elements.append(.sql(collation.name))
    }
    
    /// Appends the name of the collation.
    ///
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player
    ///         ORDER BY email COLLATING \(.nocase)
    ///         """
    public mutating func appendInterpolation(_ collation: Database.CollationName) {
        elements.append(.sql(collation.rawValue))
    }
}
