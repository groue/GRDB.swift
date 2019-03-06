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
    // associations. So let's hide all this stuff behind the _impl property:
    
    /// :nodoc:
    associatedtype Impl: AssociationImpl
    
    /// :nodoc:
    var _impl: Impl { get }
    
    /// :nodoc:
    init(_impl: Impl)
}

extension Association {
    private func mapImpl(_ transform: (Impl) throws -> Impl) rethrows -> Self {
        return try Self.init(_impl: transform(_impl))
    }
    
    private func mapRelation(_ transform: (SQLRelation) -> SQLRelation) -> Self {
        return mapImpl { $0.mapRelation(transform) }
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
        return _impl.key
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
        return mapImpl { $0.forKey(key) }
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
        return mapRelation { association._impl.joinedRelation($0, joinOperator: .optional) }
    }
    
    /// Creates an association that includes another one. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func including<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation { association._impl.joinedRelation($0, joinOperator: .required) }
    }
    
    /// Creates an association that joins another one. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func joining<A: Association>(optional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation { association.select([])._impl.joinedRelation($0, joinOperator: .optional) }
    }
    
    /// Creates an association that joins another one. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func joining<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation { association.select([])._impl.joinedRelation($0, joinOperator: .required) }
    }
}

extension Association where OriginRowDecoder: MutablePersistableRecord {
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
    func request(from record: OriginRowDecoder) -> QueryInterfaceRequest<RowDecoder> {
        // Goal: turn `JOIN association ON association.recordId = record.id`
        // into a regular request `SELECT * FROM association WHERE association.recordId = 123`
        
        // We need table aliases to build the joining condition
        let associationAlias = TableAlias()
        let recordAlias = TableAlias()
        
        // Turn the association query into a query interface request:
        // JOIN association -> SELECT FROM association
        return QueryInterfaceRequest(query: SQLSelectQuery(relation: _impl.relation))
            
            // Turn the JOIN condition into a regular WHERE condition
            .filter { db in
                // Build a join condition: `association.recordId = record.id`
                // We still need to replace `record.id` with the actual record id.
                let joinExpression = try self._impl.joinCondition.sqlExpression(db, leftAlias: recordAlias, rightAlias: associationAlias)
                
                // Serialize record: ["id": 123, ...]
                // We do it as late as possible, when request is about to be
                // executed, in order to support long-lived reference types.
                let container = PersistenceContainer(record)
                
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

// MARK: - AssociationImpl

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The protocol for implementation details of associations.
///
/// :nodoc:
public /* TODO: internal */ protocol AssociationImpl {
    /// The association key
    var key: String { get }
    
    /// Creates an association with the given key.
    func forKey(_ key: String) -> Self
    
    /// Returns an association whose relation is transformed by the
    /// given closure.
    ///
    /// This method provides fundamental support for association derivation:
    ///
    ///     // Invokes Book.author.mapRelation { $0.filter(...) }
    ///     Book.author.filter(...)
    func mapRelation(_ transform: (SQLRelation) -> SQLRelation) -> Self
    
    /// Returns a relation joined with self.
    ///
    /// This method provides fundamental support for joining methods.
    func joinedRelation(_ relation: SQLRelation, joinOperator: JoinOperator) -> SQLRelation
    
    // TODO: remove relation & joinCondition properties.
    //
    // They assume that an association is implemented as a direct join to an
    // associated table. This is limiting: has-one-through and has-many-through
    // associations can't be implemented in such context.
    //
    // Their impact is limited yet. Those propertise are currently only used by
    // Association.request(from:). When this method gets a new implementation
    // that does not need a direct join to an associated table, we'll be able to
    // remove those properties.
    var relation: SQLRelation { get }
    var joinCondition: JoinCondition { get }
}

// MARK: -

/// The AssociationImpl shared by BelongsTo, HasOne, and HasMany, which is
/// implemented as a simple join.
///
/// :nodoc:
public /* TODO: internal */ struct JoinAssociationImpl: AssociationImpl {
    public var key: String
    public /* TODO: internal */ let joinCondition: JoinCondition
    public /* TODO: internal */ var relation: SQLRelation
    
    public func forKey(_ key: String) -> JoinAssociationImpl {
        var assoc = self
        assoc.key = key
        return assoc
    }
    
    public func mapRelation(_ transform: (SQLRelation) -> SQLRelation) -> JoinAssociationImpl {
        var assoc = self
        assoc.relation = transform(relation)
        return assoc
    }
    
    public func joinedRelation(_ relation: SQLRelation, joinOperator: JoinOperator) -> SQLRelation {
        let join = SQLJoin(
            joinOperator: joinOperator,
            joinCondition: joinCondition,
            relation: self.relation)
        return relation.appendingJoin(join, forKey: key)
    }
}

