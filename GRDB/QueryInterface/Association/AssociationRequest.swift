/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// In `SELECT a.*, b.* FROM a JOIN b ON b.aid = a.id AND b.name = 'foo'`,
/// the AssociationRequest is (`b.*` + `b.name = 'foo'`).
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
    
    func order(_ orderings: [SQLOrderingTerm]) -> AssociationRequest {
        return AssociationRequest(query: query.order(orderings))
    }
    
    func reversed() -> AssociationRequest {
        return AssociationRequest(query: query.reversed())
    }
    
    func aliased(_ alias: TableAlias) -> AssociationRequest {
        let userProvidedAlias = alias.userProvidedAlias
        defer {
            // Allow user to explicitely rename (TODO: test)
            alias.userProvidedAlias = userProvidedAlias
        }
        return AssociationRequest(query: query.qualified(with: &alias.qualifier))
    }
    
    func joining<A: Association>(_ joinOperator: AssociationJoinOperator, _ association: A)
        -> AssociationRequest
        where A.LeftAssociated == T
    {
        let join = AssociationJoin(
            joinOperator: joinOperator,
            query: association.request.query,
            key: association.key,
            joinConditionPromise: DatabasePromise(association.joinCondition))
        return AssociationRequest(query: query.joining(join))
    }
}
