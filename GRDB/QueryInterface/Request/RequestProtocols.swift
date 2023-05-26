import Foundation

// MARK: - TypedRequest

/// A request that knows how to decode database rows.
public protocol TypedRequest<RowDecoder> {
    /// The type that can decode database rows.
    ///
    /// For example, it is `Player` in the request below:
    ///
    /// ```swift
    /// let request = Player.all()
    /// ```
    associatedtype RowDecoder
}

// MARK: - SelectionRequest

/// A request that can define the selected columns.
///
/// ## Topics
///
/// ### The SELECT Clause
///
/// - ``annotated(with:)-4qcem``
/// - ``annotated(with:)-6ehs4``
/// - ``annotatedWhenConnected(with:)``
/// - ``select(_:)-30yzl``
/// - ``select(_:)-7e2y5``
/// - ``select(literal:)``
/// - ``select(sql:arguments:)``
/// - ``selectWhenConnected(_:)``
public protocol SelectionRequest {
    /// Defines the result columns.
    ///
    /// The `selection` parameter is a closure that accepts a database
    /// connection and returns an array of result columns. It is evaluated when
    /// the request has an access to the database, and can perform database
    /// requests in order to build its result.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT id, name FROM player
    /// let request = Player.all().selectWhenConnected { db in
    ///     [Column("id"), Column("name")]
    /// }
    /// ```
    ///
    /// Any previous selection is discarded:
    ///
    /// ```swift
    /// // SELECT name FROM player
    /// let request = Player.all()
    ///     .selectWhenConnected { db in [Column("id")] }
    ///     .selectWhenConnected { db in [Column("name")] }
    /// ```
    ///
    /// - parameter selection: A closure that accepts a database connection and
    ///   returns an array of result columns.
    func selectWhenConnected(_ selection: @escaping (Database) throws -> [any SQLSelectable]) -> Self
    
    /// Appends result columns to the selected columns.
    ///
    /// The `selection` parameter is a closure that accepts a database
    /// connection and returns an array of result columns. It is evaluated when
    /// the request has an access to the database, and can perform database
    /// requests in order to build its result.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT *, score + bonus AS totalScore FROM player
    /// let request = Player.all().annotatedWhenConnected { db in
    ///     [(Column("score") + Column("bonus")).forKey("totalScore")]
    /// }
    /// ```
    ///
    /// - parameter selection: A closure that accepts a database connection and
    ///   returns an array of result columns.
    func annotatedWhenConnected(with selection: @escaping (Database) throws -> [any SQLSelectable]) -> Self
}

extension SelectionRequest {
    /// Defines the result columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT id, score FROM player
    /// let request = Player.all().select([Column("id"), Column("score")])
    /// ```
    ///
    /// Any previous selection is replaced:
    ///
    /// ```swift
    /// // SELECT score FROM player
    /// let request = Player.all()
    ///     .select([Column("id")])
    ///     .select([Column("score")])
    /// ```
    public func select(_ selection: [any SQLSelectable]) -> Self {
        selectWhenConnected { _ in selection }
    }
    
    /// Defines the result columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT id, score FROM player
    /// let request = Player.all().select(Column("id"), Column("score"))
    /// ```
    ///
    /// Any previous selection is discarded:
    ///
    /// ```swift
    /// // SELECT score FROM player
    /// let request = Player.all()
    ///     .select(Column("id"))
    ///     .select(Column("score"))
    /// ```
    public func select(_ selection: any SQLSelectable...) -> Self {
        select(selection)
    }
    
    /// Defines the result columns with an SQL string.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT id, name FROM player
    /// let request = Player.all()
    ///     .select(sql: "id, name")
    ///
    /// // SELECT id, IFNULL(name, 'Anonymous') FROM player
    /// let defaultName = "Anonymous"
    /// let request = Player.all()
    ///     .select(sql: "id, IFNULL(name, ?)", arguments: [defaultName])
    /// ```
    ///
    /// Any previous selection is discarded:
    ///
    /// ```swift
    /// // SELECT score FROM player
    /// let request = Player.all()
    ///     .select(sql: "id")
    ///     .select(sql: "name")
    /// ```
    public func select(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        select(SQL(sql: sql, arguments: arguments))
    }
    
    /// Defines the result columns with an ``SQL`` literal.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// // SELECT id, IFNULL(name, 'Anonymous') FROM player
    /// let defaultName = "Anonymous"
    /// let request = Player.all()
    ///     .select(literal: "id, IFNULL(name, \(defaultName))")
    /// ```
    ///
    /// Any previous selection is discarded:
    ///
    /// ```swift
    /// // SELECT IFNULL(name, 'Anonymous') FROM player
    /// let request = Player.all()
    ///     .select(literal: "id")
    ///     .select(literal: "IFNULL(name, \(defaultName))")
    /// ```
    public func select(literal sqlLiteral: SQL) -> Self {
        // NOT TESTED
        select(sqlLiteral)
    }
    
    /// Appends result columns to the selected columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT *, score + bonus AS totalScore FROM player
    /// let totalScore = (Column("score") + Column("bonus")).forKey("totalScore")
    /// let request = Player.all().annotated(with: [totalScore])
    /// ```
    public func annotated(with selection: [any SQLSelectable]) -> Self {
        annotatedWhenConnected(with: { _ in selection })
    }
    
    /// Appends result columns to the selected columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT *, score + bonus AS totalScore FROM player
    /// let totalScore = (Column("score") + Column("bonus")).forKey("totalScore")
    /// let request = Player.all().annotated(with: totalScore)
    /// ```
    public func annotated(with selection: any SQLSelectable...) -> Self {
        annotated(with: selection)
    }
}

// MARK: - FilteredRequest

/// A request that can filter database rows.
///
/// The filter applies to the `WHERE` clause, or to the `ON` clause of
/// an SQL join.
///
/// ## Topics
///
/// ### The WHERE and JOIN ON Clauses
///
/// - ``all()``
/// - ``filter(_:)``
/// - ``filter(literal:)``
/// - ``filter(sql:arguments:)``
/// - ``filterWhenConnected(_:)``
/// - ``none()``
public protocol FilteredRequest {
    /// Filters the fetched rows with a boolean SQL expression.
    ///
    /// The `predicate` parameter is a closure that accepts a database
    /// connection and returns a boolean SQL expression. It is evaluated when
    /// the request has an access to the database, and can perform database
    /// requests in order to build its result.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player WHERE name = 'O''Brien'
    /// let name = "O'Brien"
    /// let request = Player.all().filterWhenConnected { db in
    ///     Column("name") == name
    /// }
    /// ```
    ///
    /// - parameter predicate: A closure that accepts a database connection and
    ///   returns a boolean SQL expression.
    func filterWhenConnected(_ predicate: @escaping (Database) throws -> any SQLExpressible) -> Self
}

extension FilteredRequest {
    // Accept SQLSpecificExpressible instead of SQLExpressible, so that we
    // prevent the `Player.filter(42)` misuse.
    // See https://github.com/groue/GRDB.swift/pull/864
    /// Filters the fetched rows with a boolean SQL expression.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player WHERE name = 'O''Brien'
    /// let name = "O'Brien"
    /// let request = Player.all().filter(Column("name") == name)
    /// ```
    public func filter(_ predicate: some SQLSpecificExpressible) -> Self {
        filterWhenConnected { _ in predicate }
    }
    
    /// Filters the fetched rows with an SQL string.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player WHERE name = 'O''Brien'
    /// let name = "O'Brien"
    /// let request = Player.all().filter(sql: "name = ?", arguments: [name])
    /// ```
    public func filter(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        filter(SQL(sql: sql, arguments: arguments))
    }
    
    /// Filters the fetched rows with an ``SQL`` literal.
    ///
    /// ``SQL`` literals allow you to safely embed raw values in your SQL,
    /// without any risk of syntax errors or SQL injection:
    ///
    /// ```swift
    /// // SELECT * FROM player WHERE name = 'O''Brien'
    /// let name = "O'Brien"
    /// let request = Player.all().filter(literal: "name = \(name)")
    /// ```
    public func filter(literal sqlLiteral: SQL) -> Self {
        // NOT TESTED
        filter(sqlLiteral)
    }
    
    /// Returns an empty request that fetches no row.
    public func none() -> Self {
        filterWhenConnected { _ in false }
    }
  
  /// Returns `self`: a request that fetches all rows from this request.
  ///
  /// This method, which does nothing, exists in order to match ``none()``.
  public func all() -> Self {
      self
  }
}

// MARK: - TableRequest

/// A request that feeds from a database table
///
/// ## Topics
///
/// ## The Database Table
///
/// - ``databaseTableName``
///
/// ### Instance Methods
///
/// - ``aliased(_:)``
/// - ``TableAlias``
///
/// ### The WHERE Clause
/// 
/// - ``filter(id:)``
/// - ``filter(ids:)``
/// - ``filter(key:)-1p9sq``
/// - ``filter(key:)-2te6v``
/// - ``filter(keys:)-6ggt1``
/// - ``filter(keys:)-8fbn9``
/// - ``matching(_:)-3s3zr``
/// - ``matching(_:)-7c1e8``
///
/// ### The GROUP BY and HAVING Clauses
///
/// - ``groupByPrimaryKey()``
///
/// ### The ORDER BY Clause
///
/// - ``orderByPrimaryKey()``
public protocol TableRequest {
    /// The name of the database table
    var databaseTableName: String { get }
    
    /// Returns a request that can be referred to with the provided alias.
    ///
    /// Use this method when you need to refer to this request from
    /// another request.
    ///
    /// The first example fetches posthumous books:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord { }
    /// struct Book: TableRecord, FetchableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// // SELECT book.*
    /// // FROM book
    /// // JOIN author ON author.id = book.authorId
    /// // WHERE book.publishDate >= author.deathDate
    /// let authorAlias = TableAlias()
    /// let posthumousBooks = try Book
    ///     .joining(required: Book.author.aliased(authorAlias))
    ///     .filter(Column("publishDate") >= authorAlias[Column("deathDate")])
    ///     .fetchAll(db)
    /// ```
    ///
    /// The second example sorts books by author name first, and then by title:
    ///
    /// ```swift
    /// // SELECT book.*
    /// // FROM book
    /// // JOIN author ON author.id = book.authorId
    /// // ORDER BY author.name, book.title
    /// let authorAlias = TableAlias()
    /// let books = try Book
    ///     .joining(required: Book.author.aliased(authorAlias))
    ///     .order(authorAlias[Column("name")], Column("title"))
    ///     .fetchAll(db)
    /// ```
    ///
    /// The third example uses named ``TableAlias`` so that SQL snippets can
    /// refer to SQL tables with those names:
    ///
    /// ```swift
    /// // SELECT b.*
    /// // FROM book b
    /// // JOIN author a ON a.id = b.authorId
    /// //              AND a.countryCode = 'FR'
    /// // WHERE b.publishDate >= a.deathDate
    /// let bookAlias = TableAlias(name: "b")
    /// let authorAlias = TableAlias(name: "a")
    /// let posthumousFrenchBooks = try Book.aliased(bookAlias)
    ///     .joining(required: Book.author.aliased(authorAlias)
    ///         .filter(sql: "a.countryCode = ?", arguments: ["FR"]))
    ///     .filter(sql: "b.publishDate >= a.deathDate")
    ///     .fetchAll(db)
    /// ```
    func aliased(_ alias: TableAlias) -> Self
}

extension TableRequest where Self: FilteredRequest, Self: TypedRequest {
    
    /// Filters by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// // SELECT * FROM player WHERE id = 1
    /// let request = Player.all().filter(key: 1)
    ///
    /// // SELECT * FROM country WHERE code = 'FR'
    /// let request = Country.all().filter(key: "FR")
    /// ```
    ///
    /// - parameter key: A primary key
    public func filter(key: some DatabaseValueConvertible) -> Self {
        if key.databaseValue.isNull {
            return none()
        }
        return filter(keys: [key])
    }
    
    /// Filters by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// // SELECT * FROM player WHERE id = IN (1, 2, 3)
    /// let request = Player.all().filter(keys: [1, 2, 3])
    ///
    /// // SELECT * FROM country WHERE code = IN ('FR', 'US')
    /// let request = Country.all().filter(keys: ["FR", "US"])
    /// ```
    ///
    /// - parameter keys: A collection of primary keys
    public func filter<Sequence: Swift.Sequence>(keys: Sequence)
    -> Self
    where Sequence.Element: DatabaseValueConvertible
    {
        // In order to encode keys in the database, we perform a runtime check
        // for EncodableRecord, and look for a customized encoding strategy.
        // Such dynamic dispatch is unusual in GRDB, but static dispatch
        // (customizing TableRequest where RowDecoder: EncodableRecord) would
        // make it impractical to define `filter(id:)`, `fetchOne(_:key:)`,
        // `deleteAll(_:ids:)` etc.
        if let recordType = RowDecoder.self as? any EncodableRecord.Type {
            if Sequence.Element.self == Date.self || Sequence.Element.self == Optional<Date>.self {
                let strategy = recordType.databaseDateEncodingStrategy
                let keys = keys.compactMap { ($0 as! Date?).flatMap(strategy.encode)?.databaseValue }
                return filter(rawKeys: keys)
            } else if Sequence.Element.self == UUID.self || Sequence.Element.self == Optional<UUID>.self {
                let strategy = recordType.databaseUUIDEncodingStrategy
                let keys = keys.map { ($0 as! UUID?).map(strategy.encode)?.databaseValue }
                return filter(rawKeys: keys)
            }
        }
        
        return filter(rawKeys: keys)
    }
    
    /// Creates a request filtered by primary key.
    ///
    ///     // SELECT * FROM player WHERE ... id IN (1, 2, 3)
    ///     let request = try Player...filter(rawKeys: [1, 2, 3])
    ///
    /// - parameter keys: A collection of primary keys
    func filter<Keys>(rawKeys: Keys) -> Self
    where Keys: Sequence, Keys.Element: DatabaseValueConvertible
    {
        // Don't bother removing NULLs. We'd lose CPU cycles, and this does not
        // change the SQLite results anyway.
        let expressions = rawKeys.map {
            $0.databaseValue.sqlExpression
        }
        
        if expressions.isEmpty {
            // Don't hit the database
            return none()
        }
        
        let databaseTableName = self.databaseTableName
        return filterWhenConnected { db in
            let primaryKey = try db.primaryKey(databaseTableName)
            GRDBPrecondition(
                primaryKey.columns.count == 1,
                "Requesting by key requires a single-column primary key in the table \(databaseTableName)")
            return SQLCollection.array(expressions).contains(Column(primaryKey.columns[0]).sqlExpression)
        }
    }
    
    /// Filters by primary or unique key.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player WHERE id = 1
    /// let request = Player.all().filter(key: ["id": 1])
    ///
    /// // SELECT * FROM player WHERE email = 'arthur@example.com'
    /// let request = Player.all().filter(key: ["email": "arthur@example.com"])
    ///
    /// // SELECT * FROM citizenship WHERE citizenId = 1 AND countryCode = 'FR'
    /// let request = Citizenship.all().filter(key: [
    ///     "citizenId": 1,
    ///     "countryCode": "FR",
    /// ])
    /// ```
    ///
    /// When executed, this request raises a fatal error if no unique index
    /// exists on a subset of the key columns.
    ///
    /// - parameter key: A key dictionary.
    public func filter(key: [String: (any DatabaseValueConvertible)?]?) -> Self {
        guard let key else {
            return none()
        }
        return filter(keys: [key])
    }
    
    /// Filters by primary or unique key.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player WHERE id = 1
    /// let request = Player.all().filter(keys: [["id": 1]])
    ///
    /// // SELECT * FROM player WHERE email = 'arthur@example.com'
    /// let request = Player.all().filter(keys: [["email": "arthur@example.com"]])
    ///
    /// // SELECT * FROM citizenship WHERE citizenId = 1 AND countryCode = 'FR'
    /// let request = Citizenship.all().filter(keys: [
    ///     ["citizenId": 1, "countryCode": "FR"],
    /// ])
    /// ```
    ///
    /// When executed, this request raises a fatal error if no unique index
    /// exists on a subset of the key columns.
    ///
    /// - parameter keys: An array of key dictionaries.
    public func filter(keys: [[String: (any DatabaseValueConvertible)?]]) -> Self {
        if keys.isEmpty {
            return none()
        }
        
        let databaseTableName = self.databaseTableName
        return filterWhenConnected { db in
            try keys
                .map { key in
                    // Prevent filter(keys: [["foo": 1, "bar": 2]]) where
                    // ("foo", "bar") do not contain a unique key (primary key
                    // or unique index).
                    guard let columns = try db.columnsForUniqueKey(key.keys, in: databaseTableName) else {
                        fatalError("""
                            table \(databaseTableName) has no unique key on column(s) \
                            \(key.keys.sorted().joined(separator: ", "))
                            """)
                    }
                    
                    let lowercaseColumns = columns.map { $0.lowercased() }
                    return key
                        // Preserve ordering of columns in the unique index
                        .sorted { (kv1, kv2) in
                            guard let index1 = lowercaseColumns.firstIndex(of: kv1.key.lowercased()) else {
                                // We allow extra columns which are not in the unique key
                                // Put them last in the query
                                return false
                            }
                            guard let index2 = lowercaseColumns.firstIndex(of: kv2.key.lowercased()) else {
                                // We allow extra columns which are not in the unique key
                                // Put them last in the query
                                return true
                            }
                            return index1 < index2
                        }
                        .map { (column, value) in Column(column) == value }
                        .joined(operator: .and)
                }
                .joined(operator: .or)
        }
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension TableRequest
where Self: FilteredRequest,
      Self: TypedRequest,
      RowDecoder: Identifiable,
      RowDecoder.ID: DatabaseValueConvertible
{
    /// Filters by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// // SELECT * FROM player WHERE id = 1
    /// let request = Player.all().filter(id: 1)
    ///
    /// // SELECT * FROM country WHERE code = 'FR'
    /// let request = Country.all().filter(id: "FR")
    /// ```
    ///
    /// - parameter id: A primary key
    public func filter(id: RowDecoder.ID) -> Self {
        filter(key: id)
    }
    
    /// Filters by primary key.
    ///
    /// All single-column primary keys are supported:
    ///
    /// ```swift
    /// // SELECT * FROM player WHERE id = IN (1, 2, 3)
    /// let request = Player.all().filter(ids: [1, 2, 3])
    ///
    /// // SELECT * FROM country WHERE code = IN ('FR', 'US')
    /// let request = Country.all().filter(ids: ["FR", "US"])
    /// ```
    ///
    /// - parameter ids: A collection of primary keys
    public func filter<IDS>(ids: IDS) -> Self
    where IDS: Collection, IDS.Element == RowDecoder.ID
    {
        filter(keys: ids)
    }
}

extension TableRequest where Self: OrderedRequest {
    /// Sorts the fetched rows according to the primary key.
    ///
    /// All primary keys are supported:
    ///
    /// ```swift
    /// // SELECT * FROM player ORDER BY id
    /// let request = Player.all().orderByPrimaryKey()
    ///
    /// // SELECT * FROM country ORDER BY code
    /// let request = Country.all().orderByPrimaryKey()
    ///
    /// // SELECT * FROM citizenship ORDER BY citizenId, countryCode
    /// let request = Citizenship.all().orderByPrimaryKey()
    /// ```
    ///
    /// Any previous ordering is discarded.
    public func orderByPrimaryKey() -> Self {
        let tableName = self.databaseTableName
        return orderWhenConnected { db in
            try db.primaryKey(tableName).columns.map(SQLExpression.column)
        }
    }
}

extension TableRequest where Self: AggregatingRequest {
    /// Returns an aggregate request grouped on the primary key.
    ///
    /// Any previous grouping is discarded.
    public func groupByPrimaryKey() -> Self {
        let tableName = self.databaseTableName
        return groupWhenConnected { db in
            let primaryKey = try db.primaryKey(tableName)
            if let rowIDColumn = primaryKey.rowIDColumn {
                // Prefer the user-provided name of the rowid:
                //
                //  // CREATE TABLE player (id INTEGER PRIMARY KEY, ...)
                //  // SELECT * FROM player GROUP BY id
                //  Player.all().groupByPrimaryKey()
                return [Column(rowIDColumn)]
            } else if primaryKey.tableHasRowID {
                // Prefer the rowid
                //
                //  // CREATE TABLE player (uuid TEXT NOT NULL PRIMARY KEY, ...)
                //  // SELECT * FROM player GROUP BY rowid
                //  Player.all().groupByPrimaryKey()
                return [.rowID]
            } else {
                // WITHOUT ROWID table: group by primary key columns
                //
                //  // CREATE TABLE player (uuid TEXT NOT NULL PRIMARY KEY, ...) WITHOUT ROWID
                //  // SELECT * FROM player GROUP BY uuid
                //  Player.all().groupByPrimaryKey()
                return primaryKey.columns.map { Column($0) }
            }
        }
    }
}

// MARK: - AggregatingRequest

/// A request that can aggregate database rows.
///
/// ## Topics
///
/// ### The GROUP BY Clause
///
/// - ``group(_:)-edak``
/// - ``group(_:)-4216o``
/// - ``group(literal:)``
/// - ``group(sql:arguments:)``
/// - ``groupWhenConnected(_:)``
///
/// ### The HAVING Clause
///
/// - ``having(_:)``
/// - ``having(literal:)``
/// - ``having(sql:arguments:)``
/// - ``havingWhenConnected(_:)``
public protocol AggregatingRequest {
    /// Returns an aggregate request grouped on the given SQL expressions.
    ///
    /// The `expressions` parameter is a closure that accepts a database
    /// connection and returns an array of grouping SQL expressions. It is
    /// evaluated when the request has an access to the database, and can
    /// perform database requests in order to build its result.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT teamId, MAX(score)
    /// // FROM player
    /// // GROUP BY teamId
    /// let request = Player
    ///     .select(Column("teamId"), max(Column("score")))
    ///     .groupWhenConnected { db in [Column("teamId")] }
    /// ```
    ///
    /// Any previous grouping is discarded.
    ///
    /// - parameter expressions: A closure that accepts a database connection
    ///   and returns an array of SQL expressions.
    func groupWhenConnected(_ expressions: @escaping (Database) throws -> [any SQLExpressible]) -> Self
    
    /// Filters the aggregated groups with a boolean SQL expression.
    ///
    /// The `predicate` parameter is a closure that accepts a database
    /// connection and returns a boolean SQL expression. It is evaluated when
    /// the request has an access to the database, and can perform database
    /// requests in order to build its result.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT teamId, MAX(score)
    /// // FROM player
    /// // GROUP BY teamId
    /// // HAVING MAX(score) > 1000
    /// let request = Player
    ///     .select(Column("teamId"), max(Column("score")))
    ///     .group(Column("teamId"))
    ///     .havingWhenConnected { db in max(Column("score")) > 1000 }
    /// ```
    ///
    /// - parameter predicate: A closure that accepts a database connection and
    ///   returns a boolean SQL expression.
    func havingWhenConnected(_ predicate: @escaping (Database) throws -> any SQLExpressible) -> Self
}

extension AggregatingRequest {
    /// Returns an aggregate request grouped on the given SQL expressions.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT teamId, MAX(score)
    /// // FROM player
    /// // GROUP BY teamId
    /// let request = Player
    ///     .select(Column("teamId"), max(Column("score")))
    ///     .group([Column("teamId")])
    /// ```
    ///
    /// Any previous grouping is discarded.
    ///
    /// - parameter expressions: An array of SQL expressions.
    public func group(_ expressions: [any SQLExpressible]) -> Self {
        groupWhenConnected { _ in expressions }
    }
    
    /// Returns an aggregate request grouped on the given SQL expressions.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT teamId, MAX(score)
    /// // FROM player
    /// // GROUP BY teamId
    /// let request = Player
    ///     .select(Column("teamId"), max(Column("score")))
    ///     .group(Column("teamId"))
    /// ```
    ///
    /// Any previous grouping is discarded.
    ///
    /// - parameter expressions: An array of SQL expressions.
    public func group(_ expressions: any SQLExpressible...) -> Self {
        group(expressions)
    }
    
    /// Returns an aggregate request grouped on an SQL string.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT teamId, MAX(score)
    /// // FROM player
    /// // GROUP BY teamId
    /// let request = Player
    ///     .select(Column("teamId"), max(Column("score")))
    ///     .group(sql: "teamId")
    /// ```
    ///
    /// Any previous grouping is discarded.
    public func group(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        group(SQL(sql: sql, arguments: arguments))
    }
    
    /// Returns an aggregate request grouped on an ``SQL`` literal.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT teamId, MAX(score)
    /// // FROM player
    /// // GROUP BY teamId
    /// let request = Player
    ///     .select(Column("teamId"), max(Column("score")))
    ///     .group(literal: "teamId")
    /// ```
    ///
    /// Any previous grouping is discarded.
    public func group(literal sqlLiteral: SQL) -> Self {
        // NOT TESTED
        group(sqlLiteral)
    }
    
    /// Filters the aggregated groups with a boolean SQL expression.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT teamId, MAX(score)
    /// // FROM player
    /// // GROUP BY teamId
    /// // HAVING MAX(score) > 1000
    /// let request = Player
    ///     .select(Column("teamId"), max(Column("score")))
    ///     .group(Column("teamId"))
    ///     .having(max(Column("score")) > 1000)
    /// ```
    public func having(_ predicate: some SQLExpressible) -> Self {
        havingWhenConnected { _ in predicate }
    }
    
    /// Filters the aggregated groups with an SQL string.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT teamId, MAX(score)
    /// // FROM player
    /// // GROUP BY teamId
    /// // HAVING MAX(score) > 1000
    /// let request = Player
    ///     .select(Column("teamId"), max(Column("score")))
    ///     .group(Column("teamId"))
    ///     .having(sql: "MAX(score) > 1000")
    /// ```
    public func having(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        having(SQL(sql: sql, arguments: arguments))
    }
    
    /// Filters the aggregated groups with an ``SQL`` literal.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT teamId, MAX(score)
    /// // FROM player
    /// // GROUP BY teamId
    /// // HAVING MAX(score) > 1000
    /// let request = Player
    ///     .select(Column("teamId"), max(Column("score")))
    ///     .group(Column("teamId"))
    ///     .having(literal: "MAX(score) > 1000")
    /// ```
    public func having(literal sqlLiteral: SQL) -> Self {
        // NOT TESTED
        having(sqlLiteral)
    }
}

// MARK: - OrderedRequest

/// A request that can sort database rows.
///
/// ## Topics
///
/// ### The ORDER BY Clause
///
/// - ``order(_:)-63rzl``
/// - ``order(_:)-6co0m``
/// - ``order(literal:)``
/// - ``order(sql:arguments:)``
/// - ``orderWhenConnected(_:)``
/// - ``reversed()``
/// - ``unordered()``
public protocol OrderedRequest {
    /// Sorts the fetched rows according to the given SQL ordering terms.
    ///
    /// The `orderings` parameter is a closure that accepts a database
    /// connection and returns an array of SQL ordering terms. It is evaluated
    /// when the request has an access to the database, and can perform database
    /// requests in order to build its result.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = Player.all().orderWhenConnected { db in
    ///     [Column("score").desc, Column("name")]
    /// }
    /// ```
    ///
    /// Any previous ordering is discarded:
    ///
    /// ```swift
    /// // SELECT * FROM player ORDER BY name
    /// let request = Player.all()
    ///     .orderWhenConnected { db in [Column("score").desc] }
    ///     .orderWhenConnected { db in [Column("name")] }
    /// ```
    ///
    /// - parameter orderings: A closure that accepts a database connection and
    ///   returns an array of SQL ordering terms.
    func orderWhenConnected(_ orderings: @escaping (Database) throws -> [any SQLOrderingTerm]) -> Self
    
    /// Returns a request with reversed ordering.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player ORDER BY name DESC
    /// let request = Player.all()
    ///     .order(Column("name"))
    ///     .reversed()
    /// ```
    ///
    /// If no ordering was already specified, this method has no effect:
    ///
    /// ```swift
    /// // SELECT * FROM player
    /// let request = Player.all().reversed()
    /// ```
    func reversed() -> Self
    
    /// Returns a request without any ordering.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player
    /// let request = Player.all()
    ///     .order(Column("name"))
    ///     .unordered()
    /// ```
    func unordered() -> Self
}

extension OrderedRequest {
    /// Sorts the fetched rows according to the given SQL ordering terms.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = Player.all()
    ///     .order(Column("score").desc, Column("name"))
    /// ```
    ///
    /// Any previous ordering is discarded:
    ///
    /// ```swift
    /// // SELECT * FROM player ORDER BY name
    /// let request = Player.all()
    ///     .order(Column("score").desc)
    ///     .order(Column("name"))
    /// ```
    public func order(_ orderings: any SQLOrderingTerm...) -> Self {
        orderWhenConnected { _ in orderings }
    }
    
    /// Sorts the fetched rows according to the given SQL ordering terms.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = Player.all()
    ///     .order([Column("score").desc, Column("name")])
    /// ```
    ///
    /// Any previous ordering is discarded:
    ///
    /// ```swift
    /// // SELECT * FROM player ORDER BY name
    /// let request = Player.all()
    ///     .order([Column("score").desc])
    ///     .order([Column("name")])
    /// ```
    public func order(_ orderings: [any SQLOrderingTerm]) -> Self {
        orderWhenConnected { _ in orderings }
    }
    
    /// Sorts the fetched rows according to the given SQL string.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = Player.all()
    ///     .order(sql: "score DESC, name")
    /// ```
    ///
    /// Any previous ordering is discarded.
    public func order(sql: String, arguments: StatementArguments = StatementArguments()) -> Self {
        order(SQL(sql: sql, arguments: arguments))
    }
    
    /// Sorts the fetched rows according to the given ``SQL`` literal.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT * FROM player ORDER BY score DESC, name
    /// let request = Player.all()
    ///     .order(literal: "score DESC, name")
    /// ```
    ///
    /// Any previous ordering is discarded.
    public func order(literal sqlLiteral: SQL) -> Self {
        // NOT TESTED
        order(sqlLiteral)
    }
}

// MARK: - JoinableRequest

/// A request that can join and prefetch associations.
///
/// `JoinableRequest` is adopted by ``QueryInterfaceRequest`` and all
/// types conforming to ``Association``.
///
/// It provides the methods that build requests involving several tables linked
/// through associations.
///
/// ## Topics
///
/// ### Extending the Selection with Columns of Associated Records
///
/// - ``annotated(withOptional:)``
/// - ``annotated(withRequired:)``
///
/// ### Prefetching Associated Records
///
/// - ``including(all:)``
/// - ``including(optional:)``
/// - ``including(required:)``
///
/// ### Joining Associated Records
///
/// - ``joining(optional:)``
/// - ``joining(required:)``
public protocol JoinableRequest<RowDecoder>: TypedRequest {
    /// Creates a request that prefetches an association.
    func _including(all association: _SQLAssociation) -> Self
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned request does not
    /// require that the associated database table contains a matching row.
    func _including(optional association: _SQLAssociation) -> Self
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned request requires
    /// that the associated database table contains a matching row.
    func _including(required association: _SQLAssociation) -> Self
    
    /// Creates a request that joins an association. The columns of the
    /// associated record are not selected. The returned request does not
    /// require that the associated database table contains a matching row.
    func _joining(optional association: _SQLAssociation) -> Self
    
    /// Creates a request that joins an association. The columns of the
    /// associated record are not selected. The returned request requires
    /// that the associated database table contains a matching row.
    func _joining(required association: _SQLAssociation) -> Self
}

extension JoinableRequest {
    /// Returns a request that fetches all records associated with each record
    /// in this request.
    ///
    /// For example, we can fetch authors along with their books:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable {
    ///     static let books = hasMany(Book.self)
    /// }
    /// struct Book: TableRecord, FetchableRecord, Decodable { }
    ///
    /// struct AuthorInfo: FetchableRecord, Decodable {
    ///     var author: Author
    ///     var books: [Book]
    /// }
    ///
    /// let authorInfos = try Author.all()
    ///     .including(all: Author.books)
    ///     .asRequest(of: AuthorInfo.self)
    ///     .fetchAll(db)
    /// ```
    public func including<A: AssociationToMany>(all association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        _including(all: association._sqlAssociation)
    }
    
    /// Returns a request that fetches the eventual record associated with each
    /// record of this request.
    ///
    /// For example, we can fetch books along with their eventual author:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable { }
    /// struct Book: TableRecord, FetchableRecord, Decodable {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct BookInfo: FetchableRecord, Decodable {
    ///     var book: Book
    ///     var author: Author?
    /// }
    ///
    /// let bookInfos = try Book.all()
    ///     .including(optional: Book.author)
    ///     .asRequest(of: BookInfo.self)
    ///     .fetchAll(db)
    /// ```
    public func including<A: Association>(optional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        _including(optional: association._sqlAssociation)
    }
    
    /// Returns a request that fetches the record associated with each record in
    /// this request. Records that do not have an associated record
    /// are discarded.
    ///
    /// For example, we can fetch books along with their eventual author:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable { }
    /// struct Book: TableRecord, FetchableRecord, Decodable {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct BookInfo: FetchableRecord, Decodable {
    ///     var book: Book
    ///     var author: Author
    /// }
    ///
    /// let bookInfos = try Book.all()
    ///     .including(required: Book.author)
    ///     .asRequest(of: BookInfo.self)
    ///     .fetchAll(db)
    /// ```
    public func including<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        _including(required: association._sqlAssociation)
    }
    
    /// Returns a request that joins each record of this request to its
    /// eventual associated record.
    public func joining<A: Association>(optional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        _joining(optional: association._sqlAssociation)
    }
    
    /// Returns a request that joins each record of this request to its
    /// associated record. Records that do not have an associated record
    /// are discarded.
    ///
    /// For example, we can fetch only books whose author is French:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable { }
    /// struct Book: TableRecord, FetchableRecord, Decodable {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// let frenchAuthors = Book.author.filter(Column("countryCode") == "FR")
    /// let bookInfos = try Book.all()
    ///     .joining(required: frenchAuthors)
    ///     .fetchAll(db)
    /// ```
    public func joining<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        _joining(required: association._sqlAssociation)
    }
}

extension JoinableRequest where Self: SelectionRequest {
    /// Appends the columns of the eventual associated record to the
    /// selected columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT player.*, team.color
    /// // FROM player LEFT JOIN team ...
    /// let teamColor = Player.team.select(Column("color"))
    /// let request = Player.all().annotated(withOptional: teamColor)
    /// ```
    ///
    /// This method performs the exact same SQL request as
    /// ``including(optional:)``. The difference is in the record type that can
    /// decode such a request: the columns of the associated record must be
    /// decoded at the same level as the main record. For example:
    ///
    /// ```swift
    /// struct PlayerWithTeamColor: FetchableRecord, Decodable {
    ///     var player: Player
    ///     var color: String?
    /// }
    /// try dbQueue.read { db in
    ///     let players = try request
    ///         .asRequest(of: PlayerWithTeamColor.self)
    ///         .fetchAll(db)
    /// }
    /// ```
    ///
    /// This method is a convenience. You can build the same request with
    /// ``TableAlias``, ``SelectionRequest/annotated(with:)-6ehs4``, and
    /// ``JoinableRequest/joining(optional:)``:
    ///
    /// ```swift
    /// let teamAlias = TableAlias()
    /// let request = Player.all()
    ///     .annotated(with: teamAlias[Column("color")])
    ///     .joining(optional: Player.team.aliased(teamAlias))
    /// ```
    public func annotated<A: Association>(withOptional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        // TODO: find a way to prefix the selection with the association key
        let alias = TableAlias()
        let selection = association._sqlAssociation.destination.relation.selectionPromise
        return self
            .joining(optional: association.aliased(alias))
            .annotatedWhenConnected(with: { db in
                try selection.resolve(db).map { selection in
                    selection.qualified(with: alias)
                }
            })
    }
    
    /// Appends the columns of the associated record to the selected columns.
    /// Records that do not have an associated record are discarded.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT player.*, team.color
    /// // FROM player JOIN team ...
    /// let teamColor = Player.team.select(Column("color"))
    /// let request = Player.all().annotated(withRequired: teamColor)
    /// ```
    ///
    /// This method performs the exact same SQL request as
    /// ``including(required:)``. The difference is in the record type that can
    /// decode such a request: the columns of the associated record must be
    /// decoded at the same level as the main record. For example:
    ///
    /// ```swift
    /// struct PlayerWithTeamColor: FetchableRecord, Decodable {
    ///     var player: Player
    ///     var color: String
    /// }
    /// try dbQueue.read { db in
    ///     let players = try request
    ///         .asRequest(of: PlayerWithTeamColor.self)
    ///         .fetchAll(db)
    /// }
    /// ```
    ///
    /// This method is a convenience. You can build the same request with
    /// ``TableAlias``, ``SelectionRequest/annotated(with:)-6ehs4``, and
    /// ``JoinableRequest/joining(required:)``:
    ///
    /// ```swift
    /// let teamAlias = TableAlias()
    /// let request = Player.all()
    ///     .annotated(with: teamAlias[Column("color")])
    ///     .joining(required: Player.team.aliased(teamAlias))
    /// ```
    public func annotated<A: Association>(withRequired association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        // TODO: find a way to prefix the selection with the association key
        let selection = association._sqlAssociation.destination.relation.selectionPromise
        let alias = TableAlias()
        return self
            .joining(required: association.aliased(alias))
            .annotatedWhenConnected(with: { db in
                try selection.resolve(db).map { selection in
                    selection.qualified(with: alias)
                }
            })
    }
}

// MARK: - DerivableRequest

/// `DerivableRequest` is the base protocol for ``QueryInterfaceRequest``
/// and ``Association``.
///
/// Most features of `DerivableRequest` come from the protocols it
/// inherits from.
///
/// ## Topics
///
/// ### Instance Methods
///
/// - ``TableRequest/aliased(_:)``
/// - ``TableAlias``
///
/// ### The WITH Clause
///
/// - ``with(_:)``
///
/// ### The SELECT Clause
///
/// - ``SelectionRequest/annotated(with:)-4qcem``
/// - ``SelectionRequest/annotated(with:)-6ehs4``
/// - ``SelectionRequest/annotatedWhenConnected(with:)``
/// - ``distinct()``
/// - ``SelectionRequest/select(_:)-30yzl``
/// - ``SelectionRequest/select(_:)-7e2y5``
/// - ``SelectionRequest/select(literal:)``
/// - ``SelectionRequest/select(sql:arguments:)``
/// - ``SelectionRequest/selectWhenConnected(_:)``
///
/// ### The WHERE Clause
///
/// - ``FilteredRequest/all()``
/// - ``FilteredRequest/filter(_:)``
/// - ``TableRequest/filter(id:)``
/// - ``TableRequest/filter(ids:)``
/// - ``TableRequest/filter(key:)-1p9sq``
/// - ``TableRequest/filter(key:)-2te6v``
/// - ``TableRequest/filter(keys:)-6ggt1``
/// - ``TableRequest/filter(keys:)-8fbn9``
/// - ``FilteredRequest/filter(literal:)``
/// - ``FilteredRequest/filter(sql:arguments:)``
/// - ``FilteredRequest/filterWhenConnected(_:)``
/// - ``TableRequest/matching(_:)-3s3zr``
/// - ``TableRequest/matching(_:)-7c1e8``
/// - ``FilteredRequest/none()``
///
/// ### The GROUP BY and HAVING Clauses
///
/// - ``AggregatingRequest/group(_:)-edak``
/// - ``AggregatingRequest/group(_:)-4216o``
/// - ``AggregatingRequest/group(literal:)``
/// - ``AggregatingRequest/group(sql:arguments:)``
/// - ``TableRequest/groupByPrimaryKey()``
/// - ``AggregatingRequest/groupWhenConnected(_:)``
/// - ``AggregatingRequest/having(_:)``
/// - ``AggregatingRequest/having(literal:)``
/// - ``AggregatingRequest/having(sql:arguments:)``
/// - ``AggregatingRequest/havingWhenConnected(_:)``
///
/// ### The ORDER BY Clause
///
/// - ``OrderedRequest/order(_:)-63rzl``
/// - ``OrderedRequest/order(_:)-6co0m``
/// - ``OrderedRequest/order(literal:)``
/// - ``OrderedRequest/order(sql:arguments:)``
/// - ``OrderedRequest/orderWhenConnected(_:)``
/// - ``TableRequest/orderByPrimaryKey()``
/// - ``OrderedRequest/reversed()``
/// - ``OrderedRequest/unordered()``
///
/// ### Associations
///
/// - ``JoinableRequest/annotated(withOptional:)``
/// - ``JoinableRequest/annotated(withRequired:)``
/// - ``annotated(with:)-74xfs``
/// - ``annotated(with:)-8snn4``
/// - ``having(_:)``
/// - ``JoinableRequest/including(all:)``
/// - ``JoinableRequest/including(optional:)``
/// - ``JoinableRequest/including(required:)``
/// - ``JoinableRequest/joining(optional:)``
/// - ``JoinableRequest/joining(required:)``
///
/// ### Supporting Types
///
/// - ``AggregatingRequest``
/// - ``FilteredRequest``
/// - ``JoinableRequest``
/// - ``OrderedRequest``
/// - ``SelectionRequest``
/// - ``TableRequest``
/// - ``TypedRequest``
public protocol DerivableRequest<RowDecoder>: AggregatingRequest, FilteredRequest,
                                              JoinableRequest, OrderedRequest,
                                              SelectionRequest, TableRequest
{
    /// Returns a request which returns distinct rows.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT DISTINCT * FROM player
    /// let request = Player.all().distinct()
    ///
    /// // SELECT DISTINCT name FROM player
    /// let request = Player.select(Column("name")).distinct()
    /// ```
    func distinct() -> Self
    
    /// Embeds a common table expression.
    ///
    /// If a common table expression with the same table name had already been
    /// embedded, it is replaced by the new one.
    ///
    /// For example, you can build a request that fetches all chats with their
    /// latest message:
    ///
    /// ```swift
    /// let latestMessageRequest = Message
    ///     .annotated(with: max(Column("date")))
    ///     .group(Column("chatID"))
    ///
    /// let latestMessageCTE = CommonTableExpression(
    ///     named: "latestMessage",
    ///     request: latestMessageRequest)
    ///
    /// let latestMessageAssociation = Chat.association(
    ///     to: latestMessageCTE,
    ///     on: { chat, latestMessage in
    ///         chat[Column("id")] == latestMessage[Column("chatID")]
    ///     })
    ///
    /// // WITH latestMessage AS
    /// //   (SELECT *, MAX(date) FROM message GROUP BY chatID)
    /// // SELECT chat.*, latestMessage.*
    /// // FROM chat
    /// // LEFT JOIN latestMessage ON chat.id = latestMessage.chatID
    /// let request = Chat.all()
    ///     .with(latestMessageCTE)
    ///     .including(optional: latestMessageAssociation)
    /// ```
    func with<RowDecoder>(_ cte: CommonTableExpression<RowDecoder>) -> Self
}

// Association aggregates don't require all DerivableRequest abilities. The
// minimum set of requirements is:
//
// - AggregatingRequest, for the GROUP BY and HAVING clauses
// - TableRequest, for grouping by primary key
// - JoinableRequest, for joining associations
// - SelectionRequest, for annotating the selection
//
// It is just that extending DerivableRequest is simpler. We want the user to
// use aggregates on QueryInterfaceRequest and associations: both conform to
// DerivableRequest already.
extension DerivableRequest {
    private func annotated(with aggregate: AssociationAggregate<RowDecoder>) -> Self {
        var request = self
        let expression = aggregate.prepare(&request)
        if let key = aggregate.key {
            return request.annotated(with: expression.forKey(key))
        } else {
            return request.annotated(with: expression)
        }
    }
    
    /// Appends association aggregates to the selected columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable {
    ///     static let books = hasMany(Book.self)
    /// }
    /// struct Book: TableRecord, FetchableRecord, Decodable { }
    ///
    /// struct AuthorInfo: FetchableRecord, Decodable {
    ///     var author: Author
    ///     var bookCount: Int
    /// }
    ///
    /// // SELECT author.*, COUNT(DISTINCT book.id) AS bookCount
    /// // FROM author
    /// // LEFT JOIN book ON book.authorId = author.id
    /// // GROUP BY author.id
    /// let authorInfos = try Author.all()
    ///     .annotated(with: Author.books.count)
    ///     .asRequest(of: AuthorInfo.self)
    ///     .fetchAll(db)
    /// ```
    public func annotated(with aggregates: AssociationAggregate<RowDecoder>...) -> Self {
        annotated(with: aggregates)
    }
    
    /// Appends association aggregates to the selected columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable {
    ///     static let books = hasMany(Book.self)
    /// }
    /// struct Book: TableRecord, FetchableRecord, Decodable { }
    ///
    /// struct AuthorInfo: FetchableRecord, Decodable {
    ///     var author: Author
    ///     var bookCount: Int
    /// }
    ///
    /// // SELECT author.*, COUNT(DISTINCT book.id) AS bookCount
    /// // FROM author
    /// // LEFT JOIN book ON book.authorId = author.id
    /// // GROUP BY author.id
    /// let authorInfos = try Author.all()
    ///     .annotated(with: [Author.books.count])
    ///     .asRequest(of: AuthorInfo.self)
    ///     .fetchAll(db)
    /// ```
    public func annotated(with aggregates: [AssociationAggregate<RowDecoder>]) -> Self {
        aggregates.reduce(self) { request, aggregate in
            request.annotated(with: aggregate)
        }
    }
    
    /// Filters the fetched records with an association aggregate.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord {
    ///     static let books = hasMany(Book.self)
    /// }
    /// struct Book: TableRecord, FetchableRecord { }
    ///
    /// // SELECT author.*
    /// // FROM author
    /// // LEFT JOIN book ON book.authorId = author.id
    /// // GROUP BY author.id
    /// // HAVING COUNT(DISTINCT book.id) > 5
    /// let authors = try Author.all()
    ///     .having(Author.books.count > 5)
    ///     .fetchAll(db)
    /// ```
    public func having(_ predicate: AssociationAggregate<RowDecoder>) -> Self {
        var request = self
        let expression = predicate.prepare(&request)
        return request.having(expression)
    }
}
