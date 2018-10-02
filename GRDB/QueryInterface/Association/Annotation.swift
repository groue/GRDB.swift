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
    var alias: String
}
