// MARK: - SQLSelectQuery

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
///
/// # Low Level Query Interface
///
/// SQLSelectQuery is the protocol for types that represent a full select query.
public protocol SQLSelectQuery : Request, SQLCollection {
    
    /// This function is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// Returns the SQL string of the select query.
    ///
    /// When the arguments parameter is nil, any value must be written down as
    /// a literal in the returned SQL.
    ///
    /// When the arguments parameter is not nil, then values may be replaced by
    /// `?` or colon-prefixed tokens, and fed into arguments.
    func selectQuerySQL(_ arguments: inout StatementArguments?) -> String
}

extension SQLSelectQuery {
    
    /// Returns an SQL expression that checks whether the receiver, as a
    /// subquery, returns any row.
    ///
    ///
    ///     let request = Person.all()
    ///     request.exists()   // EXISTS (SELECT * FROM persons)
    public func exists() -> SQLExpression {
        return SQLExpressionExists(self)
    }
}


// MARK: - SQLCollection adoption

extension SQLSelectQuery {
    
    /// This function is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// See SQLCollection.collectionSQL(_)
    public func collectionSQL(_ arguments: inout StatementArguments?) -> String {
        return selectQuerySQL(&arguments)
    }
}


// MARK: - Request adoption

extension SQLSelectQuery {
    
    /// A tuple that contains a prepared statement that is ready to be
    /// executed, and an eventual row adapter.
    public func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        var arguments: StatementArguments? = StatementArguments()
        let sql = self.selectQuerySQL(&arguments)
        let statement = try db.makeSelectStatement(sql)
        try statement.setArgumentsWithValidation(arguments!)
        return (statement, nil)
    }
}


// MARK: - QueryInterfaceSelectQueryDefinition

extension QueryInterfaceSelectQueryDefinition : SQLSelectQuery {
    /// This function is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// See SQLSelectQuery.selectQuerySQL(_:arguments:)
    func selectQuerySQL(_ arguments: inout StatementArguments?) -> String {
        return sql(&arguments)
    }
}
