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
    public init(_ originColumns: [ColumnExpression], to destinationColumns: [ColumnExpression]? = nil) {
        self.init(originColumns.map { $0.name }, to: destinationColumns?.map { $0.name })
    }
}
