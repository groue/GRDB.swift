/// :nodoc:
public protocol _SQLCollectionVisitor {
    mutating func visit(_ collection: _SQLExpressionsArray) throws
    mutating func visit<Request: SQLRequestProtocol>(_ request: Request) throws
}
