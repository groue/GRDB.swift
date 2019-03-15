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
        return mapRelation { association.sqlAssociation.relation(from: $0, required: false) }
    }
    
    /// Creates an association that includes another one. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func including<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation { association.sqlAssociation.relation(from: $0, required: true) }
    }
    
    /// Creates an association that joins another one. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func joining<A: Association>(optional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation { association.select([]).sqlAssociation.relation(from: $0, required: false) }
    }
    
    /// Creates an association that joins another one. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func joining<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation { association.select([]).sqlAssociation.relation(from: $0, required: true) }
    }
}

// Allow association.filter(key: ...)
extension Association where Self: TableRequest, RowDecoder: TableRecord {
    /// :nodoc:
    public var databaseTableName: String { return RowDecoder.databaseTableName }
}

// MARK: - AssociationToMany

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The base protocol for all associations that define a one-to-many connection.
public protocol AssociationToMany: Association { }

extension AssociationToMany where OriginRowDecoder: TableRecord {
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
    /// For example:
    ///
    ///     Team.annotated(with: Team.players.count())
    public var count: AssociationAggregate<OriginRowDecoder> {
        return makeAggregate(SQLExpressionCountDistinct(Column.rowID)).aliased("\(key)Count")
    }
    
    /// An aggregate that is true if there exists no associated records.
    ///
    /// For example:
    ///
    ///     Team.having(Team.players.isEmpty())
    ///     Team.having(!Team.players.isEmpty())
    ///     Team.having(Team.players.isEmpty() == false)
    public var isEmpty: AssociationAggregate<OriginRowDecoder> {
        return makeAggregate(SQLExpressionIsEmpty(SQLExpressionCountDistinct(Column.rowID)))
    }
    
    /// The average value of the given expression in associated records.
    ///
    /// For example:
    ///
    ///     Team.annotated(with: Team.players.average(Column("score")))
    public func average(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.avg, arguments: expression))
        if let column = expression as? ColumnExpression {
            return aggregate.aliased("average\(key.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// The maximum value of the given expression in associated records.
    ///
    /// For example:
    ///
    ///     Team.annotated(with: Team.players.max(Column("score")))
    public func max(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.max, arguments: expression))
        if let column = expression as? ColumnExpression {
            return aggregate.aliased("max\(key.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// The minimum value of the given expression in associated records.
    ///
    /// For example:
    ///
    ///     Team.annotated(with: Team.players.min(Column("score")))
    public func min(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.min, arguments: expression))
        if let column = expression as? ColumnExpression {
            return aggregate.aliased("min\(key.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// The sum of the given expression in associated records.
    ///
    /// For example:
    ///
    ///     Team.annotated(with: Team.players.min(Column("score")))
    public func sum(_ expression: SQLExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(SQLExpressionFunction(.sum, arguments: expression))
        if let column = expression as? ColumnExpression {
            return aggregate.aliased("\(key)\(column.name.uppercasingFirstCharacter)Sum")
        } else {
            return aggregate
        }
    }
}

// MARK: - AssociationToOne

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// The base protocol for all associations that define a one-to-one connection.
public protocol AssociationToOne: Association { }

// MARK: - SQLAssociation

/// An SQL association is a non-empty chain of joins from an "origin" table to
/// the "head" of the association. All tables between "origin" and "head" are
/// the "tail". The table that is immediately joined to "origin" is the "pivot":
///
///     // SELECT origin.*, head.*
///     // FROM origin
///     // JOIN pivot ON ... JOIN ... -- tail
///     // JOIN head ON ...           -- head
///     origin.including(required: association)
///
/// When tail is empty, "pivot" and "head" are the same:
///
///     // SELECT origin.*, head.* FROM origin JOIN head ON ...
///     origin.including(required: association)
///
/// :nodoc:
public /* TODO: internal */ struct SQLAssociation {
    // SQLAssociation is a non-empty array of association elements
    private struct Element {
        var key: String
        var condition: SQLJoin.Condition
        var relation: SQLRelation
    }
    private var head: Element
    private var tail: [Element]
    private var pivot: Element { return tail.last ?? head }
    var key: String { return head.key }
    
    private init(head: Element, tail: [Element]) {
        self.head = head
        self.tail = tail
    }
    
    init(key: String, condition: SQLJoin.Condition, relation: SQLRelation) {
        head = Element(key: key, condition: condition, relation: relation)
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
    
    /// Support for joining methods joining(optional:), etc.
    func relation(from origin: SQLRelation, required: Bool) -> SQLRelation {
        let headJoin = SQLJoin(
            isRequired: required,
            condition: head.condition,
            relation: head.relation)
        
        // Recursion step: remove one element from tail by shifting the next
        // element to the head.
        //
        // From:
        //  ... JOIN next JOIN head
        //  <-tail------> <-head-->
        //
        // We reduce into:
        //  ...      JOIN next JOIN head
        //  <-tail-> <-head------------>
        //
        // Until the tail is empty:
        guard let next = tail.first else {
            return origin.appendingJoin(headJoin, forKey: head.key)
        }
        
        let nextRelation = next.relation.select([]).appendingJoin(headJoin, forKey: head.key)
        let reducedHead = Element(key: next.key, condition: next.condition, relation: nextRelation)
        let reducedTail = Array(tail.dropFirst())
        let reducedAssociation = SQLAssociation(head: reducedHead, tail: reducedTail)
        return reducedAssociation.relation(from: origin, required: required)
    }
    
    /// Support for (TableRecord & EncodableRecord).request(for:).
    ///
    /// Returns a "reversed" relation:
    ///
    ///     // SELECT head.* FROM head JOIN ... JOIN pivot ON pivot.originId = 123
    ///     origin.request(for: association)
    ///
    /// When tail is empty, "pivot" and "head" are the same:
    ///
    ///     // SELECT head.* FROM head WHERE head.originId = 123
    ///     origin.request(for: association)
    func relation(to originTable: String, container originContainer: @escaping (Database) throws -> PersistenceContainer) -> SQLRelation {
        // Build a "pivot" relation whose filter is the pivot condition
        // injected with values contained in originContainer.
        let pivotCondition = pivot.condition
        let pivotAlias = TableAlias()
        let pivotRelation = pivot.relation
            .qualified(with: pivotAlias)
            .filter { db in
                let originAlias = TableAlias(tableName: originTable)
                
                // Build a join condition: `association.originId = origin.id`
                let joinExpression = try pivotCondition.sqlExpression(db, leftAlias: originAlias, rightAlias: pivotAlias)
                
                // Replace `origin.id` with 123
                return try joinExpression.resolvedExpression(inContext: [originAlias: originContainer(db)])
        }
        
        // We use elements backward: join conditions have to be reversed.
        let reversedElements = zip([head] + tail, tail)
            .map { Element(key: $1.key, condition: $0.condition.reversed, relation: $1.relation.select([])) }
            .reversed()
        
        // Empty tail?
        guard var reversedHead = reversedElements.first else {
            return pivotRelation
        }
        
        reversedHead.relation = pivotRelation.select([])
        let reversedTail = Array(reversedElements.dropFirst())
        let reversedAssociation = SQLAssociation(head: reversedHead, tail: reversedTail)
        return reversedAssociation.relation(from: head.relation, required: true)
    }
}
