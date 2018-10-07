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
    let aggregatedRequest: (QueryInterfaceRequest<RowDecoder>, TableAlias) -> QueryInterfaceRequest<RowDecoder>
    let expression: SQLExpression
    var alias: String?
    
    init(
        expression: SQLExpression,
        aggregatedRequest: @escaping (QueryInterfaceRequest<RowDecoder>, TableAlias) -> QueryInterfaceRequest<RowDecoder>)
    {
        self.aggregatedRequest = aggregatedRequest
        self.expression = expression
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
    return AssociationAggregate(
        expression: !aggregate.expression,
        aggregatedRequest: aggregate.aggregatedRequest)
}

/// TODO
public func && <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression && rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func && <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression && rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func && <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs && rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func || <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression || rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func || <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression || rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func || <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs || rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

// MARK: - Egality and Identity Operators (=, <>, IS, IS NOT)

/// TODO
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression == rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible?) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression == rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func == <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression == rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func == <RowDecoder>(lhs: SQLExpressible?, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs == rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func == <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs == rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression != rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible?) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression != rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func != <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: Bool) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression != rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func != <RowDecoder>(lhs: SQLExpressible?, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs != rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func != <RowDecoder>(lhs: Bool, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs != rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func === <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression === rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func === <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible?) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression === rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func === <RowDecoder>(lhs: SQLExpressible?, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs === rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func !== <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression !== rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func !== <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible?) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression !== rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func !== <RowDecoder>(lhs: SQLExpressible?, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs !== rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

// MARK: - Comparison Operators (<, >, <=, >=)

/// TODO
public func < <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression < rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func < <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression < rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func < <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs < rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func <= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression <= rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func <= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression <= rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func <= <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs <= rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func > <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression > rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func > <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression > rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func > <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs > rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func >= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression >= rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func >= <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression >= rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func >= <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs >= rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

// MARK: - Arithmetic Operators (+, -, *, /)

/// TODO
public prefix func - <RowDecoder>(aggregate: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: -aggregate.expression,
        aggregatedRequest: aggregate.aggregatedRequest)
}

/// TODO
public func + <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression + rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func + <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression + rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func + <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs + rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func - <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression - rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func - <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression - rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func - <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs - rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func * <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression * rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func * <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression * rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func * <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs * rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

/// TODO
public func / <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression / rhs.expression,
        aggregatedRequest: { request, tableAlias in
            rhs.aggregatedRequest(lhs.aggregatedRequest(request, tableAlias), tableAlias)
    })
}

/// TODO
public func / <RowDecoder>(lhs: AssociationAggregate<RowDecoder>, rhs: SQLExpressible) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs.expression / rhs,
        aggregatedRequest: lhs.aggregatedRequest)
}

/// TODO
public func / <RowDecoder>(lhs: SQLExpressible, rhs: AssociationAggregate<RowDecoder>) -> AssociationAggregate<RowDecoder> {
    return AssociationAggregate(
        expression: lhs / rhs.expression,
        aggregatedRequest: rhs.aggregatedRequest)
}

