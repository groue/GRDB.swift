//
//  AssociationAggregate.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/09/2018.
//  Copyright © 2018 Gwendal Roué. All rights reserved.
//

import Foundation

/// TODO
public struct AssociationAggregate<RowDecoder> {
    // TODO: find a name
    let run: (QueryInterfaceRequest<RowDecoder>) -> (request: QueryInterfaceRequest<RowDecoder>, expression: SQLExpression)
    var alias: String?
    
    init(run: @escaping (QueryInterfaceRequest<RowDecoder>) -> (request: QueryInterfaceRequest<RowDecoder>, expression: SQLExpression)) {
        self.run = run
    }
}

extension AssociationAggregate {
    /// TODO
    public func aliased(_ name: String) -> AssociationAggregate<RowDecoder> {
        var aggregate = self
        aggregate.alias = name
        return aggregate
    }
}

// MARK: - Logical Operators (AND, OR, NOT)

/// TODO
public prefix func ! <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = aggregate.run(request)
        return (request: request, expression: !expression)
    }
}

/// TODO
public func && <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression && rExpression)
    }
}

/// TODO
public func && <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression && rhs)
    }
}

/// TODO
public func && <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs && expression)
    }
}

/// TODO
public func || <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression || rExpression)
    }
}

/// TODO
public func || <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression || rhs)
    }
}

/// TODO
public func || <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs || expression)
    }
}

// MARK: - Egality and Identity Operators (=, <>, IS, IS NOT)

/// TODO
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression == rExpression)
    }
}

/// TODO
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression == rhs)
    }
}

/// TODO
public func == <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs == expression)
    }
}

/// TODO
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression == rhs)
    }
}

/// TODO
public func == <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs == expression)
    }
}

/// TODO
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression != rExpression)
    }
}

/// TODO
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression != rhs)
    }
}

/// TODO
public func != <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs != expression)
    }
}

/// TODO
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression != rhs)
    }
}

/// TODO
public func != <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs != expression)
    }
}

/// TODO
public func === <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression === rExpression)
    }
}

/// TODO
public func === <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression === rhs)
    }
}

/// TODO
public func === <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs === expression)
    }
}

/// TODO
public func !== <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression !== rExpression)
    }
}

/// TODO
public func !== <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression !== rhs)
    }
}

/// TODO
public func !== <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs !== expression)
    }
}

// MARK: - Comparison Operators (<, >, <=, >=)

/// TODO
public func <= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression <= rExpression)
    }
}

/// TODO
public func <= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression <= rhs)
    }
}

/// TODO
public func <= <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs <= expression)
    }
}

/// TODO
public func < <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression < rExpression)
    }
}

/// TODO
public func < <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression < rhs)
    }
}

/// TODO
public func < <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs < expression)
    }
}

/// TODO
public func > <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression > rExpression)
    }
}

/// TODO
public func > <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression > rhs)
    }
}

/// TODO
public func > <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs > expression)
    }
}

/// TODO
public func >= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression >= rExpression)
    }
}

/// TODO
public func >= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression >= rhs)
    }
}

/// TODO
public func >= <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs >= expression)
    }
}

// MARK: - Arithmetic Operators (+, -, *, /)

/// TODO
public prefix func - <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = aggregate.run(request)
        return (request: request, expression:-expression)
    }
}

/// TODO
public func + <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression + rExpression)
    }
}

/// TODO
public func + <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression + rhs)
    }
}

/// TODO
public func + <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs + expression)
    }
}

/// TODO
public func - <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression - rExpression)
    }
}

/// TODO
public func - <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression - rhs)
    }
}

/// TODO
public func - <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs - expression)
    }
}

/// TODO
public func * <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression * rExpression)
    }
}

/// TODO
public func * <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression * rhs)
    }
}

/// TODO
public func * <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs * expression)
    }
}

/// TODO
public func / <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.run(request)
        let (request, rExpression) = rhs.run(lRequest)
        return (request: request, expression: lExpression / rExpression)
    }
}

/// TODO
public func / <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.run(request)
        return (request: request, expression: expression / rhs)
    }
}

/// TODO
public func / <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.run(request)
        return (request: request, expression: lhs / expression)
    }
}

