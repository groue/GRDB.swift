/// The protocol for expressions that can be assigned in an UPDATE query.
public protocol SQLAssignable: SQLExpressible { }

/// An `Assignment` can update rows in the database.
///
/// You create an assignment from a column or a row value, and a method or
/// operator such as `set(to:)` or `+=`:
///
///     try dbQueue.write { db in
///         // UPDATE player SET score = 0
///         let assignment = Column("score").set(to: 0)
///         try Player.updateAll(db, assignment)
///     }
public struct Assignment {
    var assigned: SQLAssignable
    var value: SQLExpressible
    
    func sql(_ context: SQLGenerationContext) throws -> String {
        try assigned.sqlExpression.expressionSQL(context, wrappedInParenthesis: false) +
            " = " +
            value.sqlExpression.expressionSQL(context, wrappedInParenthesis: false)
    }
}

@available(*, deprecated, renamed: "Assignment")
public typealias ColumnAssignment = Assignment

extension SQLAssignable {
    /// Creates an assignment to a value.
    ///
    ///     Column("valid").set(to: true)
    ///     Column("score").set(to: 0)
    ///     Column("score").set(to: nil)
    ///     Column("score").set(to: Column("score") + Column("bonus"))
    ///
    ///     try dbQueue.write { db in
    ///         // UPDATE player SET score = 0
    ///         try Player.updateAll(db, Column("score").set(to: 0))
    ///     }
    public func set(to value: SQLExpressible?) -> Assignment {
        Assignment(assigned: self, value: value ?? DatabaseValue.null)
    }
}

/// Creates an assignment that adds a value
///
///     Column("score") += 1
///     Column("score") += Column("bonus")
///
///     try dbQueue.write { db in
///         // UPDATE player SET score = score + 1
///         try Player.updateAll(db, Column("score") += 1)
///     }
public func += (column: ColumnExpression, value: SQLExpressible) -> Assignment {
    column.set(to: column + value)
}

/// Creates an assignment that subtracts a value
///
///     Column("score") -= 1
///     Column("score") -= Column("bonus")
///
///     try dbQueue.write { db in
///         // UPDATE player SET score = score - 1
///         try Player.updateAll(db, Column("score") -= 1)
///     }
public func -= (column: ColumnExpression, value: SQLExpressible) -> Assignment {
    column.set(to: column - value)
}

/// Creates an assignment that multiplies by a value
///
///     Column("score") *= 2
///     Column("score") *= Column("factor")
///
///     try dbQueue.write { db in
///         // UPDATE player SET score = score * 2
///         try Player.updateAll(db, Column("score") *= 2)
///     }
public func *= (column: ColumnExpression, value: SQLExpressible) -> Assignment {
    column.set(to: column * value)
}

/// Creates an assignment that divides by a value
///
///     Column("score") /= 2
///     Column("score") /= Column("factor")
///
///     try dbQueue.write { db in
///         // UPDATE player SET score = score / 2
///         try Player.updateAll(db, Column("score") /= 2)
///     }
public func /= (column: ColumnExpression, value: SQLExpressible) -> Assignment {
    column.set(to: column / value)
}
