public struct JSONColumn: ColumnExpression, SQLJSONExpressible {
    public var name: String
    
    /// Creates a `JSONColumn` given its name.
    ///
    /// The name should be unqualified, such as `"score"`. Qualified name such
    /// as `"player.score"` are unsupported.
    public init(_ name: String) {
        self.name = name
    }
    
    /// Creates a `JSONColumn` given a `CodingKey`.
    public init(_ codingKey: some CodingKey) {
        self.name = codingKey.stringValue
    }
}
