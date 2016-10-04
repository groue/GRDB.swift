public protocol VirtualTableDefinition : class {
    init()
    var moduleArguments: [String] { get }
}

public protocol VirtualTableModule {
    associatedtype TableDefinition: VirtualTableDefinition
    var moduleName: String { get }
    init()
}

extension Database {
    
    /// Creates a virtual database table.
    ///
    ///     try db.create(virtualTable: "vocabulary", using: "spellfix1")
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
    ///     try db.create(virtualTable: "pointOfInterests", using; TODO) { t in
    ///         TODO
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - ifNotExists: If false, no error is thrown if table already exists.
    ///     - module: TODO
    ///     - body: A closure that defines table columns and constraints.
    /// - throws: A DatabaseError whenever an SQLite error occurs.
    public func create<Module: VirtualTableModule>(virtualTable name: String, ifNotExists: Bool = false, using module: Module, _ body: ((Module.TableDefinition) -> Void)? = nil) throws {
        let definition = Module.TableDefinition()
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
        let arguments = definition.moduleArguments
        if arguments.isEmpty {
            chunks.append(module.moduleName)
        } else {
            chunks.append(module.moduleName + "(" + arguments.joined(separator: ", ") + ")")
        }
        let sql = chunks.joined(separator: " ")
        try execute(sql)
    }
}
