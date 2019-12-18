// MARK: - SQL Ordering Support

/// :nodoc:
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
    
    #if GRDBCUSTOMSQLITE
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var ascNullsLast: SQLOrderingTerm {
        return SQLOrdering.ascNullsLast(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var descNullsFirst: SQLOrderingTerm {
        return SQLOrdering.descNullsFirst(sqlExpression)
    }
    #endif
}


// MARK: - SQL Selection Support

/// :nodoc:
extension SQLSpecificExpressible {
    
    /// Give the expression the given SQL name.
    ///
    /// For example:
    ///
    ///     // SELECT (width * height) AS area FROM shape
    ///     let area = (Column("width") * Column("height")).aliased("area")
    ///     let request = Shape.select(area)
    ///     if let row = try Row.fetchOne(db, request) {
    ///         let area: Int = row["area"]
    ///     }
    @available(*, deprecated, renamed: "forKey(_:)")
    public func aliased(_ name: String) -> SQLSelectable {
        return forKey(name)
    }
    
    /// Give the expression the given SQL name.
    ///
    /// For example:
    ///
    ///     // SELECT (width * height) AS area FROM shape
    ///     let area = (Column("width") * Column("height")).forKey("area")
    ///     let request = Shape.select(area)
    ///     if let row = try Row.fetchOne(db, request) {
    ///         let area: Int = row["area"]
    ///     }
    public func forKey(_ key: String) -> SQLSelectable {
        return SQLAliasedExpression(sqlExpression, name: key)
    }
    
    /// Give the expression the same SQL name as the coding key.
    ///
    /// For example:
    ///
    ///     struct Shape: Decodable, FetchableRecord, TableRecord {
    ///         let width: Int
    ///         let height: Int
    ///         let area: Int
    ///
    ///         static let databaseSelection: [SQLSelectable] = [
    ///             Column(CodingKeys.width),
    ///             Column(CodingKeys.height),
    ///             (Column(CodingKeys.width) * Column(CodingKeys.height)).aliased(CodingKeys.area),
    ///         ]
    ///     }
    ///
    ///     // SELECT width, height, (width * height) AS area FROM shape
    ///     let shapes: [Shape] = try Shape.fetchAll(db)
    @available(*, deprecated, renamed: "forKey(_:)")
    public func aliased(_ key: CodingKey) -> SQLSelectable {
        return forKey(key)
    }
    
    /// Give the expression the same SQL name as the coding key.
    ///
    /// For example:
    ///
    ///     struct Shape: Decodable, FetchableRecord, TableRecord {
    ///         let width: Int
    ///         let height: Int
    ///         let area: Int
    ///
    ///         static let databaseSelection: [SQLSelectable] = [
    ///             Column(CodingKeys.width),
    ///             Column(CodingKeys.height),
    ///             (Column(CodingKeys.width) * Column(CodingKeys.height)).forKey(CodingKeys.area),
    ///         ]
    ///     }
    ///
    ///     // SELECT width, height, (width * height) AS area FROM shape
    ///     let shapes: [Shape] = try Shape.fetchAll(db)
    public func forKey(_ key: CodingKey) -> SQLSelectable {
        return forKey(key.stringValue)
    }
}


// MARK: - SQL Collations Support

/// :nodoc:
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
