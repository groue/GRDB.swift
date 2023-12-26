struct SQLIndexGenerator {
    let name: String
    let table: String
    let expressions: [SQLExpression]
    let options: IndexOptions
    let condition: SQLExpression?
    
    func sql(_ db: Database) throws -> String {
        var sql: SQL = "CREATE"
        
        if options.contains(.unique) {
            sql += " UNIQUE"
        }
        
        sql += " INDEX"
        
        if options.contains(.ifNotExists) {
            sql += " IF NOT EXISTS"
        }
        
        sql += " \(identifier: name) ON \(identifier: table)("
        sql += expressions.map { SQL($0) }.joined(separator: ", ")
        sql += ")"
        
        if let condition {
            sql += " WHERE \(condition)"
        }
        
        let context = SQLGenerationContext(db, argumentsSink: .literalValues)
        return try sql.sql(context)
    }
}

extension SQLIndexGenerator {
    init(index: IndexDefinition) {
        name = index.name
        table = index.table
        expressions = index.expressions
        options = index.options
        condition = index.condition
    }
}
