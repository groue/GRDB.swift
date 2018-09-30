/// QueryOrdering provides the order clause to QueryInterfaceQuery
/// and AssociationQuery.
struct QueryOrdering {
    private enum Element {
        case orderingTerms((Database) throws -> [SQLOrderingTerm])
        case queryOrdering(QueryOrdering)
        
        var reversed: Element {
            switch self {
            case .orderingTerms(let orderings):
                return .orderingTerms { db in try orderings(db).map { $0.reversed } }
            case .queryOrdering(let queryOrdering):
                return .queryOrdering(queryOrdering.reversed)
            }
        }
        
        func qualified(with alias: TableAlias) -> Element {
            switch self {
            case .orderingTerms(let orderings):
                return .orderingTerms { db in try orderings(db).map { $0.qualifiedOrdering(with: alias) } }
            case .queryOrdering(let queryOrdering):
                return .queryOrdering(queryOrdering.qualified(with: alias))
            }
        }
        
        func resolve(_ db: Database) throws -> [SQLOrderingTerm] {
            switch self {
            case .orderingTerms(let orderings):
                return try orderings(db)
            case .queryOrdering(let queryOrdering):
                return try queryOrdering.resolve(db)
            }
        }
    }
    
    private var elements: [Element] = []
    var isReversed: Bool
    
    var isEmpty: Bool {
        return elements.isEmpty
    }
    
    private init(elements: [Element], isReversed: Bool) {
        self.elements = elements
        self.isReversed = isReversed
    }
    
    init() {
        self.init(
            elements: [],
            isReversed: false)
    }
    
    init(orderings: @escaping (Database) throws -> [SQLOrderingTerm]) {
        self.init(
            elements: [.orderingTerms(orderings)],
            isReversed: false)
    }
    
    var reversed: QueryOrdering {
        return QueryOrdering(
            elements: elements,
            isReversed: !isReversed)
    }
    
    func qualified(with alias: TableAlias) -> QueryOrdering {
        return QueryOrdering(
            elements: elements.map { $0.qualified(with: alias) },
            isReversed: isReversed)
    }
    
    func appending(_ ordering: QueryOrdering) -> QueryOrdering {
        return QueryOrdering(
            elements: elements + [.queryOrdering(ordering)],
            isReversed: isReversed)
    }
    
    func resolve(_ db: Database) throws -> [SQLOrderingTerm] {
        if isReversed {
            return try elements.flatMap { try $0.reversed.resolve(db) }
        } else {
            return try elements.flatMap { try $0.resolve(db) }
        }
    }
}
