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
public struct AssociationAggregate<RowDecoder> {
    let prepare: (QueryInterfaceRequest<RowDecoder>) -> (request: QueryInterfaceRequest<RowDecoder>, expression: SQLExpression)
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

/// :nodoc:
public prefix func ! <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = aggregate.prepare(request)
        return (request: request, expression: !expression)
    }
}

/// :nodoc:
public func && <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression && rExpression)
    }
}

/// :nodoc:
public func && <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression && rhs)
    }
}

/// :nodoc:
public func && <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs && expression)
    }
}

/// :nodoc:
public func || <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression || rExpression)
    }
}

/// :nodoc:
public func || <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression || rhs)
    }
}

/// :nodoc:
public func || <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs || expression)
    }
}

// MARK: - Egality and Identity Operators (=, <>, IS, IS NOT)

/// :nodoc:
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression == rExpression)
    }
}

/// :nodoc:
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression == rhs)
    }
}

/// :nodoc:
public func == <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs == expression)
    }
}

/// :nodoc:
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression == rhs)
    }
}

/// :nodoc:
public func == <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs == expression)
    }
}

/// :nodoc:
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression != rExpression)
    }
}

/// :nodoc:
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression != rhs)
    }
}

/// :nodoc:
public func != <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs != expression)
    }
}

/// :nodoc:
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression != rhs)
    }
}

/// :nodoc:
public func != <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs != expression)
    }
}

/// :nodoc:
public func === <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression === rExpression)
    }
}

/// :nodoc:
public func === <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression === rhs)
    }
}

/// :nodoc:
public func === <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs === expression)
    }
}

/// :nodoc:
public func !== <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression !== rExpression)
    }
}

/// :nodoc:
public func !== <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression !== rhs)
    }
}

/// :nodoc:
public func !== <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs !== expression)
    }
}

// MARK: - Comparison Operators (<, >, <=, >=)

/// :nodoc:
public func <= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression <= rExpression)
    }
}

/// :nodoc:
public func <= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression <= rhs)
    }
}

/// :nodoc:
public func <= <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs <= expression)
    }
}

/// :nodoc:
public func < <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression < rExpression)
    }
}

/// :nodoc:
public func < <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression < rhs)
    }
}

/// :nodoc:
public func < <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs < expression)
    }
}

/// :nodoc:
public func > <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression > rExpression)
    }
}

/// :nodoc:
public func > <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression > rhs)
    }
}

/// :nodoc:
public func > <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs > expression)
    }
}

/// :nodoc:
public func >= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression >= rExpression)
    }
}

/// :nodoc:
public func >= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression >= rhs)
    }
}

/// :nodoc:
public func >= <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs >= expression)
    }
}

// MARK: - Arithmetic Operators (+, -, *, /)

/// :nodoc:
public prefix func - <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = aggregate.prepare(request)
        return (request: request, expression:-expression)
    }
}

/// :nodoc:
public func + <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression + rExpression)
    }
}

/// :nodoc:
public func + <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression + rhs)
    }
}

/// :nodoc:
public func + <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs + expression)
    }
}

/// :nodoc:
public func - <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression - rExpression)
    }
}

/// :nodoc:
public func - <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression - rhs)
    }
}

/// :nodoc:
public func - <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs - expression)
    }
}

/// :nodoc:
public func * <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression * rExpression)
    }
}

/// :nodoc:
public func * <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression * rhs)
    }
}

/// :nodoc:
public func * <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs * expression)
    }
}

/// :nodoc:
public func / <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression / rExpression)
    }
}

/// :nodoc:
public func / <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression / rhs)
    }
}

/// :nodoc:
public func / <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs / expression)
    }
}

