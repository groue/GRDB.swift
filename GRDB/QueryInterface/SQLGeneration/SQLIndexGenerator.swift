struct SQLIndexGenerator {
    let name: String
    let table: String
    let columns: [String]
    let options: IndexOptions
    let condition: SQLExpression?
    
    func sql(_ db: Database) throws -> String {
        var chunks: [String] = []
        chunks.append("CREATE")
        if options.contains(.unique) {
            chunks.append("UNIQUE")
        }
        chunks.append("INDEX")
        if options.contains(.ifNotExists) {
            chunks.append("IF NOT EXISTS")
        }
        chunks.append(name.quotedDatabaseIdentifier)
        chunks.append("ON")
        chunks.append("""
            \(table.quotedDatabaseIdentifier)(\
            \(columns.map(\.quotedDatabaseIdentifier).joined(separator: ", "))\
            )
            """)
        if let condition {
            try chunks.append("WHERE \(condition.quotedSQL(db))")
        }
        return chunks.joined(separator: " ")
    }
}

extension SQLIndexGenerator {
    init(index: IndexDefinition) {
        name = index.name
        table = index.table
        columns = index.columns
        options = index.options
        condition = index.condition
    }
}
