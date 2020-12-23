// MARK: - SQL Ordering Support

/// :nodoc:
extension SQLSpecificExpressible {
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: SQLOrderingTerm {
        SQLOrdering.asc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: SQLOrderingTerm {
        SQLOrdering.desc(sqlExpression)
    }
    
    #if GRDBCUSTOMSQLITE
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var ascNullsLast: SQLOrderingTerm {
        SQLOrdering.ascNullsLast(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var descNullsFirst: SQLOrderingTerm {
        SQLOrdering.descNullsFirst(sqlExpression)
    }
    #elseif !GRDBCIPHER
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    @available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *)
    public var ascNullsLast: SQLOrderingTerm {
        SQLOrdering.ascNullsLast(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    @available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *)
    public var descNullsFirst: SQLOrderingTerm {
        SQLOrdering.descNullsFirst(sqlExpression)
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
    ///     let area = (Column("width") * Column("height")).forKey("area")
    ///     let request = Shape.select(area)
    ///     if let row = try Row.fetchOne(db, request) {
    ///         let area: Int = row["area"]
    ///     }
    public func forKey(_ key: String) -> SQLSelectable {
        SQLAliasedExpression(sqlExpression, name: key)
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
        forKey(key.stringValue)
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
        SQLCollatedExpression(sqlExpression, collationName: collation)
    }
    
    /// Returns a collated expression.
    ///
    /// For example:
    ///
    ///     Player.filter(Column("name").collating(.localizedStandardCompare) == "Hervé")
    public func collating(_ collation: DatabaseCollation) -> SQLCollatedExpression {
        SQLCollatedExpression(sqlExpression, collationName: Database.CollationName(rawValue: collation.name))
    }
}
