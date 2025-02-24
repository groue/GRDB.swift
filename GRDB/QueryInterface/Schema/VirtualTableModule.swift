/// The protocol for SQLite virtual table modules.
///
/// The protocol can define a DSL for the
/// ``Database/create(virtualTable:options:using:_:)`` `Database` method:
///
/// ```swift
/// let module = ...
/// try db.create(virtualTable: "item", using: module) { t in
///     ...
/// }
/// ```
///
/// GRDB ships with three concrete classes that implement this protocol:
/// ``FTS3``, ``FTS4`` and `FTS5`.
///
/// ## Topics
///
/// ### Configuration Virtual Table Creation
///
/// - ``VirtualTableConfiguration``
public protocol VirtualTableModule {
    /// The type of the argument in the
    /// ``Database/create(virtualTable:options:using:_:)`` closure.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "item", using: module) { t in
    ///     // t is TableDefinition
    /// }
    /// ```
    associatedtype TableDefinition
    
    /// The name of the module.
    var moduleName: String { get }
    
    /// Returns a table definition that is passed as the argument in the
    /// ``Database/create(virtualTable:options:using:_:)`` closure.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "item", using: module) { t in
    ///     // t is the result of makeTableDefinition(configuration:)
    /// }
    /// ```
    func makeTableDefinition(configuration: VirtualTableConfiguration) -> TableDefinition
    
    /// Returns the module arguments for the `CREATE VIRTUAL TABLE` query.
    func moduleArguments(for definition: TableDefinition, in db: Database) throws -> [String]
    
    /// Execute any relevant database statement after the virtual table has
    /// been created.
    func database(_ db: Database, didCreate tableName: String, using definition: TableDefinition) throws
}

// TODO: Question the existence of this API. VirtualTableConfiguration was
// never able to be used by user-defined VirtualTableModule types, because
// `ifNotExists` has never been public.
public struct VirtualTableConfiguration {
    /// If true, existing objects must not be replaced, or generate any error
    /// (even if they do not match the objects that would be created otherwise.)
    var ifNotExists: Bool
    
    /// If true, new objects must be created in the temp schema.
    var temporary: Bool
}

/// Virtual table creation options.
public struct VirtualTableOptions: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    /// Only creates the table if it does not already exist.
    public static let ifNotExists = VirtualTableOptions(rawValue: 1 << 0)
    
    /// Creates a temporary table.
    public static let temporary = VirtualTableOptions(rawValue: 1 << 1)
}

extension Database {
    
    // MARK: - Database Schema
    
    /// Creates a virtual database table.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIRTUAL TABLE vocabulary USING spellfix1
    /// try db.create(virtualTable: "vocabulary", using: "spellfix1")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html>
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - options: Table creation options.
    ///     - module: The name of an SQLite virtual table module.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func create(
        virtualTable name: String,
        options: VirtualTableOptions = [],
        using module: String
    ) throws {
        var chunks: [String] = []
        chunks.append("CREATE VIRTUAL TABLE")
        if options.contains(.ifNotExists) {
            chunks.append("IF NOT EXISTS")
        }
        if options.contains(.temporary) {
            chunks.append("temp.\(name.quotedDatabaseIdentifier)")
        } else {
            chunks.append(name.quotedDatabaseIdentifier)
        }
        chunks.append("USING")
        chunks.append(module)
        let sql = chunks.joined(separator: " ")
        try execute(sql: sql)
    }
    
    /// Creates a virtual database table.
    ///
    /// The type of the argument of the `body` function depends on the type of
    /// the `module` argument: refer to this module's documentation.
    ///
    /// You can use this method to create full-text virtual tables:
    ///
    /// ```swift
    /// try db.create(virtualTable: "book", using: FTS4()) { t in
    ///     t.column("title")
    ///     t.column("author")
    ///     t.column("body")
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html>
    ///
    /// - parameters:
    ///     - tableName: The table name.
    ///     - options: Table creation options.
    ///     - module: a virtual module.
    ///     - body: An optional closure that defines the virtual table.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public func create<Module: VirtualTableModule>(
        virtualTable tableName: String,
        options: VirtualTableOptions = [],
        using module: Module,
        _ body: ((Module.TableDefinition) throws -> Void)? = nil)
    throws
    {
        // Define virtual table
        let configuration = VirtualTableConfiguration(
            ifNotExists: options.contains(.ifNotExists),
            temporary: options.contains(.temporary))
        let definition = module.makeTableDefinition(configuration: configuration)
        if let body {
            try body(definition)
        }
        
        // Create virtual table
        var chunks: [String] = []
        chunks.append("CREATE VIRTUAL TABLE")
        if options.contains(.ifNotExists) {
            chunks.append("IF NOT EXISTS")
        }
        if options.contains(.temporary) {
            chunks.append("temp.\(tableName.quotedDatabaseIdentifier)")
        } else {
            chunks.append(tableName.quotedDatabaseIdentifier)
        }
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
    
    /// Creates a virtual database table.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIRTUAL TABLE vocabulary USING spellfix1
    /// try db.create(virtualTable: "vocabulary", using: "spellfix1")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html>
    ///
    /// - warning: This is a legacy interface that is preserved for backwards
    ///   compatibility. Use of this interface is not recommended: prefer
    ///   ``create(virtualTable:options:using:)`` instead.
    ///
    /// - parameters:
    ///     - name: The table name.
    ///     - ifNotExists: If false (the default), an error is thrown if the
    ///       table already exists. Otherwise, the table is created unless it
    ///       already exists.
    ///     - module: The name of an SQLite virtual table module.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    @_disfavoredOverload
    public func create(virtualTable name: String, ifNotExists: Bool = false, using module: String) throws {
        try create(
            virtualTable: name,
            options: ifNotExists ? .ifNotExists : [],
            using: module)
    }
    
    /// Creates a virtual database table.
    ///
    /// The type of the argument of the `body` function depends on the type of
    /// the `module` argument: refer to this module's documentation.
    ///
    /// You can use this method to create full-text virtual tables:
    ///
    /// ```swift
    /// try db.create(virtualTable: "book", using: FTS4()) { t in
    ///     t.column("title")
    ///     t.column("author")
    ///     t.column("body")
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/lang_createtable.html>
    ///
    /// - warning: This is a legacy interface that is preserved for backwards
    ///   compatibility. Use of this interface is not recommended: prefer
    ///   ``create(virtualTable:options:using:_:)`` instead.
    ///
    /// - parameters:
    ///     - tableName: The table name.
    ///     - ifNotExists: If false (the default), an error is thrown if the
    ///       table already exists. Otherwise, the table is created unless it
    ///       already exists.
    ///     - module: a virtual module.
    ///     - body: An optional closure that defines the virtual table.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    @_disfavoredOverload
    public func create<Module: VirtualTableModule>(
        virtualTable tableName: String,
        ifNotExists: Bool = false,
        using module: Module,
        _ body: ((Module.TableDefinition) throws -> Void)? = nil)
    throws
    {
        try create(
            virtualTable: tableName,
            options: ifNotExists ? .ifNotExists : [],
            using: module,
            body)
    }
}
