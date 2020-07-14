/// :nodoc:
public protocol _FetchRequestVisitor {
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws
}
