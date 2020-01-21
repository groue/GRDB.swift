import Foundation

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
    associatedtype OriginRowDecoder: TableRecord
    
    /// :nodoc:
    var sqlAssociation: SQLAssociation { get }
    
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
    func forKey(_ key: String) -> Self
    
    /// :nodoc:
    init(sqlAssociation: SQLAssociation)
}

extension Association {
    /// :nodoc:
    public func _including(all association: SQLAssociation) -> Self {
        return mapDestinationRelation { $0._including(all: association) }
    }
    
    /// :nodoc:
    public func _including(optional association: SQLAssociation) -> Self {
        return mapDestinationRelation { $0._including(optional: association) }
    }
    
    /// :nodoc:
    public func _including(required association: SQLAssociation) -> Self {
        return mapDestinationRelation { $0._including(required: association) }
    }
    
    /// :nodoc:
    public func _joining(optional association: SQLAssociation) -> Self {
        return mapDestinationRelation { $0._joining(optional: association) }
    }
    
    /// :nodoc:
    public func _joining(required association: SQLAssociation) -> Self {
        return mapDestinationRelation { $0._joining(required: association) }
    }
}

extension Association {
    private func mapDestinationRelation(_ transform: (SQLRelation) -> SQLRelation) -> Self {
        return .init(sqlAssociation: sqlAssociation.map(\.destination.relation, transform))
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
    var key: SQLAssociationKey {
        return sqlAssociation.destination.key
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
        return mapDestinationRelation { $0.select(selection) }
    }
    
    /// Creates an association which appends *selection*.
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     // SELECT player.*, team.color, team.name
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId
    ///     let association = Player.team
    ///         .select([Column("color")])
    ///         .annotated(with: [Column("name")])
    ///     var request = Player.including(required: association)
    public func annotated(with selection: [SQLSelectable]) -> Self {
        return mapDestinationRelation { $0.annotated(with: selection) }
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
        return mapDestinationRelation { $0.filter(predicate) }
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
        return mapDestinationRelation { $0.order(orderings) }
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
        return mapDestinationRelation { $0.reversed() }
    }
    
    /// Creates an association without any ordering.
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     // SELECT player.*, team.*
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId
    ///     let association = Player.team.order(Column("name")).unordered()
    ///     var request = Player.including(required: association)
    public func unordered() -> Self {
        return mapDestinationRelation { $0.unordered() }
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
        return mapDestinationRelation { $0.qualified(with: alias) }
    }
}

// TableRequest
extension Association {
    /// :nodoc:
    public var databaseTableName: String { return RowDecoder.databaseTableName }
}

// MARK: - AssociationToOne

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The base protocol for all associations that define a one-to-one connection.
public protocol AssociationToOne: Association { }

extension AssociationToOne {
    public func forKey(_ key: String) -> Self {
        let associationKey = SQLAssociationKey.fixedSingular(key)
        return .init(sqlAssociation: sqlAssociation.forDestinationKey(associationKey))
    }
}

// MARK: - AssociationToMany

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The base protocol for all associations that define a one-to-many connection.
public protocol AssociationToMany: Association { }

extension AssociationToMany {
    public func forKey(_ key: String) -> Self {
        let associationKey = SQLAssociationKey.fixedPlural(key)
        return .init(sqlAssociation: sqlAssociation.forDestinationKey(associationKey))
    }
}

extension AssociationToMany {
    private func makeAggregate(_ expression: SQLExpression) -> AssociationAggregate<OriginRowDecoder> {
        return AssociationAggregate { request in
            let tableAlias = TableAlias()
            let request = request
                .joining(optional: self.aliased(tableAlias))
                .groupByPrimaryKey()
            let expression = tableAlias[expression]
            return (request: request, expression: expression)
        }
    }
    
    /// The number of associated records.
    ///
    /// It has a default name, which is "[key]Count", where key is the key of
    /// the association. For example:
    ///
    /// For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var playerCount: Int
    ///     }
    ///     let request = Team.annotated(with: Team.players.count())
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.count() > 10).fetchAll(db)
    public var count: AssociationAggregate<OriginRowDecoder> {
        return makeAggregate(SQLExpressionCountDistinct(Column.rowID))
            .forKey("\(key.singularizedName)Count")
    }
    
    /// Creates an aggregate that is true if there exists no associated records.
    ///
    /// It has a default name, which is "hasNo[Key]", where key is the key of
    /// the association. For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var hasNoPlayer: Bool
    ///     }
    ///     let request = Team.annotated(with: Team.players.isEmpty())
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.isEmpty()).fetchAll(db)
    ///     let teams: [Team] = try Team.having(!Team.players.isEmpty())
    ///     let teams: [Team] = try Team.having(Team.players.isEmpty() == false)
    public var isEmpty: AssociationAggregate<OriginRowDecoder> {
        return makeAggregate(SQLExpressionIsEmpty(SQLExpressionCountDistinct(Column.rowID)))
            .forKey("hasNo\(key.singularizedName.uppercasingFirstCharacter)")
    }
    
    /// Creates an aggregate which evaluate to the average value of the given
    /// expression in associated records.
    ///
    /// When the averaged expression is a column, the aggregate has a default
    /// name which is "average[Key][Column]", where key is the key of the
    /// association. For example:
    ///
    /// For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var averagePlayerScore: Double
    ///     }
    ///     let request = Team.annotated(with: Team.players.average(Column("score")))
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.average(Column("score")) > 100).fetchAll(db)
    public func average(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.avg, arguments: expression))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("average\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// Creates an aggregate which evaluate to the maximum value of the given
    /// expression in associated records.
    ///
    /// When the maximized expression is a column, the aggregate has a default
    /// name which is "maximum[Key][Column]", where key is the key of the
    /// association. For example:
    ///
    /// For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var maxPlayerScore: Double
    ///     }
    ///     let request = Team.annotated(with: Team.players.max(Column("score")))
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.max(Column("score")) < 100).fetchAll(db)
    public func max(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.max, arguments: expression))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("max\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// Creates an aggregate which evaluate to the minimum value of the given
    /// expression in associated records.
    ///
    /// When the minimized expression is a column, the aggregate has a default
    /// name which is "minimum[Key][Column]", where key is the key of the
    /// association. For example:
    ///
    /// For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var minPlayerScore: Double
    ///     }
    ///     let request = Team.annotated(with: Team.players.min(Column("score")))
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.min(Column("score")) > 100).fetchAll(db)
    public func min(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.min, arguments: expression))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("min\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// Creates an aggregate which evaluate to the sum of the given expression
    /// in associated records.
    ///
    /// When the summed expression is a column, the aggregate has a default
    /// name which is "[key][Column]Sum", where key is the key of the
    /// association. For example:
    ///
    /// For example:
    ///
    ///     struct TeamInfo: FetchableRecord, Decodable {
    ///         var team: Team
    ///         var playerScoreSum: Double
    ///     }
    ///     let request = Team.annotated(with: Team.players.sum(Column("score")))
    ///     let infos: [TeamInfo] = try TeamInfo.fetchAll(db, request)
    ///
    ///     let teams: [Team] = try Team.having(Team.players.sum(Column("score")) > 100).fetchAll(db)
    public func sum(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.sum, arguments: expression))
        if let column = expression as? ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("\(name)\(column.name.uppercasingFirstCharacter)Sum")
        } else {
            return aggregate
        }
    }
}
