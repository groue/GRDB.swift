/// :nodoc:
public protocol _SQLCollectionVisitor: _FetchRequestVisitor {
    mutating func visit(_ collection: _SQLExpressionsArray) throws
    mutating func visit(_ collection: _SQLTableCollection) throws
}
