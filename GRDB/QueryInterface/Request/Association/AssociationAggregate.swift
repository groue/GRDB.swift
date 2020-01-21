import Foundation

typealias AssociationAggregatePreparation<RowDecoder> =
    (QueryInterfaceRequest<RowDecoder>)
    -> (request: QueryInterfaceRequest<RowDecoder>, expression: SQLExpression)

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
    ///     //  COUNT(DISTINCT book.rowid)
    ///     tuple.expression
    ///
    /// The aggregated value is not right away embedded in the extended request:
    ///
    /// - We don't know yet if the aggregated value will be used in the
    ///   SQL selection, or in the HAVING clause.
    /// - It helps implementing aggregate operators such as `&&`, `+`, etc.
    let prepare: AssociationAggregatePreparation<RowDecoder>
    
    /// The SQL name for the value of this aggregate. See forKey(_:).
    var key: String?
    
    init(_ prepare: @escaping AssociationAggregatePreparation<RowDecoder>) {
        self.prepare = prepare
    }
}

extension AssociationAggregate: KeyPathRefining {
    /// Returns an aggregate that is selected in a column with the given name.
    ///
    /// For example:
    ///
    ///     let aggregate = Author.books.count.aliased("numberOfBooks")
    ///     let request = Author.annotated(with: aggregate)
    ///     if let row = try Row.fetchOne(db, request) {
    ///         let numberOfBooks: Int = row["numberOfBooks"]
    ///     }
    @available(*, deprecated, renamed: "forKey(_:)")
    public func aliased(_ name: String) -> AssociationAggregate<RowDecoder> {
        return forKey(name)
    }
    
    /// Returns an aggregate that is selected in a column with the given name.
    ///
    /// For example:
    ///
    ///     let aggregate = Author.books.count.forKey("numberOfBooks")
    ///     let request = Author.annotated(with: aggregate)
    ///     if let row = try Row.fetchOne(db, request) {
    ///         let numberOfBooks: Int = row["numberOfBooks"]
    ///     }
    public func forKey(_ key: String) -> AssociationAggregate<RowDecoder> {
        return with(\.key, key)
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
    ///             let aggregate = Author.books.count.aliased(CodingKeys.numberOfBooks)
    ///             let request = Author.annotated(with: aggregate)
    ///             return try AuthorInfo.fetchAll(db, request)
    ///         }
    ///     }
    @available(*, deprecated, renamed: "forKey(_:)")
    public func aliased(_ key: CodingKey) -> AssociationAggregate<RowDecoder> {
        return forKey(key)
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
    public func forKey(_ key: CodingKey) -> AssociationAggregate<RowDecoder> {
        return forKey(key.stringValue)
    }
}

// MARK: - Logical Operators (AND, OR, NOT)

/// Returns a logically negated aggregate.
///
/// For example:
///
///     Author.having(!Author.books.isEmpty)
public prefix func ! <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = aggregate.prepare(request)
        return (request: request, expression: !expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression && rExpression)
    }
}

// TODO: test
/// :nodoc:
public func && <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression && rhs)
    }
}

// TODO: test
/// :nodoc:
public func && <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs && expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression || rExpression)
    }
}

// TODO: test
/// :nodoc:
public func || <RowDecoder>(
    lhs: AssociationAggregate<RowDecoder>,
    rhs: SQLExpressible)
    -> AssociationAggregate<RowDecoder>
{
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression || rhs)
    }
}

// TODO: test
/// :nodoc:
public func || <RowDecoder>(
    lhs: SQLExpressible,
    rhs: AssociationAggregate<RowDecoder>)
    -> AssociationAggregate<RowDecoder>
{
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs || expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression == rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression == rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs == expression)
    }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(Author.books.isEmpty == false)
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression == rhs)
    }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(false == Author.books.isEmpty)
public func == <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs == expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression != rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression != rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs != expression)
    }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(Author.books.isEmpty != true)
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression != rhs)
    }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     Author.having(true != Author.books.isEmpty)
public func != <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs != expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression === rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression === rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs === expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression !== rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression !== rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs !== expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression <= rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression <= rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs <= expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression < rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression < rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs < expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression > rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression > rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs > expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression >= rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression >= rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs >= expression)
    }
}

// MARK: - Arithmetic Operators (+, -, *, /)

/// Returns an arithmetically negated aggregate.
///
/// For example:
///
///     Author.annotated(with: -Author.books.count)
public prefix func - <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = aggregate.prepare(request)
        return (request: request, expression:-expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression + rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression + rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs + expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression - rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression - rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs - expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression * rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression * rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs * expression)
    }
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
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression / rExpression)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression / rhs)
    }
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
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs / expression)
    }
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
    var aggregate = AssociationAggregate<RowDecoder> { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression ?? rhs)
    }
    
    // Preserve key
    aggregate.key = lhs.key
    return aggregate
}

// TODO: add support for ABS(aggregate)
// TODO: add support for LENGTH(aggregate)
