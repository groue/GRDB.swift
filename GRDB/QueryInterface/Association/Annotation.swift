//
//  Annotation.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/09/2018.
//  Copyright © 2018 Gwendal Roué. All rights reserved.
//

import Foundation

/// TODO
public struct Annotation<A: Association> {
    let association: A
    let expression: SQLExpression
    var alias: String?
    
    init(association: A, expression: SQLExpression) {
        self.association = association
        self.expression = expression
    }
}

extension Annotation {
    func aliased(_ name: String) -> Annotation<A> {
        var annotation = self
        annotation.alias = name
        return annotation
    }
}

public prefix func ! <A>(annotation: Annotation<A>) -> Annotation<A> {
    return Annotation(
        association: annotation.association,
        expression: !annotation.expression)
}

public func == <A>(lhs: Annotation<A>, rhs: SQLExpressible?) -> Annotation<A> {
    return Annotation(
        association: lhs.association,
        expression: lhs.expression == rhs)
}

public func == <A>(lhs: SQLExpressible?, rhs: Annotation<A>) -> Annotation<A> {
    return Annotation(
        association: rhs.association,
        expression: lhs == rhs.expression)
}

public func != <A>(lhs: Annotation<A>, rhs: SQLExpressible?) -> Annotation<A> {
    return Annotation(
        association: lhs.association,
        expression: lhs.expression != rhs)
}

public func != <A>(lhs: SQLExpressible?, rhs: Annotation<A>) -> Annotation<A> {
    return Annotation(
        association: rhs.association,
        expression: lhs != rhs.expression)
}
