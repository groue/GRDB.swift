/// `StatementColumnConvertible` is free for `RawRepresentable` types whose raw
/// value is itself `StatementColumnConvertible`.
///
///     // If the RawValue adopts StatementColumnConvertible...
///     enum Color : Int {
///         case red
///         case white
///         case rose
///     }
///
///     // ... then the RawRepresentable type can freely
///     // adopt StatementColumnConvertible:
///     extension Color: StatementColumnConvertible { }
extension StatementColumnConvertible where Self: RawRepresentable, Self.RawValue: StatementColumnConvertible {
    @inline(__always)
    @inlinable
    public init?(sqliteStatement: SQLiteStatement, index: Int32) {
        guard let rawValue = RawValue(sqliteStatement: sqliteStatement, index: index) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }
}
