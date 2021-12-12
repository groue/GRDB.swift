import Foundation

extension AssociationToMany {
    private func makeAggregate(_ expression: SQLExpression) -> AssociationAggregate<OriginRowDecoder> {
        AssociationAggregate(preparation: BasePreparation(association: self, expression: expression))
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
        makeAggregate(.countDistinct(.fastPrimaryKey))
            .forKey("\(key.singularizedName)Count")
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
        makeAggregate(.isEmpty(.countDistinct(.fastPrimaryKey)))
            .forKey("hasNo\(key.singularizedName.uppercasingFirstCharacter)")
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
    @available(*, deprecated, message: "Did you mean average(Column(...))? If not, prefer average(value.databaseValue) instead.") // swiftlint:disable:this line_length
    public func average(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.aggregate("AVG", [expression.sqlExpression]))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("average\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
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
    public func average(_ expression: SQLSpecificExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.aggregate("AVG", [expression.sqlExpression]))
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
    @available(*, deprecated, message: "Did you mean max(Column(...))? If not, prefer max(value.databaseValue) instead.") // swiftlint:disable:this line_length
    public func max(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.aggregate("MAX", [expression.sqlExpression]))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("max\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
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
    public func max(_ expression: SQLSpecificExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.aggregate("MAX", [expression.sqlExpression]))
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
    @available(*, deprecated, message: "Did you mean min(Column(...))? If not, prefer min(value.databaseValue) instead.") // swiftlint:disable:this line_length
    public func min(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.aggregate("MIN", [expression.sqlExpression]))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("min\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
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
    public func min(_ expression: SQLSpecificExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.aggregate("MIN", [expression.sqlExpression]))
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
    ///
    /// This aggregate invokes the `SUM` SQL function. See also `total(_:)`, and
    /// <https://www.sqlite.org/lang_aggfunc.html#sumunc>.
    @available(*, deprecated, message: "Did you mean sum(Column(...))? If not, prefer sum(value.databaseValue) instead.") // swiftlint:disable:this line_length
    public func sum(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.aggregate("SUM", [expression.sqlExpression]))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("\(name)\(column.name.uppercasingFirstCharacter)Sum")
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
    ///
    /// This aggregate invokes the `SUM` SQL function. See also `total(_:)`, and
    /// <https://www.sqlite.org/lang_aggfunc.html#sumunc>.
    public func sum(_ expression: SQLSpecificExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.aggregate("SUM", [expression.sqlExpression]))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("\(name)\(column.name.uppercasingFirstCharacter)Sum")
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
    ///     let request = Team.annotated(with: Team.players.total(Column("score")))
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.total(Column("score")) > 100).fetchAll(db)
    ///
    /// This aggregate invokes the `TOTAL` SQL function. See also `sum(_:)`, and
    /// <https://www.sqlite.org/lang_aggfunc.html#sumunc>.
    public func total(_ expression: SQLSpecificExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.aggregate("TOTAL", [expression.sqlExpression]))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            // Yes we use the `Sum` suffix instead of `Total`. Both `total(_:)`
            // and `sum(_:)` compute sums.
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
    fileprivate let preparation: AssociationAggregatePreparation<RowDecoder>
    
    /// The SQL name for the value of this aggregate. See forKey(_:).
    var key: String? = nil
    
    /// Extends the request with the associated records used to compute the
    /// aggregate, and returns the aggregated expression.
    ///
    /// For example:
    ///
    ///     struct Author: TableRecord {
    ///         static let books = hasMany(Book.self)
    ///     }
    ///
    ///     // SELECT * FROM author
    ///     var request = Author.all()
    ///
    ///     let aggregate = Author.books.count
    ///     let expression = aggregate.prepare(&request)
    ///
    ///     // The request has been extended with associated records:
    ///     //
    ///     //  SELECT author.* FROM author
    ///     //  LEFT JOIN book ON book.authorId = author.id
    ///     //  GROUP BY author.id
    ///     request
    ///
    ///     // The aggregated value:
    ///     //
    ///     //  COUNT(DISTINCT book.id)
    ///     expression
    ///
    /// The aggregated expression is not embedded in the extended request:
    ///
    /// - We don't know yet if the aggregated expression will be used in the
    ///   SQL selection, or in the HAVING clause.
    /// - It helps implementing aggregate operators such as `&&`, `+`, etc.
    func prepare<Request>(_ request: inout Request) -> SQLExpression
    where Request: DerivableRequest, Request.RowDecoder == RowDecoder
    {
        preparation.prepare(&request)
    }
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
        with {
            $0.key = key
        }
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
}

// MARK: - AssociationAggregatePreparation

/// An abstract class that only exists as support for
/// `AssociationAggregate.prepare(_:)`, which needs to prepare both query
/// interface requests and associations through their conformance
/// to `DerivableRequest`:
///
///     aggregate.prepare(&request)
///     aggregate.prepare(&association)
///
/// We could have used a generic closure instead of this class... if only Swift
/// would support generic closures.
private class AssociationAggregatePreparation<RowDecoder> {
    func prepare<Request>(_ request: inout Request) -> SQLExpression
    where Request: DerivableRequest, Request.RowDecoder == RowDecoder
    {
        fatalError("subclass must override")
    }
}

/// Prepares a request so that it can use association aggregates.
private class BasePreparation<Association: AssociationToMany>:
    AssociationAggregatePreparation<Association.OriginRowDecoder>  // swiftlint:disable:previous colon
{
    private let association: Association
    private let expression: SQLExpression
    
    init(association: Association, expression: SQLExpression) {
        self.association = association
        self.expression = expression
    }
    
    override func prepare<Request>(_ request: inout Request) -> SQLExpression
    where Request: DerivableRequest, Request.RowDecoder == Association.OriginRowDecoder
    {
        // The fundamental request that supports association aggregate:
        //
        //     SELECT parent.*
        //     LEFT JOIN child ON child.parentID = parent.id
        //     GROUP BY parent.id
        let tableAlias = TableAlias()
        request = request
            .joining(optional: association.aliased(tableAlias))
            .groupByPrimaryKey()
        
        // The fundamental request can now be annotated, or filtered in the
        // having clause, with the association aggregate expression:
        // MIN(child.score), COUNT(DISTINCT child.id), etc.
        return expression.qualified(with: tableAlias)
    }
}

/// Transforms the expression of an aggregate.
private class MapPreparation<RowDecoder>: AssociationAggregatePreparation<RowDecoder> {
    private let base: AssociationAggregatePreparation<RowDecoder>
    private let transform: (SQLExpression) -> SQLExpression
    
    init(
        base: AssociationAggregatePreparation<RowDecoder>,
        transform: @escaping (SQLExpression) -> SQLExpression)
    {
        self.base = base
        self.transform = transform
    }
    
    override func prepare<Request>(_ request: inout Request) -> SQLExpression
    where Request: DerivableRequest, Request.RowDecoder == RowDecoder
    {
        transform(base.prepare(&request))
    }
}

extension AssociationAggregate {
    /// Transforms the expression, and does not preserve key.
    fileprivate func map(_ transform: @escaping (SQLExpression) -> SQLExpression) -> Self {
        AssociationAggregate(preparation: MapPreparation(base: preparation, transform: transform))
    }
}

/// Combines the expressions of two aggregates.
private class CombinePreparation<RowDecoder>: AssociationAggregatePreparation<RowDecoder> {
    private let lhs: AssociationAggregatePreparation<RowDecoder>
    private let rhs: AssociationAggregatePreparation<RowDecoder>
    private let combine: (_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLExpression
    
    init(
        _ lhs: AssociationAggregatePreparation<RowDecoder>,
        _ rhs: AssociationAggregatePreparation<RowDecoder>,
        combine: @escaping (_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLExpression)
    {
        self.lhs = lhs
        self.rhs = rhs
        self.combine = combine
    }
    
    override func prepare<Request>(_ request: inout Request) -> SQLExpression
    where Request: DerivableRequest, Request.RowDecoder == RowDecoder
    {
        let lhsExpression = lhs.prepare(&request)
        let rhsExpression = rhs.prepare(&request)
        return combine(lhsExpression, rhsExpression)
    }
}

/// Combines the expression of two aggregates.
private func combine<RowDecoder>(
    _ lhs: AssociationAggregate<RowDecoder>,
    _ rhs: AssociationAggregate<RowDecoder>,
    with combine: @escaping (_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLExpression)
-> AssociationAggregate<RowDecoder>
{
    AssociationAggregate(preparation: CombinePreparation(lhs.preparation, rhs.preparation, combine: combine))
}

// MARK: - Logical Operators (AND, OR, NOT)

/// Returns a logically negated aggregate.
///
/// For example:
///
///     Author.having(!Author.books.isEmpty)
public prefix func ! <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    aggregate.map { !$0 }
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
    combine(lhs, rhs, with: &&)
}

// TODO: test
/// :nodoc:
public func && <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
-> AssociationAggregate<RowDecoder>
{
    lhs.map { $0 && rhs }
}

// TODO: test
/// :nodoc:
public func && <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
-> AssociationAggregate<RowDecoder>
{
    rhs.map { lhs && $0 }
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
    combine(lhs, rhs, with: ||)
}

// TODO: test
/// :nodoc:
public func || <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
-> AssociationAggregate<RowDecoder>
{
    lhs.map { $0 || rhs }
}

// TODO: test
/// :nodoc:
public func || <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
-> AssociationAggregate<RowDecoder>
{
    rhs.map { lhs || $0 }
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
    combine(lhs, rhs, with: ==)
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
    lhs.map { $0 == rhs }
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
    rhs.map { lhs == $0 }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(Author.books.isEmpty == false)
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    lhs.map { $0 == rhs }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(false == Author.books.isEmpty)
public func == <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    rhs.map { lhs == $0 }
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
    combine(lhs, rhs, with: !=)
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
    lhs.map { $0 != rhs }
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
    rhs.map { lhs != $0 }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(Author.books.isEmpty != true)
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    lhs.map { $0 != rhs }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(true != Author.books.isEmpty)
public func != <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    rhs.map { lhs != $0 }
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
    combine(lhs, rhs, with: ===)
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
    lhs.map { $0 === rhs }
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
    rhs.map { lhs === $0 }
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
    combine(lhs, rhs, with: !==)
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
    lhs.map { $0 !== rhs }
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
    rhs.map { lhs !== $0 }
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
    combine(lhs, rhs, with: <=)
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
    lhs.map { $0 <= rhs }
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
    rhs.map { lhs <= $0 }
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
    combine(lhs, rhs, with: <)
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
    lhs.map { $0 < rhs }
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
    rhs.map { lhs < $0 }
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
    combine(lhs, rhs, with: >)
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
    lhs.map { $0 > rhs }
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
    rhs.map { lhs > $0 }
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
    combine(lhs, rhs, with: >=)
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
    lhs.map { $0 >= rhs }
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
    rhs.map { lhs >= $0 }
}

// MARK: - Arithmetic Operators (+, -, *, /)

/// Returns an arithmetically negated aggregate.
///
/// For example:
///
///     Author.annotated(with: -Author.books.count)
public prefix func - <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    aggregate.map { -$0 }
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
    combine(lhs, rhs, with: +)
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
    lhs.map { $0 + rhs }
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
    rhs.map { lhs + $0 }
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
    combine(lhs, rhs, with: -)
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
    lhs.map { $0 - rhs }
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
    rhs.map { lhs - $0 }
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
    combine(lhs, rhs, with: *)
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
    lhs.map { $0 * rhs }
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
    rhs.map { lhs * $0 }
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
    combine(lhs, rhs, with: /)
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
    lhs.map { $0 / rhs }
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
    rhs.map { lhs / $0 }
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
    lhs
        .map { $0 ?? rhs }
        .with { $0.key = lhs.key } // Preserve key
}

// MARK: - ABS(...)

/// Returns an aggregate that evaluates to the absolute value of the
/// input aggregate.
public func abs<RowDecoder>(_ aggregate: AssociationAggregate<RowDecoder>)
-> AssociationAggregate<RowDecoder>
{
    aggregate.map(abs)
}

// MARK: - LENGTH(...)

/// Returns an aggregate that evaluates the `LENGTH` SQL function on the
/// input aggregate.
public func length<RowDecoder>(_ aggregate: AssociationAggregate<RowDecoder>)
-> AssociationAggregate<RowDecoder>
{
    aggregate.map(length)
}
