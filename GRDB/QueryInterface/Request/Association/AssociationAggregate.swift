import Foundation

typealias AssociationAggregatePreparation<RowDecoder> =
    (QueryInterfaceRequest<RowDecoder>)
    -> (request: QueryInterfaceRequest<RowDecoder>, expressionPromise: DatabasePromise<SQLExpression>)

extension AssociationToMany {
    private func makeAggregate(_ expressionPromise: DatabasePromise<SQLExpression>) -> AssociationAggregate<OriginRowDecoder> {
        AssociationAggregate { request in
            let tableAlias = TableAlias()
            let request = request
                .joining(optional: self.aliased(tableAlias))
                .groupByPrimaryKey()
            let expressionPromise = expressionPromise.map { tableAlias[$0] }
            return (request: request, expressionPromise: expressionPromise)
        }
    }
    
    // Convenience
    private func makeAggregate(_ expression: SQLExpression) -> AssociationAggregate<OriginRowDecoder> {
        makeAggregate(DatabasePromise(value: expression))
    }
    
    /// The number of associated records.
    ///
    /// It has a default name, which is "[key]Count", where key is the key of
    /// the association. For example:
    ///
    /// For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var playerCount: Int
    ///     }
    ///     let request = Team.annotated(with: Team.players.count())
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.count() > 10).fetchAll(db)
    public var count: AssociationAggregate<OriginRowDecoder> {
        let expression = DatabasePromise<SQLExpression> { db in
            let primaryKey = try db.primaryKeyExpression(self.databaseTableName)
            return SQLExpressionCountDistinct(primaryKey)
        }
        return makeAggregate(expression).forKey("\(key.singularizedName)Count")
    }
    
    /// Creates an aggregate that is true if there exists no associated records.
    ///
    /// It has a default name, which is "hasNo[Key]", where key is the key of
    /// the association. For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var hasNoPlayer: Bool
    ///     }
    ///     let request = Team.annotated(with: Team.players.isEmpty())
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.isEmpty()).fetchAll(db)
    ///     let teams: [Team] = try Team.having(!Team.players.isEmpty())
    ///     let teams: [Team] = try Team.having(Team.players.isEmpty() == false)
    public var isEmpty: AssociationAggregate<OriginRowDecoder> {
        let expression = DatabasePromise<SQLExpression> { db in
            let primaryKey = try db.primaryKeyExpression(self.databaseTableName)
            return SQLExpressionIsEmpty(SQLExpressionCountDistinct(primaryKey))
        }
        return makeAggregate(expression).forKey("hasNo\(key.singularizedName.uppercasingFirstCharacter)")
    }
    
    /// Creates an aggregate which evaluate to the average value of the given
    /// expression in associated records.
    ///
    /// When the averaged expression is a column, the aggregate has a default
    /// name which is "average[Key][Column]", where key is the key of the
    /// association. For example:
    ///
    /// For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var averagePlayerScore: Double
    ///     }
    ///     let request = Team.annotated(with: Team.players.average(Column("score")))
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.average(Column("score")) > 100).fetchAll(db)
    public func average(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.avg, arguments: expression))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("average\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// Creates an aggregate which evaluate to the maximum value of the given
    /// expression in associated records.
    ///
    /// When the maximized expression is a column, the aggregate has a default
    /// name which is "maximum[Key][Column]", where key is the key of the
    /// association. For example:
    ///
    /// For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var maxPlayerScore: Double
    ///     }
    ///     let request = Team.annotated(with: Team.players.max(Column("score")))
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.max(Column("score")) < 100).fetchAll(db)
    public func max(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.max, arguments: expression))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("max\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// Creates an aggregate which evaluate to the minimum value of the given
    /// expression in associated records.
    ///
    /// When the minimized expression is a column, the aggregate has a default
    /// name which is "minimum[Key][Column]", where key is the key of the
    /// association. For example:
    ///
    /// For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var minPlayerScore: Double
    ///     }
    ///     let request = Team.annotated(with: Team.players.min(Column("score")))
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.min(Column("score")) > 100).fetchAll(db)
    public func min(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.min, arguments: expression))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("min\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// Creates an aggregate which evaluate to the sum of the given expression
    /// in associated records.
    ///
    /// When the summed expression is a column, the aggregate has a default
    /// name which is "[key][Column]Sum", where key is the key of the
    /// association. For example:
    ///
    /// For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var playerScoreSum: Double
    ///     }
    ///     let request = Team.annotated(with: Team.players.sum(Column("score")))
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.sum(Column("score")) > 100).fetchAll(db)
    public func sum(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.sum, arguments: expression))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("\(name)\(column.name.uppercasingFirstCharacter)Sum")
        } else {
            return aggregate
        }
    }
}

/// An AssociationAggregate is able to compute aggregated values from a
/// population of associated records.
///
/// For example:
///
///     struct Author: TableRecord {
///         static let books = hasMany(Book.self)
///     }
///
///     let bookCount = Author.books.count // AssociationAggregate<Author>
///
/// Association aggregates can be used in the `annotated(with:)` and
/// `having(_:)` request methods:
///
///     let request = Author.annotated(with: bookCount)
///     let request = Author.having(bookCount >= 10)
///
/// The RowDecoder generic type helps the compiler prevent incorrect use
/// of aggregates:
///
///     // Won't compile because Fruit is not Author.
///     let request = Fruit.annotated(with: bookCount)
public struct AssociationAggregate<RowDecoder> {
    /// Given a request, returns a tuple made of a request extended with the
    /// associated records used to compute the aggregate, and an expression
    /// whose value is the aggregated value.
    ///
    /// For example:
    ///
    ///     struct Author: TableRecord {
    ///         static let books = hasMany(Book.self)
    ///     }
    ///
    ///     // SELECT * FROM author
    ///     let request = Author.all()
    ///
    ///     let aggregate = Author.books.count
    ///     let tuple = aggregate.prepare(request)
    ///
    ///     // The request extended with associated records:
    ///     //
    ///     //  SELECT author.* FROM author
    ///     //  LEFT JOIN book ON book.authorId = author.id
    ///     //  GROUP BY author.id
    ///     tuple.request
    ///
    ///     // The aggregated value:
    ///     //
    ///     //  COUNT(DISTINCT book.id)
    ///     tuple.expression
    ///
    /// The aggregated value is not right away embedded in the extended request:
    ///
    /// - We don't know yet if the aggregated value will be used in the
    ///   SQL selection, or in the HAVING clause.
    /// - It helps implementing aggregate operators such as `&&`, `+`, etc.
    let prepare: AssociationAggregatePreparation<RowDecoder>
    
    /// The SQL name for the value of this aggregate. See forKey(_:).
    var key: String? = nil
}

extension AssociationAggregate: Refinable {
    /// Returns an aggregate that is selected in a column with the given name.
    ///
    /// For example:
    ///
    ///     let aggregate = Author.books.count.forKey("numberOfBooks")
    ///     let request = Author.annotated(with: aggregate)
    ///     if let row = try Row.fetchOne(db, request) {
    ///         let numberOfBooks: Int = row["numberOfBooks"]
    ///     }
    public func forKey(_ key: String) -> Self {
        with(\.key, key)
    }
    
    /// Returns an aggregate that is selected in a column named like the given
    /// coding key.
    ///
    /// For example:
    ///
    ///     struct AuthorInfo: Decodable, FetchableRecord {
    ///         var author: Author
    ///         var numberOfBooks: Int
    ///
    ///         static func fetchAll(_ db: Database) throws -> [AuthorInfo] {
    ///             let aggregate = Author.books.count.forKey(CodingKeys.numberOfBooks)
    ///             let request = Author.annotated(with: aggregate)
    ///             return try AuthorInfo.fetchAll(db, request)
    ///         }
    ///     }
    public func forKey(_ key: CodingKey) -> Self {
        forKey(key.stringValue)
    }
    
    /// Transforms the expression, and does not preserve key.
    func mapExpression(_ transform: @escaping (SQLExpression) throws -> SQLExpression) -> Self {
        AssociationAggregate { request in
            let (request, expressionPromise) = self.prepare(request)
            return (request: request, expressionPromise: expressionPromise.map(transform))
        }
    }
    
    func combined(
        with other: Self,
        _ combineExpressions : @escaping (_ lhs: SQLExpression, _ rhs: SQLExpression) throws -> SQLExpression)
        -> Self
    {
        AssociationAggregate { request in
            let (lRequest, lExpression) = self.prepare(request)
            let (request, rExpression) = other.prepare(lRequest)
            let expressionPromise = DatabasePromise<SQLExpression> { db in
                try combineExpressions(lExpression.resolve(db), rExpression.resolve(db))
            }
            return (request: request, expressionPromise: expressionPromise)
        }
    }
}

// MARK: - Logical Operators (AND, OR, NOT)

/// Returns a logically negated aggregate.
///
/// For example:
///
///     Author.having(!Author.books.isEmpty)
public prefix func ! <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    aggregate.mapExpression { !$0 }
}

/// Groups two aggregates with the `AND` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.isEmpty && Author.paintings.isEmpty)
public func && <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, &&)
}

// TODO: test
/// :nodoc:
public func && <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 && rhs }
}

// TODO: test
/// :nodoc:
public func && <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs && $0 }
}


/// Groups two aggregates with the `OR` SQL operator.
///
/// For example:
///
///     Author.having(!Author.books.isEmpty || !Author.paintings.isEmpty)
public func || <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, ||)
}

// TODO: test
/// :nodoc:
public func || <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 || rhs }
}

// TODO: test
/// :nodoc:
public func || <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs || $0 }
}

// MARK: - Egality and Identity Operators (=, <>, IS, IS NOT)

/// Returns an aggregate that compares two aggregates with the `=` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count == Author.paintings.count)
public func == <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, ==)
}

/// Returns an aggregate that compares an aggregate with the `=` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count == 3)
public func == <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 == rhs }
}

/// Returns an aggregate that compares an aggregate with the `=` SQL operator.
///
/// For example:
///
///    Author.having(3 == Author.books.count)
public func == <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs == $0 }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(Author.books.isEmpty == false)
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    lhs.mapExpression { $0 == rhs }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(false == Author.books.isEmpty)
public func == <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    rhs.mapExpression { lhs == $0 }
}

/// Returns an aggregate that compares two aggregates with the `<>` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count != Author.paintings.count)
public func != <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, !=)
}

/// Returns an aggregate that compares an aggregate with the `<>` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count != 3)
public func != <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 != rhs }
}

/// Returns an aggregate that compares an aggregate with the `<>` SQL operator.
///
/// For example:
///
///     Author.having(3 != Author.books.count)
public func != <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs != $0 }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(Author.books.isEmpty != true)
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    lhs.mapExpression { $0 != rhs }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(true != Author.books.isEmpty)
public func != <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    rhs.mapExpression { lhs != $0 }
}

/// Returns an aggregate that compares two aggregates with the `IS` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count === Author.paintings.count)
public func === <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, ===)
}

/// Returns an aggregate that compares an aggregate with the `IS` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count === 3)
public func === <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 === rhs }
}

/// Returns an aggregate that compares an aggregate with the `IS` SQL operator.
///
/// For example:
///
///     Author.having(3 === Author.books.count)
public func === <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs === $0 }
}

/// Returns an aggregate that compares two aggregates with the `IS NOT` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count !== Author.paintings.count)
public func !== <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, !==)
}

/// Returns an aggregate that compares an aggregate with the `IS NOT` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count !== 3)
public func !== <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 !== rhs }
}

/// Returns an aggregate that compares an aggregate with the `IS NOT` SQL operator.
///
/// For example:
///
///     Author.having(3 !== Author.books.count)
public func !== <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs !== $0 }
}

// MARK: - Comparison Operators (<, >, <=, >=)

/// Returns an aggregate that compares two aggregates with the `<=` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count <= Author.paintings.count)
public func <= <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, <=)
}

/// Returns an aggregate that compares an aggregate with the `<=` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count <= 3)
public func <= <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 <= rhs }
}

/// Returns an aggregate that compares an aggregate with the `<=` SQL operator.
///
/// For example:
///
///     Author.having(3 <= Author.books.count)
public func <= <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs <= $0 }
}

/// Returns an aggregate that compares two aggregates with the `<` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count < Author.paintings.count)
public func < <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, <)
}

/// Returns an aggregate that compares an aggregate with the `<` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count < 3)
public func < <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 < rhs }
}

/// Returns an aggregate that compares an aggregate with the `<` SQL operator.
///
/// For example:
///
///     Author.having(3 < Author.books.count)
public func < <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs < $0 }
}

/// Returns an aggregate that compares two aggregates with the `>` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count > Author.paintings.count)
public func > <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, >)
}

/// Returns an aggregate that compares an aggregate with the `>` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count > 3)
public func > <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 > rhs }
}

/// Returns an aggregate that compares an aggregate with the `>` SQL operator.
///
/// For example:
///
///     Author.having(3 > Author.books.count)
public func > <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs > $0 }
}

/// Returns an aggregate that compares two aggregates with the `>=` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count >= Author.paintings.count)
public func >= <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, >=)
}

/// Returns an aggregate that compares an aggregate with the `>=` SQL operator.
///
/// For example:
///
///     Author.having(Author.books.count >= 3)
public func >= <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 >= rhs }
}

/// Returns an aggregate that compares an aggregate with the `>=` SQL operator.
///
/// For example:
///
///     Author.having(3 >= Author.books.count)
public func >= <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs >= $0 }
}

// MARK: - Arithmetic Operators (+, -, *, /)

/// Returns an arithmetically negated aggregate.
///
/// For example:
///
///     Author.annotated(with: -Author.books.count)
public prefix func - <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    aggregate.mapExpression { -$0 }
}

/// Returns an aggregate that sums two aggregates with the `+` SQL operator.
///
/// For example:
///
///     Author.annotated(with: Author.books.count + Author.paintings.count)
public func + <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, +)
}

/// Returns an aggregate that sums an aggregate with the `+` SQL operator.
///
/// For example:
///
///     Author.annotated(with: Author.books.count + 1)
public func + <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 + rhs }
}

/// Returns an aggregate that sums an aggregate with the `+` SQL operator.
///
/// For example:
///
///     Author.annotated(with: 1 + Author.books.count)
public func + <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs + $0 }
}

/// Returns an aggregate that substracts two aggregates with the `-` SQL operator.
///
/// For example:
///
///     Author.annotated(with: Author.books.count - Author.paintings.count)
public func - <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, -)
}

/// Returns an aggregate that substracts an aggregate with the `-` SQL operator.
///
/// For example:
///
///     Author.annotated(with: Author.books.count - 1)
public func - <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 - rhs }
}

/// Returns an aggregate that substracts an aggregate with the `-` SQL operator.
///
/// For example:
///
///     Author.annotated(with: 1 - Author.books.count)
public func - <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs - $0 }
}

/// Returns an aggregate that multiplies two aggregates with the `*` SQL operator.
///
/// For example:
///
///     Author.annotated(with: Author.books.count * Author.paintings.count)
public func * <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, *)
}

/// Returns an aggregate that substracts an aggregate with the `*` SQL operator.
///
/// For example:
///
///     Author.annotated(with: Author.books.count * 2)
public func * <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 * rhs }
}

/// Returns an aggregate that substracts an aggregate with the `*` SQL operator.
///
/// For example:
///
///     Author.annotated(with: 2 * Author.books.count)
public func * <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs * $0 }
}

/// Returns an aggregate that multiplies two aggregates with the `/` SQL operator.
///
/// For example:
///
///     Author.annotated(with: Author.books.count / Author.paintings.count)
public func / <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    lhs.combined(with: rhs, /)
}

/// Returns an aggregate that substracts an aggregate with the `/` SQL operator.
///
/// For example:
///
///     Author.annotated(with: Author.books.count / 2)
public func / <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    lhs.mapExpression { $0 / rhs }
}

/// Returns an aggregate that substracts an aggregate with the `/` SQL operator.
///
/// For example:
///
///     Author.annotated(with: 2 / Author.books.count)
public func / <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    rhs.mapExpression { lhs / $0 }
}

// MARK: - IFNULL(...)

/// Returns an aggregate that evaluates the `IFNULL` SQL function.
///
///     Team.annotated(with: Team.players.min(Column("score")) ?? 0)
public func ?? <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    // Preserve key
    lhs.mapExpression { $0 ?? rhs }.with(\.key, lhs.key)
}

// TODO: add support for ABS(aggregate)
// TODO: add support for LENGTH(aggregate)
