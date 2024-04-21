// MARK: - FetchRequest

/// A type that fetches and decodes database rows.
///
/// The main kinds of fetch requests are ``SQLRequest``
/// and ``QueryInterfaceRequest``:
///
/// ```swift
/// let lastName = "O'Reilly"
///
/// // SQLRequest
/// let request: SQLRequest<Player> = """
///     SELECT * FROM player WHERE lastName = \(lastName)
///     """
///
/// // QueryInterfaceRequest
/// let request = Player.filter(Column("lastName") == lastName)
///
/// // Use the request
/// try dbQueue.read { db in
///     let players = try request.fetchAll(db) // [Player]
/// }
/// ```
///
/// ## Topics
///
/// ### Counting the Results
///
/// - ``fetchCount(_:)``
///
/// ### Fetching Database Rows
///
/// - ``fetchCursor(_:)-9283d``
/// - ``fetchAll(_:)-7p809``
/// - ``fetchOne(_:)-9fafl``
/// - ``fetchSet(_:)-6bdrd``
///
/// ### Fetching Database Values
///
/// - ``fetchCursor(_:)-19f5g``
/// - ``fetchCursor(_:)-66xoi``
/// - ``fetchAll(_:)-1loau``
/// - ``fetchAll(_:)-28pne``
/// - ``fetchOne(_:)-44mvv``
/// - ``fetchOne(_:)-5hlkf``
/// - ``fetchSet(_:)-4hhtm``
/// - ``fetchSet(_:)-9wshm``
///
/// ### Fetching Records
///
/// - ``fetchCursor(_:)-2ah3q``
/// - ``fetchAll(_:)-vdos``
/// - ``fetchOne(_:)-2bq0k``
/// - ``fetchSet(_:)-4jdrq``
///
/// ### Preparing Database Requests
///
/// - ``makePreparedRequest(_:forSingleResult:)``
/// - ``PreparedRequest``
///
/// ### Adapting the Fetched Rows
///
/// - ``adapted(_:)``
/// - ``AdaptedFetchRequest``
///
/// ### Supporting Types
///
/// - ``AnyFetchRequest``
public protocol FetchRequest<RowDecoder>: SQLSubqueryable, DatabaseRegionConvertible {
    /// The type that tells how fetched database rows should be interpreted.
    associatedtype RowDecoder
    
    /// Returns a ``PreparedRequest``.
    ///
    /// The `singleResult` argument is a hint that a single result row will be
    /// consumed. Implementations can optionally use it to optimize the
    /// prepared statement, for example by adding a `LIMIT 1` SQL clause:
    ///
    /// ```swift
    /// // Calls makePreparedRequest(db, forSingleResult: true)
    /// try request.fetchOne(db)
    ///
    /// // Calls makePreparedRequest(db, forSingleResult: false)
    /// try request.fetchAll(db)
    /// ```
    ///
    /// - parameter db: A database connection.
    /// - parameter singleResult: A hint that a single result row will be
    ///   consumed.
    func makePreparedRequest(_ db: Database, forSingleResult singleResult: Bool) throws -> PreparedRequest
    
    /// Returns the number of rows fetched by the request.
    ///
    /// - parameter db: A database connection.
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    func fetchCount(_ db: Database) throws -> Int
}

extension FetchRequest {
    /// Returns the database region that the request feeds from.
    ///
    /// - parameter db: A database connection.
    public func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        try makePreparedRequest(db, forSingleResult: false).statement.databaseRegion
    }
}
