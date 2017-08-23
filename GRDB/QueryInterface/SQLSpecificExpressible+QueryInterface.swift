// MARK: - SQL Ordering Support

extension SQLSpecificExpressible {
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: SQLOrderingTerm {
        return SQLOrdering.asc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: SQLOrderingTerm {
        return SQLOrdering.desc(sqlExpression)
    }
}


// MARK: - SQL Selection Support

extension SQLSpecificExpressible {
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.select()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func aliased(_ alias: String) -> SQLSelectable {
        return SQLAliasedExpression(sqlExpression, alias: alias)
    }
}


// MARK: - SQL Collations Support

extension SQLSpecificExpressible {
    
    /// Returns a collated expression.
    ///
    /// For example:
    ///
    ///     Player.filter(Column("email").collating(.nocase) == "contact@example.com")
    public func collating(_ collation: Database.CollationName) -> SQLCollatedExpression {
        return SQLCollatedExpression(sqlExpression, collationName: collation)
    }
    
    /// Returns a collated expression.
    ///
    /// For example:
    ///
    ///     Player.filter(Column("name").collating(.localizedStandardCompare) == "Hervé")
    public func collating(_ collation: DatabaseCollation) -> SQLCollatedExpression {
        return SQLCollatedExpression(sqlExpression, collationName: Database.CollationName(collation.name))
    }
}

