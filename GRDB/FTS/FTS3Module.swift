public struct FTS3 : VirtualTableModule {
    public let moduleName = "FTS3"
    public typealias TableDefinition = FTS3TableDefinition
    public init() {
    }
}

/// The TableDefinition class lets you define table columns and constraints.
///
/// You don't create instances of this class. Instead, you use the Database
/// `create(table:)` method:
///
///     try db.create(table: "persons") { t in // t is TableDefinition
///         t.column(...)
///     }
///
/// See https://www.sqlite.org/lang_createtable.html
public final class FTS3TableDefinition : VirtualTableDefinition {
    private var columns: [String] = []
    
    public init() {
    }
    
    /// Appends a table column.
    ///
    ///     try db.create(virtualTable: "persons", using: TODO) { t in
    ///         t.column("name")
    ///     }
    ///
    /// See https://www.sqlite.org/lang_createtable.html#tablecoldef
    ///
    /// - parameter name: the column name.
    /// - parameter type: the column type.
    /// - returns: An ColumnDefinition that allows you to refine the
    ///   column definition.
    public func column(_ name: String) {
        columns.append(name)
    }
    
    public var moduleArguments: [String] {
        return columns
    }
}
