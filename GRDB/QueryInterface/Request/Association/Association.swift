import Foundation

/// Implementation details of `Association`.
///
/// :nodoc:
public protocol _Association {
    var _sqlAssociation: _SQLAssociation { get set }
}

/// The base protocol for all associations that define a connection between two
/// record types.
public protocol Association: _Association, DerivableRequest {
    // OriginRowDecoder and RowDecoder inherited from DerivableRequest provide
    // type safety:
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
}

extension Association {
    /// Returns self modified with the *update* function.
    func with(_ update: (inout Self) throws -> Void) rethrows -> Self {
        var result = self
        try update(&result)
        return result
    }
    
    /// Returns self with destination relation modified with the *update* function.
    fileprivate func withDestinationRelation(_ update: (inout SQLRelation) throws -> Void) rethrows -> Self {
        var result = self
        try update(&result._sqlAssociation.destination.relation)
        return result
    }
}

extension Association {
    /// :nodoc:
    public func _including(all association: _SQLAssociation) -> Self {
        withDestinationRelation { relation in
            relation = relation._including(all: association)
        }
    }
    
    /// :nodoc:
    public func _including(optional association: _SQLAssociation) -> Self {
        withDestinationRelation { relation in
            relation = relation._including(optional: association)
        }
    }
    
    /// :nodoc:
    public func _including(required association: _SQLAssociation) -> Self {
        withDestinationRelation { relation in
            relation = relation._including(required: association)
        }
    }
    
    /// :nodoc:
    public func _joining(optional association: _SQLAssociation) -> Self {
        withDestinationRelation { relation in
            relation = relation._joining(optional: association)
        }
    }
    
    /// :nodoc:
    public func _joining(required association: _SQLAssociation) -> Self {
        withDestinationRelation { relation in
            relation = relation._joining(required: association)
        }
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
    var key: SQLAssociationKey { _sqlAssociation.destination.key }
    
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
        forKey(codingKey.stringValue)
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
        withDestinationRelation { relation in
            relation = relation.aliased(alias)
        }
    }
}

// SelectionRequest conformance
extension Association {
    
    /// Creates an association which selects *selection*.
    ///
    ///     struct Player: TableRecord {
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///
    ///     // SELECT player.*, team.color
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId
    ///     let association = Player.team.select { db in [Column("color")]
    ///     var request = Player.including(required: association)
    ///
    /// Any previous selection is replaced:
    ///
    ///     // SELECT player.*, team.color
    ///     // FROM player
    ///     // JOIN team ON team.id = player.teamId
    ///     let association = Player.team
    ///         .select { db in [Column("id")] }
    ///         .select { db in [Column("color") }
    ///     var request = Player.including(required: association)
    public func select(_ selection: @escaping (Database) throws -> [SQLSelectable]) -> Self {
        withDestinationRelation { relation in
            relation = relation.select { db in
                try selection(db).map(\.sqlSelection)
            }
        }
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
    ///         .annotated(with: { db in [Column("name")] })
    ///     var request = Player.including(required: association)
    public func annotated(with selection: @escaping (Database) throws -> [SQLSelectable]) -> Self {
        withDestinationRelation { relation in
            relation = relation.annotated { db in
                try selection(db).map(\.sqlSelection)
            }
        }
    }
}

// FilteredRequest conformance
extension Association {
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
        withDestinationRelation { relation in
            relation = relation.filter { db in
                try predicate(db).sqlExpression
            }
        }
    }
}

// OrderedRequest conformance
extension Association {
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
        withDestinationRelation { relation in
            relation = relation.order { db in
                try orderings(db).map(\.sqlOrdering)
            }
        }
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
        withDestinationRelation { relation in
            relation = relation.reversed()
        }
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
        withDestinationRelation { relation in
            relation = relation.unordered()
        }
    }
}

// TableRequest conformance
extension Association {
    public var databaseTableName: String {
        _sqlAssociation.destination.relation.source.tableName
    }
}

// AggregatingRequest conformance
extension Association {
    /// Creates an association grouped according to *expressions promise*.
    public func group(_ expressions: @escaping (Database) throws -> [SQLExpressible]) -> Self {
        withDestinationRelation { relation in
            relation = relation.group { db in
                try expressions(db).map(\.sqlExpression)
            }
        }
    }
    
    /// Creates an association with the provided *predicate promise* added to
    /// the eventual set of already applied predicates.
    public func having(_ predicate: @escaping (Database) throws -> SQLExpressible) -> Self {
        withDestinationRelation { relation in
            relation = relation.having { db in
                try predicate(db).sqlExpression
            }
        }
    }
}

// DerivableRequest conformance
extension Association {
    /// Creates an association for returns distinct rows.
    public func distinct() -> Self {
        withDestinationRelation { relation in
            relation.isDistinct = true
        }
    }
    
    /// Creates an association that fetches *limit* rows, starting at *offset*.
    ///
    /// Any previous limit is replaced.
    ///
    /// - warning: Avoid this method: it is unlikely it does what you expect it
    ///   to do. It will be removed in a future GRDB version.
    ///
    /// :nodoc:
    public func limit(_ limit: Int, offset: Int? = nil) -> Self {
        withDestinationRelation { relation in
            relation.limit = SQLLimit(limit: limit, offset: offset)
        }
    }
    
    /// Returns an association that embeds the common table expression.
    ///
    /// See `QueryInterfaceRequest.with(_:)` for more information.
    public func with<RowDecoder>(_ cte: CommonTableExpression<RowDecoder>) -> Self {
        withDestinationRelation { relation in
            relation.ctes[cte.tableName] = cte.cte
        }
    }
}

// MARK: - AssociationToOne

/// The base protocol for all associations that define a one-to-one connection.
public protocol AssociationToOne: Association { }

extension AssociationToOne {
    public func forKey(_ key: String) -> Self {
        let associationKey = SQLAssociationKey.fixedSingular(key)
        return with {
            $0._sqlAssociation = $0._sqlAssociation.forDestinationKey(associationKey)
        }
    }
}

// MARK: - AssociationToMany

/// The base protocol for all associations that define a one-to-many connection.
public protocol AssociationToMany: Association { }

extension AssociationToMany {
    public func forKey(_ key: String) -> Self {
        let associationKey = SQLAssociationKey.fixedPlural(key)
        return with {
            $0._sqlAssociation = $0._sqlAssociation.forDestinationKey(associationKey)
        }
    }
}
