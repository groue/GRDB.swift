/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// In `SELECT a.*, b.* FROM a JOIN b ON b.aid = a.id AND b.name = 'foo'`,
/// the AssociationRequest is (`b.*` + `b.name = 'foo'`).
/// :nodoc:
public struct AssociationRequest<T> {
    let query: AssociationQuery
    
    init(query: AssociationQuery) {
        self.query = query
    }
    
    init(_ request: QueryInterfaceRequest<T>) {
        self.init(query: AssociationQuery(request.query))
    }
}

extension AssociationRequest {
    func select(_ selection: [SQLSelectable]) -> AssociationRequest {
        return AssociationRequest(query: query.select(selection))
    }
    
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> AssociationRequest {
        return AssociationRequest(query: query.filter(predicate))
    }
    
    func order(_ orderings: @escaping (Database) throws -> [SQLOrderingTerm]) -> AssociationRequest {
        return AssociationRequest(query: query.order(orderings))
    }
    
    func reversed() -> AssociationRequest {
        return AssociationRequest(query: query.reversed())
    }
    
    func aliased(_ alias: TableAlias) -> AssociationRequest {
        return AssociationRequest(query: query.qualified(with: alias))
    }
    
    func joining<A: Association>(_ joinOperator: AssociationJoinOperator, _ association: A)
        -> AssociationRequest
        where A.OriginRowDecoder == T
    {
        let join = AssociationJoin(
            joinOperator: joinOperator,
            joinCondition: association.joinCondition,
            query: association.request.query)
        return AssociationRequest(query: query.appendingJoin(join, forKey: association.key))
    }
}
