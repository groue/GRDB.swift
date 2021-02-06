import Foundation

/// A subprotocol of `DecodableRecord` which has the program crash whenever it
/// could not decode a database row. Since GRDB 5.4, the use of
/// `FetchableRecord` is discouraged: you should use `DecodableRecord` instead.
public protocol FetchableRecord: DecodableRecord {
    /// Creates a record from `row`.
    ///
    /// For performance reasons, the row argument may be reused during the
    /// iteration of a fetch query. If you want to keep the row for later use,
    /// make sure to store a copy: `self.row = row.copy()`.
    init(row: Row)
}
