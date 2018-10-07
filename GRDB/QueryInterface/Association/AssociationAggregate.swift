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
    let prepare: (QueryInterfaceRequest<RowDecoder>) -> (request: QueryInterfaceRequest<RowDecoder>, expression: SQLExpression)
    var alias: String?
    
    init(_ prepare: @escaping (QueryInterfaceRequest<RowDecoder>) -> (request: QueryInterfaceRequest<RowDecoder>, expression: SQLExpression)) {
        self.prepare = prepare
    }
}

extension AssociationAggregate {
    /// TODO
    public func aliased(_ name: String) -> AssociationAggregate<RowDecoder> {
        var aggregate = self
        aggregate.alias = name
        return aggregate
    }
    
    /// TODO
    public func aliased(_ key: CodingKey) -> AssociationAggregate<RowDecoder> {
        return aliased(key.stringValue)
    }
}

// MARK: - Logical Operators (AND, OR, NOT)

/// TODO
public prefix func ! <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = aggregate.prepare(request)
        return (request: request, expression: !expression)
    }
}

/// TODO
public func && <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression && rExpression)
    }
}

/// TODO
public func && <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression && rhs)
    }
}

/// TODO
public func && <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs && expression)
    }
}

/// TODO
public func || <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression || rExpression)
    }
}

/// TODO
public func || <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression || rhs)
    }
}

/// TODO
public func || <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs || expression)
    }
}

// MARK: - Egality and Identity Operators (=, <>, IS, IS NOT)

/// TODO
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression == rExpression)
    }
}

/// TODO
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression == rhs)
    }
}

/// TODO
public func == <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs == expression)
    }
}

/// TODO
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression == rhs)
    }
}

/// TODO
public func == <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs == expression)
    }
}

/// TODO
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression != rExpression)
    }
}

/// TODO
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression != rhs)
    }
}

/// TODO
public func != <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs != expression)
    }
}

/// TODO
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression != rhs)
    }
}

/// TODO
public func != <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs != expression)
    }
}

/// TODO
public func === <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression === rExpression)
    }
}

/// TODO
public func === <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression === rhs)
    }
}

/// TODO
public func === <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs === expression)
    }
}

/// TODO
public func !== <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression !== rExpression)
    }
}

/// TODO
public func !== <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression !== rhs)
    }
}

/// TODO
public func !== <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs !== expression)
    }
}

// MARK: - Comparison Operators (<, >, <=, >=)

/// TODO
public func <= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression <= rExpression)
    }
}

/// TODO
public func <= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression <= rhs)
    }
}

/// TODO
public func <= <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs <= expression)
    }
}

/// TODO
public func < <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression < rExpression)
    }
}

/// TODO
public func < <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression < rhs)
    }
}

/// TODO
public func < <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs < expression)
    }
}

/// TODO
public func > <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression > rExpression)
    }
}

/// TODO
public func > <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression > rhs)
    }
}

/// TODO
public func > <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs > expression)
    }
}

/// TODO
public func >= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression >= rExpression)
    }
}

/// TODO
public func >= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression >= rhs)
    }
}

/// TODO
public func >= <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs >= expression)
    }
}

// MARK: - Arithmetic Operators (+, -, *, /)

/// TODO
public prefix func - <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = aggregate.prepare(request)
        return (request: request, expression:-expression)
    }
}

/// TODO
public func + <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression + rExpression)
    }
}

/// TODO
public func + <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression + rhs)
    }
}

/// TODO
public func + <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs + expression)
    }
}

/// TODO
public func - <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression - rExpression)
    }
}

/// TODO
public func - <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression - rhs)
    }
}

/// TODO
public func - <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs - expression)
    }
}

/// TODO
public func * <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression * rExpression)
    }
}

/// TODO
public func * <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression * rhs)
    }
}

/// TODO
public func * <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs * expression)
    }
}

/// TODO
public func / <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (lRequest, lExpression) = lhs.prepare(request)
        let (request, rExpression) = rhs.prepare(lRequest)
        return (request: request, expression: lExpression / rExpression)
    }
}

/// TODO
public func / <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = lhs.prepare(request)
        return (request: request, expression: expression / rhs)
    }
}

/// TODO
public func / <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate { request in
        let (request, expression) = rhs.prepare(request)
        return (request: request, expression: lhs / expression)
    }
}

