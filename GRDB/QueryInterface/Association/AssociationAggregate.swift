//
//  AssociationAggregate.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/09/2018.
//  Copyright © 2018 Gwendal Roué. All rights reserved.
//

import Foundation

/// TODO
public struct AssociationAggregate<A: Association> {
    let association: A
    let expression: SQLExpression
    var alias: String?
    
    init(association: A, expression: SQLExpression) {
        self.association = association
        self.expression = expression
    }
}

extension AssociationAggregate {
    /// TODO
    public func aliased(_ name: String) -> AssociationAggregate<A> {
        var aggregate = self
        aggregate.alias = name
        return aggregate
    }
}

/// TODO
public prefix func ! <A>(aggregate: AssociationAggregate<A>) -> AssociationAggregate<A> {
    return AssociationAggregate(
        association: aggregate.association,
        expression: !aggregate.expression)
}

/// TODO
public func == <A>(lhs: AssociationAggregate<A>, rhs: SQLExpressible?) -> AssociationAggregate<A> {
    return AssociationAggregate(
        association: lhs.association,
        expression: lhs.expression == rhs)
}

/// TODO
public func == <A>(lhs: SQLExpressible?, rhs: AssociationAggregate<A>) -> AssociationAggregate<A> {
    return AssociationAggregate(
        association: rhs.association,
        expression: lhs == rhs.expression)
}

/// TODO
public func == <A>(lhs: AssociationAggregate<A>, rhs: Bool) -> AssociationAggregate<A> {
    return AssociationAggregate(
        association: lhs.association,
        expression: lhs.expression == rhs)
}

/// TODO
public func != <A>(lhs: AssociationAggregate<A>, rhs: SQLExpressible?) -> AssociationAggregate<A> {
    return AssociationAggregate(
        association: lhs.association,
        expression: lhs.expression != rhs)
}

/// TODO
public func != <A>(lhs: SQLExpressible?, rhs: AssociationAggregate<A>) -> AssociationAggregate<A> {
    return AssociationAggregate(
        association: rhs.association,
        expression: lhs != rhs.expression)
}

/// TODO
public func != <A>(lhs: AssociationAggregate<A>, rhs: Bool) -> AssociationAggregate<A> {
    return AssociationAggregate(
        association: lhs.association,
        expression: lhs.expression != rhs)
}
