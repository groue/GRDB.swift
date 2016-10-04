/// FTS3 lets you define FTS3 virtual tables.
///
///     try db.create(virtualTable: "documents", using: FTS3()) { t in
///         t.column("content")
///     }
public struct FTS3 : VirtualTableModule {
    /// Creates a FTS3 module suitable for the Database
    /// `create(virtualTable:using:)` method.
    ///
    ///     try db.create(virtualTable: "documents", using: FTS3()) { t in
    ///         t.column("content")
    ///     }
    public init() {
    }
    
    // MARK: - VirtualTableModule Adoption
    
    /// The virtual table module name
    public let moduleName = "FTS3"
    
    /// Don't use this method.
    public func makeTableDefinition() -> FTS3TableDefinition {
        return FTS3TableDefinition()
    }
    
    /// Don't use this method.
    public func moduleArguments(_ definition: FTS3TableDefinition) -> [String] {
        return definition.columns
    }
}

/// The FTS3TableDefinition class lets you define columns of a FTS3 virtual table.
///
/// You don't create instances of this class. Instead, you use the Database
/// `create(virtualTable:using:)` method:
///
///     try db.create(virtualTable: "documents", using: FTS3()) { t in // t is FTS3TableDefinition
///         t.column("content")
///     }
public final class FTS3TableDefinition : VirtualTableDefinition {
    fileprivate var columns: [String] = []
    
    /// Appends a table column.
    ///
    ///     try db.create(virtualTable: "documents", using: FTS3()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// - parameter name: the column name.
    public func column(_ name: String) {
        columns.append(name)
    }
}
