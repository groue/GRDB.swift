/// Implementation details of `SQLSelectable`.
///
/// :nodoc:
public protocol _SQLSelectable {
    /// Returns the number of columns in the selectable.
    func _columnCount(_ db: Database) throws -> Int
    
    /// If the selectable can be counted, return how to count it.
    func _count(distinct: Bool) -> _SQLCount?
    
    /// Returns the SQL that feeds the argument of the `COUNT` function.
    ///
    /// For example:
    ///
    ///     COUNT(*)
    ///     COUNT(id)
    ///           ^---- countedSQL
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func _countedSQL(_ context: SQLGenerationContext) throws -> String
    
    /// Returns true if the selectable is an aggregate.
    ///
    /// When in doubt, returns false.
    ///
    ///     SELECT *              -- false
    ///     SELECT score          -- false
    ///     SELECT COUNT(*)       -- true
    ///     SELECT MAX(score)     -- true
    ///     SELECT MAX(score) + 1 -- true
    ///
    /// This method makes it possible to avoid inserting `LIMIT 1` to the SQL
    /// of some requests:
    ///
    ///     // SELECT MAX("score") FROM "player"
    ///     try Player.select(max(Column("score")), as: Int.self).fetchOne(db)
    ///
    ///     // SELECT "score" FROM "player" LIMIT 1
    ///     try Player.select(Column("score"), as: Int.self).fetchOne(db)
    var _isAggregate: Bool { get }
    
    /// Returns a qualified selectable
    func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable
    
    /// Returns the SQL that feeds the selection of a `SELECT` statement.
    ///
    /// For example:
    ///
    ///     1
    ///     name
    ///     COUNT(*)
    ///     (score + bonus) AS total
    ///
    /// See https://sqlite.org/syntax/result-column.html
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func _resultColumnSQL(_ context: SQLGenerationContext) throws -> String
}

/// SQLSelectable is the protocol for types that can be selected, as
/// described at https://www.sqlite.org/syntax/result-column.html
///
/// :nodoc:
public protocol SQLSelectable: _SQLSelectable { }

/// :nodoc:
public enum _SQLCount {
    /// Represents `COUNT(*)`
    case all
    
    /// Represents `COUNT(DISTINCT expression)`
    case distinct(SQLExpression)
}

extension SQLSelectable {
    /// :nodoc:
    public var _isAggregate: Bool { false }
}
