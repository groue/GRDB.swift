/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The base protocol for all associations that define a connection between two
/// record types.
public protocol Association: DerivableRequest {
    // OriginRowDecoder and RowDecoder provide type safety:
    //
    //      Book.including(required: Book.author)  // compiles
    //      Fruit.including(required: Book.author) // does not compile
    
    /// The record type at the origin of the association.
    ///
    /// In the `belongsTo` association below, it is Book:
    ///
    ///     struct Book: TableRecord {
    ///         // BelongsToAssociation<Book, Author>
    ///         static let author = belongsTo(Author.self)
    ///     }
    associatedtype OriginRowDecoder
    
    /// The associated record type.
    ///
    /// In the `belongsTo` association below, it is Author:
    ///
    ///     struct Book: TableRecord {
    ///         // BelongsToAssociation<Book, Author>
    ///         static let author = belongsTo(Author.self)
    ///     }
    associatedtype RowDecoder
    
    // Association is a protocol, not a struct.
    // This is because we want associations to be richly typed.
    // Yet, we don't want to pollute user code with implementation details of
    // associations. So let's hide all this stuff behind the
    // sqlAssociation property:
    
    /// :nodoc:
    var sqlAssociation: SQLAssociation { get }
    
    /// :nodoc:
    init(sqlAssociation: SQLAssociation)
}

extension Association {
    private func mapRelation(_ transform: (SQLRelation) -> SQLRelation) -> Self {
        return Self.init(sqlAssociation: sqlAssociation.mapRelation(transform))
    }
}

extension Association {

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
    var key: String {
        return sqlAssociation.key
    }
    
    /// Creates an association which selects *selection*.
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     // SELECT player.*, team.color
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId
    ///     let association = Player.team.select([Column("color")])
    ///     var request = Player.including(required: association)
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT player.*, team.color
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId
    ///     let association = Player.team
    ///         .select([Column("id")])
    ///         .select([Column("color")])
    ///     var request = Player.including(required: association)
    public func select(_ selection: [SQLSelectable]) -> Self {
        return mapRelation { $0.select(selection) }
    }
    
    /// Creates an association with the provided *predicate promise* added to
    /// the eventual set of already applied predicates.
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     // SELECT player.*, team.*
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId AND 1
    ///     let association = Player.team.filter { db in true }
    ///     var request = Player.including(required: association)
    public func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> Self {
        return mapRelation { $0.filter(predicate) }
    }
    
    /// Creates an association with the provided *orderings promise*.
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     // SELECT player.*, team.*
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId
    ///     // ORDER BY team.name
    ///     let association = Player.team.order { _ in [Column("name")] }
    ///     var request = Player.including(required: association)
    ///
    /// Any previous ordering is replaced:
    ///
    ///     // SELECT player.*, team.*
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId
    ///     // ORDER BY team.name
    ///     let association = Player.team
    ///         .order{ _ in [Column("color")] }
    ///         .reversed()
    ///         .order{ _ in [Column("name")] }
    ///     var request = Player.including(required: association)
    public func order(_ orderings: @escaping (Database) throws -> [SQLOrderingTerm]) -> Self {
        return mapRelation { $0.order(orderings) }
    }
    
    /// Creates an association that reverses applied orderings.
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     // SELECT player.*, team.*
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId
    ///     // ORDER BY team.name DESC
    ///     let association = Player.team.order(Column("name")).reversed()
    ///     var request = Player.including(required: association)
    ///
    /// If no ordering was applied, the returned association is identical.
    ///
    ///     // SELECT player.*, team.*
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId
    ///     let association = Player.team.reversed()
    ///     var request = Player.including(required: association)
    public func reversed() -> Self {
        return mapRelation { $0.reversed() }
    }
    
    /// Creates an association with the given key.
    ///
    /// This new key impacts how rows fetched from the resulting association
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
    public func forKey(_ key: String) -> Self {
        return Self.init(sqlAssociation: sqlAssociation.forKey(key))
    }
    
    /// Creates an association with the given key.
    ///
    /// This new key helps Decodable records decode rows fetched from the
    /// resulting association:
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     struct PlayerInfo: FetchableRecord, Decodable {
    ///         let player: Player
    ///         let team: Team
    ///
    ///         static func all() -> QueryInterfaceRequest<PlayerInfo> {
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
    
    /// Creates an association that allows you to define expressions that target
    /// a specific database table.
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
    ///         .filter(teamAlias[Column("color")] == "red")
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
    ///         .filter(sql: "custom.color = ?", arguments: ["red"])
    public func aliased(_ alias: TableAlias) -> Self {
        return mapRelation { $0.qualified(with: alias) }
    }
}

extension Association {
    /// Creates an association that includes another one. The columns of the
    /// associated record are selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func including<A: Association>(optional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation { association.sqlAssociation.joinedRelation($0, joinOperator: .optional) }
    }
    
    /// Creates an association that includes another one. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func including<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation { association.sqlAssociation.joinedRelation($0, joinOperator: .required) }
    }
    
    /// Creates an association that joins another one. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func joining<A: Association>(optional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation { association.select([]).sqlAssociation.joinedRelation($0, joinOperator: .optional) }
    }
    
    /// Creates an association that joins another one. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func joining<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation { association.select([]).sqlAssociation.joinedRelation($0, joinOperator: .required) }
    }
}

// Allow association.filter(key: ...)
extension Association where Self: TableRequest, RowDecoder: TableRecord {
    /// :nodoc:
    public var databaseTableName: String { return RowDecoder.databaseTableName }
}

// MARK: - ToOneAssociation

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The base protocol for all associations that define a one-to-one connection.
public protocol ToOneAssociation: Association { }

// MARK: - SQLAssociation

/// :nodoc:
public /* TODO: internal */ struct SQLAssociation {
    // SQLAssociation is a non-empty array of association items
    private struct Item {
        var key: String
        var joinCondition: JoinCondition
        var relation: SQLRelation
    }
    private var head: Item
    private var tail: [Item]
    
    var key: String { return head.key }
    
    private init(head: Item, tail: [Item]) {
        self.head = head
        self.tail = tail
    }
    
    init(key: String, joinCondition: JoinCondition, relation: SQLRelation) {
        head = Item(key: key, joinCondition: joinCondition, relation: relation)
        tail = []
    }
    
    func forKey(_ key: String) -> SQLAssociation {
        var result = self
        result.head.key = key
        return result
    }
    
    func mapRelation(_ transform: (SQLRelation) -> SQLRelation) -> SQLAssociation {
        var result = self
        result.head.relation = transform(head.relation)
        return result
    }
    
    func appending(_ other: SQLAssociation) -> SQLAssociation {
        var result = self
        result.tail.append(other.head)
        result.tail.append(contentsOf: other.tail)
        return result
    }
    
    /// Returns a relation joined with self.
    ///
    /// This method provides fundamental support for joining methods.
    func joinedRelation(_ relation: SQLRelation, joinOperator: JoinOperator) -> SQLRelation {
        let headJoin = SQLJoin(
            joinOperator: joinOperator,
            joinCondition: head.joinCondition,
            relation: head.relation)
        
        guard let next = tail.first else {
            return relation.appendingJoin(headJoin, forKey: head.key)
        }
        
        // Recursion step: remove one item from tail by shifting the next item
        // to the head.
        //
        // From:
        //  (... JOIN next) JOIN (head)
        //  ^~ tail              ^~ head
        //
        // We reduce into:
        //  (...) JOIN (next JOIN head)
        //  ^~ tail    ^~ head
        let nextRelation = next.relation.select([]).appendingJoin(headJoin, forKey: head.key)
        let nextHead = Item(key: next.key, joinCondition: next.joinCondition, relation: nextRelation)
        let nextTail = Array(tail.dropFirst())
        let nextImpl = SQLAssociation(head: nextHead, tail: nextTail)
        return nextImpl.joinedRelation(relation, joinOperator: joinOperator)
    }
    
    /// Support for MutablePersistableRecord.request(for:).
    ///
    /// For example:
    ///
    ///     struct Team: {
    ///         static let players = hasMany(Player.self)
    ///         var players: QueryInterfaceRequest<Player> {
    ///             return request(for: Team.players)
    ///         }
    ///     }
    ///
    ///     let team: Team = ...
    ///     let players = try team.players.fetchAll(db) // [Player]
    func request<OriginRowDecoder, RowDecoder>(of: RowDecoder.Type, from record: OriginRowDecoder)
        -> QueryInterfaceRequest<RowDecoder>
        where OriginRowDecoder: MutablePersistableRecord
    {
        guard tail.isEmpty else {
            fatalError("Not implemented")
        }
        
        // Goal: turn `JOIN association ON association.recordId = record.id`
        // into a regular request `SELECT * FROM association WHERE association.recordId = 123`
        
        // We need table aliases to build the joining condition
        let associationAlias = TableAlias()
        let recordAlias = TableAlias()
        
        // Turn the association query into a query interface request:
        // JOIN association -> SELECT FROM association
        return QueryInterfaceRequest(query: SQLSelectQuery(relation: head.relation))
            
            // Turn the JOIN condition into a regular WHERE condition
            .filter { db in
                // Build a join condition: `association.recordId = record.id`
                // We still need to replace `record.id` with the actual record id.
                let joinExpression = try self.head.joinCondition.sqlExpression(db, leftAlias: recordAlias, rightAlias: associationAlias)
                
                // Serialize record: ["id": 123, ...]
                // We do it as late as possible, when request is about to be
                // executed, in order to support long-lived reference types.
                let container = try PersistenceContainer(db, record)
                
                // Replace `record.id` with 123
                return joinExpression.resolvedExpression(inContext: [recordAlias: container])
            }
            
            // We just added a condition qualified with associationAlias. Don't
            // risk introducing conflicting aliases that would prevent the user
            // from setting a custom alias name: force the same alias for the
            // whole request.
            .aliased(associationAlias)
    }
}
