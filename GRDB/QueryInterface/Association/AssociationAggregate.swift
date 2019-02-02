import Foundation

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
    let prepare: (QueryInterfaceRequest<RowDecoder>) -> (request: QueryInterfaceRequest<RowDecoder>, expression: SQLExpression)
    
    /// The SQL alias for the value of this aggregate. See aliased(_:).
    var alias: String?
    
    init(_ prepare: @escaping (QueryInterfaceRequest<RowDecoder>) -> (request: QueryInterfaceRequest<RowDecoder>, expression: SQLExpression)) {
        self.prepare = prepare
    }
}

extension AssociationAggregate {
    /// Returns an aggregate that is selected in a column with the given name.
    ///
    /// For example:
    ///
    ///     let aggregate = Author.books.count.aliased("foo")
    ///     let request = Author.annotated(with: aggregate)
    ///     if let row = try Row.fetchOne(db, request) {
    ///         let bookCount: Int = row["foo"]
    ///     }
    public func aliased(_ name: String) -> AssociationAggregate<RowDecoder> {
        var aggregate = self
        aggregate.alias = name
        return aggregate
    }
    
    /// Returns an aggregate that is selected in a column named like the given
    /// coding key.
    ///
    /// For example:
    ///
    ///     struct AuthorInfo: Decodable, FetchableRecord {
    ///         var author: Author
    ///         var bookCount: Int
    ///
    ///         static func fetchAll(_ db: Database) throws -> [AuthorInfo] {
    ///             let aggregate = Author.books.count.aliased(CodingKeys.bookCount)
    ///             let request = Author.annotated(with: aggregate)
    ///             return try AuthorInfo.fetchAll(db, request)
    ///         }
    ///     }
    public func aliased(_ key: CodingKey) -> AssociationAggregate<RowDecoder> {
        return aliased(key.stringValue)
    }
}

// MARK: - Logical Operators (AND, OR, NOT)

/// Returns a logically negated aggregate.
///
/// For example:
///
///     let request = Author.having(!Author.books.isEmpty)
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
///     let request = Author.having(Author.books.isEmpty && Author.paintings.isEmpty)
public func && <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression && rExpression)
    }
}

// TODO: test & document
/// :nodoc:
public func && <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression && rhs)
    }
}

// TODO: test & document
/// :nodoc:
public func && <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs && expression)
    }
}


/// Groups two aggregates with the `OR` SQL operator.
///
/// For example:
///
///     let request = Author.having(!Author.books.isEmpty || !Author.paintings.isEmpty)
public func || <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression || rExpression)
    }
}

// TODO: test & document
/// :nodoc:
public func || <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression || rhs)
    }
}

// TODO: test & document
/// :nodoc:
public func || <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.having(Author.books.count == Author.paintings.count)
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.having(Author.books.count == 3)
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression == rhs)
    }
}

/// Returns an aggregate that compares an aggregate with the `=` SQL operator.
///
/// For example:
///
///     let request = Author.having(3 == Author.books.count)
public func == <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs == expression)
    }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     let request = Author.having(Author.books.isEmpty == false)
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
///     let request = Author.having(false == Author.books.isEmpty)
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
///     let request = Author.having(Author.books.count != Author.paintings.count)
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.having(Author.books.count != 3)
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression != rhs)
    }
}

/// Returns an aggregate that compares an aggregate with the `<>` SQL operator.
///
/// For example:
///
///     let request = Author.having(3 != Author.books.count)
public func != <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs != expression)
    }
}

/// Returns an aggregate that checks the boolean value of an aggregate.
///
/// For example:
///
///     let request = Author.having(Author.books.isEmpty != true)
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
///     let request = Author.having(true != Author.books.isEmpty)
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
///     let request = Author.having(Author.books.count === Author.paintings.count)
public func === <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.having(Author.books.count === 3)
public func === <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression === rhs)
    }
}

/// Returns an aggregate that compares an aggregate with the `IS` SQL operator.
///
/// For example:
///
///     let request = Author.having(3 === Author.books.count)
public func === <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs === expression)
    }
}

/// Returns an aggregate that compares two aggregates with the `IS NOT` SQL operator.
///
/// For example:
///
///     let request = Author.having(Author.books.count !== Author.paintings.count)
public func !== <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.having(Author.books.count !== 3)
public func !== <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression !== rhs)
    }
}

/// Returns an aggregate that compares an aggregate with the `IS NOT` SQL operator.
///
/// For example:
///
///     let request = Author.having(3 !== Author.books.count)
public func !== <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.having(Author.books.count <= Author.paintings.count)
public func <= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.having(Author.books.count <= 3)
public func <= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression <= rhs)
    }
}

/// Returns an aggregate that compares an aggregate with the `<=` SQL operator.
///
/// For example:
///
///     let request = Author.having(3 <= Author.books.count)
public func <= <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs <= expression)
    }
}

/// Returns an aggregate that compares two aggregates with the `<` SQL operator.
///
/// For example:
///
///     let request = Author.having(Author.books.count < Author.paintings.count)
public func < <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.having(Author.books.count < 3)
public func < <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression < rhs)
    }
}

/// Returns an aggregate that compares an aggregate with the `<` SQL operator.
///
/// For example:
///
///     let request = Author.having(3 < Author.books.count)
public func < <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs < expression)
    }
}

/// Returns an aggregate that compares two aggregates with the `>` SQL operator.
///
/// For example:
///
///     let request = Author.having(Author.books.count > Author.paintings.count)
public func > <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.having(Author.books.count > 3)
public func > <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression > rhs)
    }
}

/// Returns an aggregate that compares an aggregate with the `>` SQL operator.
///
/// For example:
///
///     let request = Author.having(3 > Author.books.count)
public func > <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs > expression)
    }
}

/// Returns an aggregate that compares two aggregates with the `>=` SQL operator.
///
/// For example:
///
///     let request = Author.having(Author.books.count >= Author.paintings.count)
public func >= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.having(Author.books.count >= 3)
public func >= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression >= rhs)
    }
}

/// Returns an aggregate that compares an aggregate with the `>=` SQL operator.
///
/// For example:
///
///     let request = Author.having(3 >= Author.books.count)
public func >= <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.annotated(with: -Author.books.count)
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
///     let request = Author.annotated(with: Author.books.count + Author.paintings.count)
public func + <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.annotated(with: Author.books.count + 1)
public func + <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression + rhs)
    }
}

/// Returns an aggregate that sums an aggregate with the `+` SQL operator.
///
/// For example:
///
///     let request = Author.annotated(with: 1 + Author.books.count)
public func + <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs + expression)
    }
}

/// Returns an aggregate that substracts two aggregates with the `-` SQL operator.
///
/// For example:
///
///     let request = Author.annotated(with: Author.books.count - Author.paintings.count)
public func - <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.annotated(with: Author.books.count - 1)
public func - <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression - rhs)
    }
}

/// Returns an aggregate that substracts an aggregate with the `-` SQL operator.
///
/// For example:
///
///     let request = Author.annotated(with: 1 - Author.books.count)
public func - <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs - expression)
    }
}

/// Returns an aggregate that multiplies two aggregates with the `*` SQL operator.
///
/// For example:
///
///     let request = Author.annotated(with: Author.books.count * Author.paintings.count)
public func * <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.annotated(with: Author.books.count * 2)
public func * <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression * rhs)
    }
}

/// Returns an aggregate that substracts an aggregate with the `*` SQL operator.
///
/// For example:
///
///     let request = Author.annotated(with: 2 * Author.books.count)
public func * <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs * expression)
    }
}

/// Returns an aggregate that multiplies two aggregates with the `/` SQL operator.
///
/// For example:
///
///     let request = Author.annotated(with: Author.books.count / Author.paintings.count)
public func / <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
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
///     let request = Author.annotated(with: Author.books.count / 2)
public func / <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression / rhs)
    }
}

/// Returns an aggregate that substracts an aggregate with the `/` SQL operator.
///
/// For example:
///
///     let request = Author.annotated(with: 2 / Author.books.count)
public func / <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs / expression)
    }
}

// TODO: add support for ABS(aggregate)
// TODO: add support for LENGTH(aggregate)
// TODO: add support for IFNULL(aggregate, ...)
// TODO: add support for IFNULL(..., aggregate)
