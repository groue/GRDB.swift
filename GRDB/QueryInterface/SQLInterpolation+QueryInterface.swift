#if swift(>=5.0)
/// :nodoc:
extension SQLInterpolation {
    /// Appends the table name of the record type.
    ///
    ///     // SELECT * FROM player
    ///     let request: SQLRequest<Player> = "SELECT * FROM \(Player.self)"
    public mutating func appendInterpolation<T: TableRecord>(_ table: T.Type) {
        sql += table.databaseTableName.quotedDatabaseIdentifier
    }
    
    /// Appends the table name of the record.
    ///
    ///     // INSERT INTO player ...
    ///     let player: Player = ...
    ///     let request: SQLRequest<Player> = "INSERT INTO \(tableOf: player) ..."
    public mutating func appendInterpolation<T: TableRecord>(tableOf record: T) {
        sql += type(of: record).databaseTableName.quotedDatabaseIdentifier
    }
    
    /// Appends the selectable SQL.
    ///
    ///     // SELECT * FROM player
    ///     let request: SQLRequest<Player> = """
    ///         SELECT \(AllColumns()) FROM player
    ///         """
    public mutating func appendInterpolation(_ selection: SQLSelectable) {
        sql += selection.resultColumnSQL(&context)
    }
    
    /// Appends the expression SQL.
    ///
    ///     // SELECT name FROM player
    ///     let request: SQLRequest<String> = """
    ///         SELECT \(Column("name")) FROM player
    ///         """
    public mutating func appendInterpolation(_ expressible: SQLExpressible & SQLSelectable & SQLOrderingTerm) {
        sql += expressible.sqlExpression.expressionSQL(&context)
    }
    
    /// Appends the name of the coding key.
    ///
    ///     // SELECT name FROM player
    ///     let request: SQLRequest<String> = "
    ///         SELECT \(CodingKey.name) FROM player
    ///         """
    public mutating func appendInterpolation(_ codingKey: SQLExpressible & SQLSelectable & SQLOrderingTerm & CodingKey) {
        sql += codingKey.sqlExpression.expressionSQL(&context)
    }
    
    /// Appends the expression SQL, or NULL if it is nil.
    ///
    ///     // SELECT score + ? FROM player
    ///     let bonus = 1000
    ///     let request: SQLRequest<Int> = """
    ///         SELECT score + \(bonus) FROM player
    ///         """
    public mutating func appendInterpolation<T: SQLExpressible>(_ expressible: T?) {
        if let expressible = expressible {
            sql += expressible.sqlExpression.expressionSQL(&context)
        } else {
            sql += "NULL"
        }
    }
    
    /// Appends the name of the coding key.
    ///
    ///     // SELECT name FROM player
    ///     let request: SQLRequest<String> = """
    ///         SELECT \(CodingKey.name) FROM player
    ///         """
    public mutating func appendInterpolation(_ codingKey: CodingKey) {
        appendInterpolation(Column(codingKey.stringValue))
    }
    
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
    public mutating func appendInterpolation<S>(_ sequence: S) where S: Sequence, S.Element: SQLExpressible {
        appendInterpolation(sequence.lazy.map { $0.sqlExpression })
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
    public mutating func appendInterpolation<S>(_ sequence: S) where S: Sequence, S.Element == SQLExpression {
        sql += "("
        var first = true
        for element in sequence {
            if first {
                first = false
            } else {
                sql += ","
            }
            appendInterpolation(element)
        }
        if first {
            sql += "SELECT NULL WHERE NULL"
        }
        sql += ")"
    }
    
    /// Appends the ordering SQL.
    ///
    ///     // SELECT name FROM player ORDER BY name DESC
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player ORDER BY \(Column("name").desc)
    ///         """
    public mutating func appendInterpolation(_ ordering: SQLOrderingTerm) {
        sql += ordering.orderingTermSQL(&context)
    }

    /// Appends the request SQL, wrapped in parentheses
    ///
    ///     // SELECT name FROM player WHERE score = (SELECT MAX(score) FROM player)
    ///     let subQuery: SQLRequest<Int> = "SELECT MAX(score) FROM player"
    ///     let request: SQLRequest<Player> = """
    ///         SELECT * FROM player WHERE score = \(subQuery)
    ///         """
    public mutating func appendInterpolation<T>(_ request: SQLRequest<T>) {
        sql += "(" + request.sql + ")"
        arguments += request.arguments
    }
}
#endif
