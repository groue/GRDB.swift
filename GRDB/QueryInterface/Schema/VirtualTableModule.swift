/// The protocol for SQLite virtual table modules. It lets you define a DSL for
/// the `Database.create(virtualTable:using:)` method:
///
///     let module = ...
///     try db.create(virtualTable: "item", using: module) { t in
///         ...
///     }
///
/// GRDB ships with three concrete classes that implement this protocol: FTS3,
/// FTS4 and FTS5.
public protocol VirtualTableModule {
    
    /// The type of the closure argument in the
    /// `Database.create(virtualTable:using:)` method:
    ///
    ///     try db.create(virtualTable: "item", using: module) { t in
    ///         // t is TableDefinition
    ///     }
    associatedtype TableDefinition
    
    /// The name of the module.
    var moduleName: String { get }
    
    /// Returns a table definition that is passed as the closure argument in the
    /// `Database.create(virtualTable:using:)` method:
    ///
    ///     try db.create(virtualTable: "item", using: module) { t in
    ///         // t is the result of makeTableDefinition()
    ///     }
    func makeTableDefinition() -> TableDefinition
    
    /// Returns the module arguments for the `CREATE VIRTUAL TABLE` query.
    func moduleArguments(for definition: TableDefinition, in db: Database) throws -> [String]
    
    /// Execute any relevant database statement after the virtual table has
    /// been created.
    func database(_ db: Database, didCreate tableName: String, using definition: TableDefinition) throws
}

extension Database {
    
    // MARK: - Database Schema
    
    /// Creates a virtual database table.
    ///
    ///     try db.create(virtualTable: "vocabulary", using: "spellfix1")
    ///
    /// See https://www.sqlite.org/lang_createtable.html
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - ifNotExists: If false (the default), an error is thrown if the
    ///       table already exists. Otherwise, the table is created unless it
    ///       already exists.
    ///     - module: The name of an SQLite virtual table module.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func create(virtualTable name: String, ifNotExists: Bool = false, using module: String) throws {
        var chunks: [String] = []
        chunks.append("CREATE VIRTUAL TABLE")
        if ifNotExists {
            chunks.append("IF NOT EXISTS")
        }
        chunks.append(name.quotedDatabaseIdentifier)
        chunks.append("USING")
        chunks.append(module)
        let sql = chunks.joined(separator: " ")
        try execute(sql: sql)
    }
    
    /// Creates a virtual database table.
    ///
    ///     let module = ...
    ///     try db.create(virtualTable: "book", using: module) { t in
    ///         ...
    ///     }
    ///
    /// The type of the closure argument `t` depends on the type of the module
    /// argument: refer to this module's documentation.
    ///
    /// Use this method to create full-text tables using the FTS3, FTS4, or
    /// FTS5 modules:
    ///
    ///     try db.create(virtualTable: "book", using: FTS4()) { t in
    ///         t.column("title")
    ///         t.column("author")
    ///         t.column("body")
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - ifNotExists: If false (the default), an error is thrown if the
    ///       table already exists. Otherwise, the table is created unless it
    ///       already exists.
    ///     - module: a VirtualTableModule
    ///     - body: An optional closure that defines the virtual table.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func create<Module: VirtualTableModule>(
        virtualTable tableName: String,
        ifNotExists: Bool = false,
        using module: Module,
        _ body: ((Module.TableDefinition) -> Void)? = nil)
        throws
    {
        // Define virtual table
        let definition = module.makeTableDefinition()
        if let body = body {
            body(definition)
        }
        
        // Create virtual table
        var chunks: [String] = []
        chunks.append("CREATE VIRTUAL TABLE")
        if ifNotExists {
            chunks.append("IF NOT EXISTS")
        }
        chunks.append(tableName.quotedDatabaseIdentifier)
        chunks.append("USING")
        let arguments = try module.moduleArguments(for: definition, in: self)
        if arguments.isEmpty {
            chunks.append(module.moduleName)
        } else {
            chunks.append(module.moduleName + "(" + arguments.joined(separator: ", ") + ")")
        }
        let sql = chunks.joined(separator: " ")
        
        try inSavepoint {
            try execute(sql: sql)
            try module.database(self, didCreate: tableName, using: definition)
            return .commit
        }
    }
}
