enum SQLColumnGenerator {
    case columnDefinition(ColumnDefinition)
    case columnLiteral(SQL)
    
    /// - parameter tableName: The name of the table that contains
    ///   the column.
    /// - parameter primaryKeyColumns: A closure that returns the
    ///   primary key columns in the table that contains the column. If
    ///   the result is nil, the primary key is the hidden rowID.
    func sql(
        _ db: Database,
        tableName: String,
        primaryKeyColumns: () throws -> [SQLColumnDescriptor]?)
    throws -> String
    {
        switch self {
        case let .columnDefinition(column):
            return try columnSQL(
                db, column: column,
                tableName: tableName,
                primaryKeyColumns: primaryKeyColumns)
            
        case let .columnLiteral(sqlLiteral):
            let context = SQLGenerationContext(db, argumentsSink: .literalValues)
            return try sqlLiteral.sql(context)
        }
    }
    
    private func columnSQL(
        _ db: Database,
        column: ColumnDefinition,
        tableName: String,
        primaryKeyColumns: () throws -> [SQLColumnDescriptor]?)
    throws -> String
    {
        var chunks: [String] = []
        chunks.append(column.name.quotedDatabaseIdentifier)
        
        if let type = column.type {
            chunks.append(type.rawValue)
        }
        
        if let (conflictResolution, autoincrement) = column.primaryKey {
            chunks.append("PRIMARY KEY")
            if let conflictResolution {
                chunks.append("ON CONFLICT")
                chunks.append(conflictResolution.rawValue)
            }
            if autoincrement {
                chunks.append("AUTOINCREMENT")
            }
        }
        
        switch column.notNullConflictResolution {
        case .none:
            break
        case .abort:
            chunks.append("NOT NULL")
        case let conflictResolution?:
            chunks.append("NOT NULL ON CONFLICT")
            chunks.append(conflictResolution.rawValue)
        }
        
        switch column.indexing {
        case .none:
            break
        case .unique(let conflictResolution):
            switch conflictResolution {
            case .abort:
                chunks.append("UNIQUE")
            default:
                chunks.append("UNIQUE ON CONFLICT")
                chunks.append(conflictResolution.rawValue)
            }
        case .index:
            break
        }
        
        for checkConstraint in column.checkConstraints {
            try chunks.append("CHECK (\(checkConstraint.quotedSQL(db)))")
        }
        
        if let defaultExpression = column.defaultExpression {
            try chunks.append("DEFAULT \(defaultExpression.quotedSQL(db))")
        }
        
        if let collationName = column.collationName {
            chunks.append("COLLATE")
            chunks.append(collationName)
        }
        
        for constraint in column.foreignKeyConstraints {
            chunks.append("REFERENCES")
            if let column = constraint.destinationColumn {
                // explicit referenced column names
                chunks.append("""
                    \(constraint.destinationTable.quotedDatabaseIdentifier)\
                    (\(column.quotedDatabaseIdentifier))
                    """)
            } else {
                // implicit reference to primary key
                let pkColumns: [String]
                
                if constraint.destinationTable.lowercased() == tableName.lowercased() {
                    // autoreference
                    let primaryKeyColumns = try primaryKeyColumns() ?? [.rowID]
                    pkColumns = primaryKeyColumns.map(\.name)
                } else {
                    pkColumns = try db.primaryKey(constraint.destinationTable).columns
                }
                
                chunks.append("""
                    \(constraint.destinationTable.quotedDatabaseIdentifier)\
                    (\(pkColumns.map(\.quotedDatabaseIdentifier).joined(separator: ", ")))
                    """)
            }
            
            if let deleteAction = constraint.deleteAction {
                chunks.append("ON DELETE")
                chunks.append(deleteAction.rawValue)
            }
            if let updateAction = constraint.updateAction {
                chunks.append("ON UPDATE")
                chunks.append(updateAction.rawValue)
            }
            if constraint.isDeferred {
                chunks.append("DEFERRABLE INITIALLY DEFERRED")
            }
        }
        
        if let constraint = column.generatedColumnConstraint {
            try chunks.append("GENERATED ALWAYS AS (\(constraint.expression.quotedSQL(db)))")
            let qualificationLiteral: String
            switch constraint.qualification {
            case .stored:
                qualificationLiteral = "STORED"
            case .virtual:
                qualificationLiteral = "VIRTUAL"
            }
            chunks.append(qualificationLiteral)
        }
        
        return chunks.joined(separator: " ")
    }
}
