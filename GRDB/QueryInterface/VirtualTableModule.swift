/// The protocol for SQLite virtual table modules. It lets you define a DSL for
/// the `Database.create(virtualTable:using:)` method:
///
///     let module = ...
///     try db.create(virtualTable: "items", using: module) { t in
///         ...
///     }
///
/// GRDB ships with three concrete classes that implement this protocol: FTS3,
/// FTS4 and FTS5.
public protocol VirtualTableModule {
    
    /// The type of the closure argument in the
    /// `Database.create(virtualTable:using:)` method:
    ///
    ///     try db.create(virtualTable: "items", using: module) { t in
    ///         // t is TableDefinition
    ///     }
    associatedtype TableDefinition
    
    /// The name of the module.
    var moduleName: String { get }
    
    /// Returns a table definition that is passed as the closure argument in the
    /// `Database.create(virtualTable:using:)` method:
    ///
    ///     try db.create(virtualTable: "items", using: module) { t in
    ///         // t is the result of makeTableDefinition()
    ///     }
    func makeTableDefinition() -> TableDefinition
    
    /// Returns the module arguments for the `CREATE VIRTUAL TABLE` query.
    func moduleArguments(_ definition: TableDefinition) -> [String]
}

extension Database {
    
    // MARK: - Database Schema: Virtual Table
    
    /// Creates a virtual database table.
    ///
    ///     try db.create(virtualTable: "vocabulary", using: "spellfix1")
    ///
    /// See https://www.sqlite.org/lang_createtable.html
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - ifNotExists: If false, no error is thrown if table already exists.
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
        try execute(sql)
    }
    
    /// Creates a virtual database table.
    ///
    ///     let module = ...
    ///     try db.create(virtualTable: "pointOfInterests", using: module) { t in
    ///         ...
    ///     }
    ///
    /// The type of the closure argument `t` depends on the type of the module
    /// argument: refer to this module's documentation.
    ///
    /// Use this method to create full-text tables using the FTS3, FTS4, or
    /// FTS5 modules:
    ///
    ///     try db.create(virtualTable: "books", using: FTS4()) { t in
    ///         t.column("title")
    ///         t.column("author")
    ///         t.column("body")
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - ifNotExists: If false, no error is thrown if table already exists.
    ///     - module: a VirtualTableModule
    ///     - body: An optional closure that defines the virtual table.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func create<Module: VirtualTableModule>(virtualTable name: String, ifNotExists: Bool = false, using module: Module, _ body: ((Module.TableDefinition) -> Void)? = nil) throws {
        let definition = module.makeTableDefinition()
        if let body = body {
            body(definition)
        }
        
        var chunks: [String] = []
        chunks.append("CREATE VIRTUAL TABLE")
        if ifNotExists {
            chunks.append("IF NOT EXISTS")
        }
        chunks.append(name.quotedDatabaseIdentifier)
        chunks.append("USING")
        let arguments = module.moduleArguments(definition)
        if arguments.isEmpty {
            chunks.append(module.moduleName)
        } else {
            chunks.append(module.moduleName + "(" + arguments.joined(separator: ", ") + ")")
        }
        let sql = chunks.joined(separator: " ")
        try execute(sql)
    }
}
