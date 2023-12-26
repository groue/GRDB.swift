struct SQLTableGenerator {
    var name: String
    var options: TableOptions
    var columnGenerators: [SQLColumnGenerator]
    /// Used for auto-referencing foreign keys: we need to know the columns
    /// of the primary key before they exist in the database schema, hence
    /// the name of "forward" primary key columns.
    ///
    /// If nil, the primary key is the hidden rowID.
    var forwardPrimaryKeyColumns: [SQLColumnDescriptor]?
    var primaryKeyConstraint: KeyConstraint?
    var uniqueKeyConstraints: [KeyConstraint]
    var foreignKeyConstraints: [SQLForeignKeyConstraint]
    var checkConstraints: [SQLExpression]
    var literalConstraints: [SQL]
    var indexGenerators: [SQLIndexGenerator]
    
    struct KeyConstraint {
        var columns: [String]
        var conflictResolution: Database.ConflictResolution?
    }
    
    func sql(_ db: Database) throws -> String {
        var statements: [String] = []
        
        do {
            var chunks: [String] = []
            chunks.append("CREATE")
            if options.contains(.temporary) {
                chunks.append("TEMPORARY")
            }
            chunks.append("TABLE")
            if options.contains(.ifNotExists) {
                chunks.append("IF NOT EXISTS")
            }
            chunks.append(name.quotedDatabaseIdentifier)
            
            do {
                var items: [String] = []
                try items.append(contentsOf: columnGenerators.map {
                    try $0.sql(db, tableName: name, primaryKeyColumns: { forwardPrimaryKeyColumns })
                })
                
                if let constraint = primaryKeyConstraint {
                    var chunks: [String] = []
                    chunks.append("PRIMARY KEY")
                    chunks.append("(\(constraint.columns.map(\.quotedDatabaseIdentifier).joined(separator: ", ")))")
                    if let conflictResolution = constraint.conflictResolution {
                        chunks.append("ON CONFLICT")
                        chunks.append(conflictResolution.rawValue)
                    }
                    items.append(chunks.joined(separator: " "))
                }
                
                for constraint in uniqueKeyConstraints {
                    var chunks: [String] = []
                    chunks.append("UNIQUE")
                    chunks.append("(\(constraint.columns.map(\.quotedDatabaseIdentifier).joined(separator: ", ")))")
                    if let conflictResolution = constraint.conflictResolution {
                        chunks.append("ON CONFLICT")
                        chunks.append(conflictResolution.rawValue)
                    }
                    items.append(chunks.joined(separator: " "))
                }
                
                for constraint in foreignKeyConstraints {
                    var chunks: [String] = []
                    chunks.append("FOREIGN KEY")
                    chunks.append("(\(constraint.columns.map(\.quotedDatabaseIdentifier).joined(separator: ", ")))")
                    chunks.append("REFERENCES")
                    if let destinationColumns = constraint.destinationColumns {
                        chunks.append("""
                            \(constraint.destinationTable.quotedDatabaseIdentifier)(\
                            \(destinationColumns.map(\.quotedDatabaseIdentifier).joined(separator: ", "))\
                            )
                            """)
                    } else if constraint.destinationTable.lowercased() == name.lowercased() {
                        // autoreference
                        let forwardPrimaryKeyColumns = forwardPrimaryKeyColumns ?? [.rowID]
                        chunks.append("""
                            \(constraint.destinationTable.quotedDatabaseIdentifier)(\
                            \(forwardPrimaryKeyColumns.map(\.name.quotedDatabaseIdentifier).joined(separator: ", "))\
                            )
                            """)
                    } else {
                        let primaryKey = try db.primaryKey(constraint.destinationTable)
                        chunks.append("""
                            \(constraint.destinationTable.quotedDatabaseIdentifier)(\
                            \(primaryKey.columns.map(\.quotedDatabaseIdentifier).joined(separator: ", "))\
                            )
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
                    items.append(chunks.joined(separator: " "))
                }
                
                for checkExpression in checkConstraints {
                    var chunks: [String] = []
                    try chunks.append("CHECK (\(checkExpression.quotedSQL(db)))")
                    items.append(chunks.joined(separator: " "))
                }
                
                for literal in literalConstraints {
                    let context = SQLGenerationContext(db, argumentsSink: .literalValues)
                    try items.append(literal.sql(context))
                }
                
                chunks.append("(\(items.joined(separator: ", ")))")
            }
            
            var tableOptions: [String] = []
            
#if GRDBCUSTOMSQLITE || GRDBCIPHER
            if options.contains(.strict) {
                tableOptions.append("STRICT")
            }
#else
            if #available(iOS 15.4, macOS 12.4, tvOS 15.4, watchOS 8.5, *) { // SQLite 3.37+
                if options.contains(.strict) {
                    tableOptions.append("STRICT")
                }
            }
#endif
            if options.contains(.withoutRowID) {
                tableOptions.append("WITHOUT ROWID")
            }
            
            if !tableOptions.isEmpty {
                chunks.append(tableOptions.joined(separator: ", "))
            }
            
            statements.append(chunks.joined(separator: " "))
        }
        
        let indexStatements = try indexGenerators.map { try $0.sql(db) }
        statements.append(contentsOf: indexStatements)
        return statements.joined(separator: "; ")
    }
    
    private struct ForeignKeyGenerator {
        var columnNames: [String]
        var columnGenerators: [SQLColumnGenerator]
        var foreignKeyConstraint: SQLForeignKeyConstraint?
        var indexGenerator: SQLIndexGenerator?
    }
}

extension SQLTableGenerator {
    init(_ db: Database, table: TableDefinition) throws {
        var indexOptions: IndexOptions = []
        if table.options.contains(.ifNotExists) { indexOptions.insert(.ifNotExists) }
        
        func makeKeyConstraint(
            _ db: Database,
            constraint: TableDefinition.KeyConstraint,
            forwardPrimaryKey: SQLPrimaryKeyDescriptor)
        throws -> SQLTableGenerator.KeyConstraint
        {
            try SQLTableGenerator.KeyConstraint(
                columns: constraint.components.flatMap { component -> [String] in
                    switch component {
                    case let .columnName(columnName):
                        return [columnName]
                    case let .columnDefinition(column):
                        return [column.name]
                    case let .foreignKeyDefinition(foreignKey):
                        return try Self.makeForeignKeyGenerator(
                            db, foreignKey: foreignKey,
                            originTable: table.name,
                            forwardPrimaryKey: forwardPrimaryKey,
                            indexOptions: indexOptions).columnNames
                    }
                },
                conflictResolution: constraint.conflictResolution)
        }
        
        var forwardPrimaryKeyColumns: [SQLColumnDescriptor]?
        if let primaryKeyConstraint = table.primaryKeyConstraint {
            forwardPrimaryKeyColumns = try Self.forwardPrimaryKeyColumns(
                db, primaryKeyConstraint: primaryKeyConstraint,
                originTable: table.name)
        } else {
            for component in table.columnComponents {
                if case let .columnDefinition(column) = component, column.primaryKey != nil {
                    forwardPrimaryKeyColumns = [SQLColumnDescriptor(column)]
                    break
                }
            }
        }
        let forwardPrimaryKey = SQLPrimaryKeyDescriptor(
            tableName: table.name,
            primaryKeyColumns: forwardPrimaryKeyColumns)
        
        var columnGenerators: [SQLColumnGenerator] = []
        var foreignKeyConstraints: [SQLForeignKeyConstraint] = []
        var indexGenerators: [SQLIndexGenerator] = []
        
        for component in table.columnComponents {
            switch component {
            case let .columnDefinition(column):
                columnGenerators.append(.columnDefinition(column))
                
            case let .columnLiteral(sql):
                columnGenerators.append(.columnLiteral(sql))
                
            case let .foreignKeyDefinition(foreignKey):
                let fkGenerator = try Self.makeForeignKeyGenerator(
                    db, foreignKey: foreignKey,
                    originTable: table.name,
                    forwardPrimaryKey: forwardPrimaryKey,
                    indexOptions: indexOptions)
                columnGenerators.append(contentsOf: fkGenerator.columnGenerators)
                if let indexGenerator = fkGenerator.indexGenerator {
                    indexGenerators.append(indexGenerator)
                }
                if let foreignKeyConstraint = fkGenerator.foreignKeyConstraint {
                    foreignKeyConstraints.append(foreignKeyConstraint)
                }
                
            case let .foreignKeyConstraint(constraint):
                foreignKeyConstraints.append(constraint)
            }
        }
        
        for columnGenerator in columnGenerators {
            if case let .columnDefinition(column) = columnGenerator,
               let index = column.indexDefinition(in: table.name, options: indexOptions)
            {
                indexGenerators.append(SQLIndexGenerator(index: index))
            }
        }
        
        try self.init(
            name: table.name,
            options: table.options,
            columnGenerators: columnGenerators,
            forwardPrimaryKeyColumns: forwardPrimaryKeyColumns,
            primaryKeyConstraint: table.primaryKeyConstraint.map {
                try makeKeyConstraint(db, constraint: $0, forwardPrimaryKey: forwardPrimaryKey)
            },
            uniqueKeyConstraints: table.uniqueKeyConstraints.map {
                try makeKeyConstraint(db, constraint: $0, forwardPrimaryKey: forwardPrimaryKey)
            },
            foreignKeyConstraints: foreignKeyConstraints,
            checkConstraints: table.checkConstraints,
            literalConstraints: table.literalConstraints,
            indexGenerators: indexGenerators)
    }
    
    private static func forwardPrimaryKeyColumns(
        _ db: Database,
        primaryKeyConstraint: TableDefinition.KeyConstraint,
        originTable: String)
    throws -> [SQLColumnDescriptor]?
    {
        var forwardPrimaryKeyColumns: [SQLColumnDescriptor] = []
        for component in primaryKeyConstraint.components {
            switch component {
            case let .columnDefinition(column):
                forwardPrimaryKeyColumns.append(SQLColumnDescriptor(column))
            case let .foreignKeyDefinition(foreignKey):
                let fkGenerator = try makeForeignKeyGenerator(
                    db, foreignKey: foreignKey,
                    originTable: originTable,
                    forwardPrimaryKey: nil, // not known yet, since we're building it
                    indexOptions: [])
                for columnGenerator in fkGenerator.columnGenerators {
                    switch columnGenerator {
                    case let .columnDefinition(column):
                        forwardPrimaryKeyColumns.append(SQLColumnDescriptor(column))
                    case .columnLiteral:
                        // Unknown column name
                        return nil
                    }
                }
            case let .columnName(name):
                forwardPrimaryKeyColumns.append(SQLColumnDescriptor(name: name, type: nil))
            }
        }
        return forwardPrimaryKeyColumns
    }
    
    private static func makeForeignKeyGenerator(
        _ db: Database,
        foreignKey: ForeignKeyDefinition,
        originTable: String,
        forwardPrimaryKey: SQLPrimaryKeyDescriptor?,
        indexOptions: IndexOptions)
    throws -> ForeignKeyGenerator
    {
        let destinationPrimaryKey: SQLPrimaryKeyDescriptor
        
        if let table = foreignKey.table {
            if let forwardPrimaryKey,
               originTable.lowercased() == table.lowercased()
            {
                // autoreference
                destinationPrimaryKey = forwardPrimaryKey
            } else {
                destinationPrimaryKey = try foreignKey.primaryKey(db)
            }
        } else {
            if let forwardPrimaryKey,
               originTable.singularized.lowercased() == foreignKey.name.singularized.lowercased()
            {
                // autoreference
                destinationPrimaryKey = forwardPrimaryKey
            } else {
                destinationPrimaryKey = try foreignKey.primaryKey(db)
            }
        }
        
        guard let primaryKeyColumns = destinationPrimaryKey.primaryKeyColumns else {
            // Destination table has an hidden rowID primary key
            let columnName = foreignKey.name + "Id"
            let column = ColumnDefinition(name: columnName, type: .integer).references(
                destinationPrimaryKey.tableName,
                onDelete: foreignKey.deleteAction,
                onUpdate: foreignKey.updateAction,
                deferred: foreignKey.isDeferred)
            if let notNullConflictResolution = foreignKey.notNullConflictResolution {
                column.notNull(onConflict: notNullConflictResolution)
            }
            switch foreignKey.indexing {
            case nil:
                break
            case .index:
                column.indexed()
            case .unique:
                column.unique()
            }
            return ForeignKeyGenerator(
                columnNames: [columnName],
                columnGenerators: [SQLColumnGenerator.columnDefinition(column)],
                foreignKeyConstraint: nil,
                indexGenerator: nil)
        }
        
        assert(!primaryKeyColumns.isEmpty)
        let columnNames = primaryKeyColumns.map {
            foreignKey.name + $0.name.uppercasingFirstCharacter
        }
        
        if primaryKeyColumns.count == 1 {
            // Destination table has a single column primary key
            let pkColumn = primaryKeyColumns[0]
            let columnName = columnNames[0]
            let column = ColumnDefinition(name: columnName, type: pkColumn.type).references(
                destinationPrimaryKey.tableName,
                column: pkColumn.name,
                onDelete: foreignKey.deleteAction,
                onUpdate: foreignKey.updateAction,
                deferred: foreignKey.isDeferred)
            
            if let notNullConflictResolution = foreignKey.notNullConflictResolution {
                column.notNull(onConflict: notNullConflictResolution)
            }
            
            switch foreignKey.indexing {
            case nil:
                break
            case .index:
                column.indexed()
            case .unique:
                column.unique()
            }
            
            return ForeignKeyGenerator(
                columnNames: [columnName],
                columnGenerators: [SQLColumnGenerator.columnDefinition(column)],
                foreignKeyConstraint: nil,
                indexGenerator: nil)
        } else {
            // Destination table has a composite primary key
            let columnGenerators = zip(primaryKeyColumns, columnNames).map { pkColumn, columnName in
                let column = ColumnDefinition(name: columnName, type: pkColumn.type)
                if let notNullConflictResolution = foreignKey.notNullConflictResolution {
                    column.notNull(onConflict: notNullConflictResolution)
                }
                return SQLColumnGenerator.columnDefinition(column)
            }
            
            let foreignKeyConstraint = SQLForeignKeyConstraint(
                columns: columnNames,
                destinationTable: destinationPrimaryKey.tableName,
                destinationColumns: nil,
                deleteAction: foreignKey.deleteAction,
                updateAction: foreignKey.updateAction,
                isDeferred: foreignKey.isDeferred)
            
            let indexGenerator: SQLIndexGenerator?
            switch foreignKey.indexing {
            case nil:
                indexGenerator = nil
            case .index:
                indexGenerator = SQLIndexGenerator(
                    name: Database.defaultIndexName(on: originTable, columns: columnNames),
                    table: originTable,
                    expressions: columnNames.map { .column($0) },
                    options: indexOptions,
                    condition: nil)
            case .unique:
                indexGenerator = SQLIndexGenerator(
                    name: Database.defaultIndexName(on: originTable, columns: columnNames),
                    table: originTable,
                    expressions: columnNames.map { .column($0) },
                    options: indexOptions.union([.unique]),
                    condition: nil)
            }
            
            return ForeignKeyGenerator(
                columnNames: columnNames,
                columnGenerators: columnGenerators,
                foreignKeyConstraint: foreignKeyConstraint,
                indexGenerator: indexGenerator)
        }
    }
}

struct SQLColumnDescriptor {
    static let rowID = SQLColumnDescriptor(name: Column.rowID.name, type: .integer)
    
    var name: String
    var type: Database.ColumnType?
}

extension SQLColumnDescriptor {
    init(_ column: ColumnInfo) {
        self.init(
            name: column.name,
            type: column.columnType)
    }
    
    init(_ column: ColumnDefinition) {
        self.init(name: column.name, type: column.type)
    }
}

struct SQLForeignKeyConstraint {
    var columns: [String]
    var destinationTable: String
    var destinationColumns: [String]?
    var deleteAction: Database.ForeignKeyAction?
    var updateAction: Database.ForeignKeyAction?
    var isDeferred: Bool
}

struct SQLPrimaryKeyDescriptor {
    /// The name of the forward-declared table
    var tableName: String
    
    /// If nil, the primary key is the hidden rowID.
    var primaryKeyColumns: [SQLColumnDescriptor]?
}

extension SQLPrimaryKeyDescriptor {
    static func find(_ db: Database, table: String) throws -> Self {
        let columnInfos = try db.primaryKey(table).columnInfos
        return SQLPrimaryKeyDescriptor(
            tableName: table,
            primaryKeyColumns: columnInfos.map { columnInfos in
                columnInfos.map { SQLColumnDescriptor($0) }
            })
        
    }
}
