/// A Foreign Key that helps building associations.
public struct ForeignKey {
    let originColumns: [String]
    let destinationColumns: [String]?
    
    /// TODO
    public init(_ originColumns: [String], to destinationColumns: [String]? = nil) {
        self.originColumns = originColumns
        self.destinationColumns = destinationColumns
    }
    
    /// TODO
    public init(_ originColumns: [Column], to destinationColumns: [Column]? = nil) {
        self.init(originColumns.map { $0.name }, to: destinationColumns?.map { $0.name })
    }
}
