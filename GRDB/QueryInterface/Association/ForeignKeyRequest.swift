/// ForeignKeyRequest looks for the foreign keys associations need to
/// join tables.
///
/// Mappings come from foreign keys, when they exist in the database schema.
///
/// When the schema does not define any foreign key, we can still infer complete
/// mappings from partial information and primary keys.
struct ForeignKeyRequest {
    let originTable: String
    let destinationTable: String
    let originColumns: [String]?
    let destinationColumns: [String]?
    
    init(originTable: String, destinationTable: String, foreignKey: ForeignKey?) {
        self.originTable = originTable
        self.destinationTable = destinationTable
        
        self.originColumns = foreignKey?.originColumns
        self.destinationColumns = foreignKey?.destinationColumns
    }
    
    func fetch(_ db: Database) throws -> ForeignKeyInfo {
        if let originColumns = originColumns, let destinationColumns = destinationColumns {
            // Total information: no need to query the database schema.
            GRDBPrecondition(originColumns.count == destinationColumns.count, "Number of columns don't match")
            let mapping = zip(originColumns, destinationColumns).map {
                (origin: $0, destination: $1)
            }
            return ForeignKeyInfo(destinationTable: destinationTable, mapping: mapping)
        }
        
        // Incomplete information: let's look for schema foreign keys
        let foreignKeys = try db.foreignKeys(on: originTable).filter { foreignKey in
            if destinationTable.lowercased() != foreignKey.destinationTable.lowercased() {
                return false
            }
            if let originColumns = originColumns {
                let originColumns = Set(originColumns.lazy.map { $0.lowercased() })
                let foreignKeyColumns = Set(foreignKey.mapping.lazy.map { $0.origin.lowercased() })
                if originColumns != foreignKeyColumns {
                    return false
                }
            }
            // TODO: test
            if let destinationColumns = destinationColumns {
                let destinationColumns = Set(destinationColumns.lazy.map { $0.lowercased() })
                let foreignKeyColumns = Set(foreignKey.mapping.lazy.map { $0.destination.lowercased() })
                if destinationColumns != foreignKeyColumns {
                    return false
                }
            }
            return true
        }
        
        // Matching foreign key(s) found
        if let foreignKey = foreignKeys.first {
            if foreignKeys.count == 1 {
                // Non-ambiguous
                // TODO: test
                return foreignKey
            } else {
                // Ambiguous: can't choose
                fatalError("Ambiguous foreign key from \(originTable) to \(destinationTable)")
            }
        }
        
        // No matching foreign key found: use the destination primary key
        if let originColumns = originColumns {
            let destinationColumns = try db.primaryKey(destinationTable).columns
            if (originColumns.count == destinationColumns.count) {
                // TODO: test
                let mapping = zip(originColumns, destinationColumns).map {
                    (origin: $0, destination: $1)
                }
                return ForeignKeyInfo(destinationTable: destinationTable, mapping: mapping)
            }
        }
        
        fatalError("Could not infer foreign key from \(originTable) to \(destinationTable)")
    }
}

/// The (origin, destination) column pairs that join a left table to a right table.
/// :nodoc:
typealias ForeignKeyMapping = [(origin: String, destination: String)]
