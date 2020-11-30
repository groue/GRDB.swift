//
//  JoinAssociation.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/11/2020.
//  Copyright © 2020 Gwendal Roué. All rights reserved.
//

public struct JoinAssociation<Origin, Destination>: AssociationToOne {
    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination
    
    /// :nodoc:
    public var _sqlAssociation: _SQLAssociation
    
    /// :nodoc:
    public init(sqlAssociation: _SQLAssociation) {
        self._sqlAssociation = sqlAssociation
    }
    
    init(
        key: SQLAssociationKey,
        condition: SQLAssociationCondition,
        relation: SQLRelation)
    {
        _sqlAssociation = _SQLAssociation(
            key: key,
            condition: condition,
            relation: relation,
            cardinality: .toOne)
    }
}
