public typealias AssociationMapping = (SQLTableQualifier, SQLTableQualifier) -> SQLExpression?

enum AssociationMappingRequest {
    case foreignKey(request: ForeignKeyRequest, originIsLeft: Bool)
    
    func fetch(_ db: Database) throws -> AssociationMapping {
        switch self {
        case .foreignKey(request: let foreignKeyRequest, originIsLeft: let originIsLeft):
            let foreignKeyMapping = try foreignKeyRequest.fetch(db).mapping
            let columnMapping: [(left: Column, right: Column)]
            if originIsLeft {
                columnMapping = foreignKeyMapping.map { (left: Column($0.origin), right: Column($0.destination)) }
            } else {
                columnMapping = foreignKeyMapping.map { (left: Column($0.destination), right: Column($0.origin)) }
            }
            return { (leftQualifier, rightQualifier) in
                return columnMapping
                    .map { $0.right.qualifiedExpression(with: rightQualifier) == $0.left.qualifiedExpression(with: leftQualifier) }
                    .joined(operator: .and)
            }
        }
    }
}
