/// The base protocol for all associations that define a connection between two
/// Record types.
public protocol Association: SelectionRequest, FilteredRequest, OrderedRequest {
    associatedtype LeftAssociated
    associatedtype RightAssociated
    
    /// The association key defines how rows fetched from this association
    /// should be consumed.
    ///
    /// For example:
    ///
    ///     struct Player: TableRecord {
    ///         // The default key of this association is the name of the
    ///         // database table for teams, let's say "team":
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///     print(Player.team.key) // Prints "team"
    ///
    ///     // Consume rows:
    ///     let request = Player.including(required: Player.team)
    ///     for row in Row.fetchAll(db, request) {
    ///         let team: Team = row["team"] // the association key
    ///     }
    ///
    /// The key can be redefined with the `forKey` method:
    ///
    ///     let request = Player.including(required: Player.team.forKey("custom"))
    ///     for row in Row.fetchAll(db, request) {
    ///         let team: Team = row["custom"]
    ///     }
    var key: String { get }
    
    /// Creates an association with the given key.
    ///
    /// This new key impacts how rows fetched from this association
    /// should be consumed:
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     // Consume rows:
    ///     let request = Player.including(required: Player.team.forKey("custom"))
    ///     for row in Row.fetchAll(db, request) {
    ///         let team: Team = row["custom"]
    ///     }
    func forKey(_ key: String) -> Self
    
    /// :nodoc:
    var request: AssociationRequest<RightAssociated> { get }
    
    /// :nodoc:
    func joinCondition(_ db: Database) throws -> JoinCondition
    
    /// :nodoc:
    func mapRequest(_ transform: (AssociationRequest<RightAssociated>) -> AssociationRequest<RightAssociated>) -> Self
}

extension Association {
    /// Creates an association with a new net of selected columns.
    ///
    /// Any previous selection is replaced.
    public func select(_ selection: [SQLSelectable]) -> Self {
        return mapRequest { $0.select(selection) }
    }
    
    /// Creates an association with the provided *predicate promise* added to
    /// the eventual set of already applied predicates.
    public func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> Self {
        return mapRequest { $0.filter(predicate) }
    }
    
    /// Creates an association with the provided *orderings*.
    ///
    /// Any previous ordering is replaced.
    public func order(_ orderings: [SQLOrderingTerm]) -> Self {
        return mapRequest { $0.order(orderings) }
    }
    
    /// Creates an association that reverses applied orderings. If no ordering
    /// was applied, the returned request is identical.
    public func reversed() -> Self {
        return mapRequest { $0.reversed() }
    }
    
    /// Creates an association with the given key.
    ///
    /// This new key helps Decodable records decode fetched rows:
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     struct PlayerInfo: FetchableRecord, Decodable {
    ///         let player: Player
    ///         let team: Team
    ///
    ///         static func all() -> AnyFetchRequest<PlayerInfo> {
    ///             return Player
    ///                 .including(required: Player.team.forKey(CodingKeys.team))
    ///                 .asRequest(of: PlayerInfo.self)
    ///         }
    ///     }
    ///
    ///     let playerInfos = PlayerInfo.all().fetchAll(db)
    ///     print(playerInfos.first?.team)
    public func forKey(_ codingKey: CodingKey) -> Self {
        return forKey(codingKey.stringValue)
    }

    /// Creates an association that allows you to define unambiguous expressions
    /// based on the associated record.
    ///
    /// In the example below, the "team.color = 'red'" condition in the where
    /// clause could be not achieved without table aliases.
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     // SELECT player.*, team.*
    ///     // JOIN team ON ...
    ///     // WHERE team.color = 'red'
    ///     let teamAlias = TableAlias()
    ///     let request = Player
    ///         .including(required: Player.team.aliased(teamAlias))
    ///         .filter(teamAlias[Column("color"] == "red")
    ///
    /// When you give a name to a table alias, you can reliably inject sql
    /// snippets in your requests:
    ///
    ///     // SELECT player.*, custom.*
    ///     // JOIN team custom ON ...
    ///     // WHERE custom.color = 'red'
    ///     let teamAlias = TableAlias(name: "custom")
    ///     let request = Player
    ///         .including(required: Player.team.aliased(teamAlias))
    ///         .filter(sql: "custom.color = ?", arguments: ["red")
    public func aliased(_ alias: TableAlias) -> Self {
        return mapRequest { $0.aliased(alias) }
    }
}

public typealias JoinCondition = (_ leftQualifier: SQLTableQualifier, _ rightQualifier: SQLTableQualifier) -> SQLExpression?

struct ForeignKeyJoinConditionRequest {
    var foreignKeyRequest: ForeignKeyRequest
    var originIsLeft: Bool
    
    func fetch(_ db: Database) throws -> JoinCondition {
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

extension Association {
    /// Creates an association that includes another one. The columns of the
    /// associated record are selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func including<A: Association>(optional association: A) -> Self where A.LeftAssociated == RightAssociated {
        return mapRequest { $0.joining(.optional, association) }
    }
    
    /// Creates an association that includes another one. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func including<A: Association>(required association: A) -> Self where A.LeftAssociated == RightAssociated {
        return mapRequest { $0.joining(.required, association) }
    }
    
    /// Creates an association that joins another one. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func joining<A: Association>(optional association: A) -> Self where A.LeftAssociated == RightAssociated {
        return mapRequest { $0.joining(.optional, association.select([])) }
    }
    
    /// Creates an association that joins another one. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func joining<A: Association>(required association: A) -> Self where A.LeftAssociated == RightAssociated {
        return mapRequest { $0.joining(.required, association.select([])) }
    }
}

extension Association where LeftAssociated: MutablePersistableRecord {
    func request(from record: LeftAssociated) -> QueryInterfaceRequest<RightAssociated> {
        let query = request.query.qualifiedQuery // make sure query has a qualifier
        let associationQualifier = query.qualifier!
        let recordQualifier = SQLTableQualifier.init(tableName: LeftAssociated.databaseTableName)
        
        // Turn `right.id = left.id` into `right.id = 1`
        let resolvedQuery = query.filter { db in
            guard let joinCondition = try self.joinCondition(db)(recordQualifier, associationQualifier) else {
                fatalError("Can't request from record without association mapping")
            }
            let container = PersistenceContainer(record) // support for record classes: late construction of container
            return joinCondition.resolvedExpression(inContext: [recordQualifier: container])
        }
        
        return QueryInterfaceRequest(query: QueryInterfaceQuery(resolvedQuery))
    }
}
