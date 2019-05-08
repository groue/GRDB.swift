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

extension SQLRelation {
    /// Creates an relation that prefetches another one.
    func including(all sqlAssociation: SQLAssociation) -> SQLRelation {
        return sqlAssociation.extendedRelation(self, kind: .allPrefetched)
    }
    
    /// Creates an relation that includes another one. The columns of the
    /// associated record are selected. The returned relation does not
    /// require that the associated database table contains a matching row.
    func including(optional sqlAssociation: SQLAssociation) -> SQLRelation {
        return sqlAssociation.extendedRelation(self, kind: .oneOptional)
    }
    
    /// Creates an relation that includes another one. The columns of the
    /// associated record are selected. The returned relation requires
    /// that the associated database table contains a matching row.
    func including(required sqlAssociation: SQLAssociation) -> SQLRelation {
        return sqlAssociation.extendedRelation(self, kind: .oneRequired)
    }
    
    /// Creates an relation that joins another one. The columns of the
    /// associated record are not selected. The returned relation does not
    /// require that the associated database table contains a matching row.
    func joining(optional sqlAssociation: SQLAssociation) -> SQLRelation {
        return sqlAssociation.mapRelation { $0.select([]) }.extendedRelation(self, kind: .oneOptional)
    }
    
    /// Creates an relation that joins another one. The columns of the
    /// associated record are not selected. The returned relation requires
    /// that the associated database table contains a matching row.
    func joining(required sqlAssociation: SQLAssociation) -> SQLRelation {
        return sqlAssociation.mapRelation { $0.select([]) }.extendedRelation(self, kind: .oneRequired)
    }
}

extension Association {
    /// Creates an association that prefetches another one.
    public func including<A: AssociationToMany>(all association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation {
            $0.including(all: association.sqlAssociation)
        }
    }
    
    /// Creates an association that includes another one. The columns of the
    /// associated record are selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func including<A: Association>(optional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation {
            $0.including(optional: association.sqlAssociation)
        }
    }
    
    /// Creates an association that includes another one. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func including<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation {
            $0.including(required: association.sqlAssociation)
        }
    }
    
    /// Creates an association that joins another one. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public func joining<A: Association>(optional association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation {
            $0.joining(optional: association.sqlAssociation)
        }
    }
    
    /// Creates an association that joins another one. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public func joining<A: Association>(required association: A) -> Self where A.OriginRowDecoder == RowDecoder {
        return mapRelation {
            $0.joining(required: association.sqlAssociation)
        }
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

/// An SQL association is a non-empty chain on steps which starts from the
/// "pivot" and ends to the "destination":
///
///     // SELECT origin.*, destination.*
///     // FROM origin
///     // JOIN pivot ON ...
///     // JOIN ...
///     // JOIN ...
///     // JOIN destination ON ...
///     Origin.including(required: association)
///
/// For direct associations such as BelongTo or HasMany, the chain contains a
/// single element, the "destination", without intermediate step:
///
///     // "Origin" belongsTo "destination":
///     // SELECT origin.*, destination.*
///     // FROM origin
///     // JOIN destination ON destination.originId = origin.id
///     let association = Origin.belongsTo(Destination.self)
///     Origin.including(required: association)
///
/// Indirect associations such as HasManyThrough have one or several
/// intermediate steps:
///
///     // "Origin" has many "destination" through "pivot":
///     // SELECT origin.*, destination.*
///     // FROM origin
///     // JOIN pivot ON pivot.originId = origin.id
///     // JOIN destination ON destination.id = pivot.destinationId
///     let association = Origin.hasMany(
///         Destination.self,
///         through: Origin.hasMany(Pivot.self),
///         via: Pivot.belongsTo(Destination.self))
///     Origin.including(required: association)
///
///     // "Origin" has many "destination" through "pivot1" and  "pivot2":
///     // SELECT origin.*, destination.*
///     // FROM origin
///     // JOIN pivot1 ON pivot1.originId = origin.id
///     // JOIN pivot2 ON pivot2.pivot1Id = pivot1.id
///     // JOIN destination ON destination.id = pivot.destinationId
///     let association = Origin.hasMany(
///         Destination.self,
///         through: Origin.hasMany(Pivot1.self),
///         via: Pivot1.hasMany(
///             Destination.self,
///             through: Pivot1.hasMany(Pivot2.self),
///             via: Pivot2.belongsTo(Destination.self)))
///     Origin.including(required: association)
///
/// :nodoc:
public /* TODO: internal */ struct SQLAssociation {
    private struct AssociationStep {
        var key: String
        var condition: SQLAssociationCondition
        var relation: SQLRelation
        
        func mapRelation(_ transform: (SQLRelation) -> SQLRelation) -> AssociationStep {
            return AssociationStep(key: key, condition: condition, relation: transform(relation))
        }
    }
    private var steps: [AssociationStep] // Never empty. Last is destination.
    private var destination: AssociationStep {
        get { return steps[steps.count - 1] }
        set { steps[steps.count - 1] = newValue }
    }
    private var pivot: AssociationStep {
        get { return steps[0] }
        set { steps[0] = newValue }
    }
    var key: String { return destination.key }
    var keyPath: [String] { return steps.map { $0.key} }
    var pivotCondition: SQLAssociationCondition {
        return pivot.condition
    }
    
    private init(steps: [AssociationStep]) {
        assert(!steps.isEmpty)
        self.steps = steps
    }
    
    init(key: String, condition: SQLAssociationCondition, relation: SQLRelation) {
        self.init(steps: [AssociationStep(key: key, condition: condition, relation: relation)])
    }
    
    /// Changes the destination key
    func forKey(_ key: String) -> SQLAssociation {
        var result = self
        result.destination.key = key
        return result
    }
    
    /// Changes the pivot key
    func forPivotKey(_ key: String) -> SQLAssociation {
        var result = self
        result.pivot.key = key
        return result
    }

    /// Transforms the destination relation
    func mapRelation(_ transform: (SQLRelation) -> SQLRelation) -> SQLAssociation {
        var result = self
        result.destination = result.destination.mapRelation(transform)
        return result
    }
    
    /// Transforms the pivot relation
    func mapPivotRelation(_ transform: (SQLRelation) -> SQLRelation) -> SQLAssociation {
        var result = self
        result.pivot = result.pivot.mapRelation(transform)
        return result
    }

    /// Returns a new association
    func through(_ other: SQLAssociation) -> SQLAssociation {
        return SQLAssociation(steps: other.steps + steps)
    }
    
    /// Given a relation, returns a relation extended with this association.
    ///
    /// This method provides support for public joining methods such
    /// as `including(required:)`:
    ///
    ///     struct Destination: TableRecord { }
    ///     struct Origin: TableRecord {
    ///         static let destination = belongsTo(Destination.self)
    ///     }
    ///
    ///     // SELECT origin.*, destination.*
    ///     // FROM origin
    ///     // JOIN destination ON destination.id = origin.destinationId
    ///     let request = Origin.including(required: Origin.destination)
    ///
    /// At low-level, this gives:
    ///
    ///     let sqlAssociation = Origin.destination.sqlAssociation
    ///     let origin = Origin.all().query.relation
    ///     let extendedRelation = sqlAssociation.extendedRelation(origin, required: true)
    ///     let query = SQLSelectQuery(relation: extendedRelation)
    ///     let generator = SQLSelectQueryGenerator(query)
    ///     let statement, _ = try generator.prepare(db)
    ///     print(statement.sql)
    ///     // SELECT origin.*, destination.*
    ///     // FROM origin
    ///     // JOIN destination ON destination.originId = origin.id
    ///
    /// This method works for simple direct associations such as BelongsTo or
    /// HasMany in the above examples, but also for indirect associations such
    /// as HasManyThrough, which have any number of pivot relations between the
    /// origin and the destination.
    func extendedRelation(_ origin: SQLRelation, kind: SQLRelation.Child.Kind) -> SQLRelation {
        let destinationChild = SQLRelation.Child(
            kind: kind,
            condition: destination.condition,
            relation: destination.relation)
        
        let initialSteps = steps.dropLast()
        if initialSteps.isEmpty {
            // This is a direct join from origin to destination, without
            // intermediate step.
            //
            // SELECT origin.*, destination.*
            // FROM origin
            // JOIN destination ON destination.id = origin.destinationId
            //
            // let association = Origin.belongsTo(Destination.self)
            // Origin.including(required: association)
            return origin.appendingChild(destinationChild, forKey: destination.key)
        }
        
        // This is an indirect join from origin to destination, through
        // some pivot(s):
        //
        // SELECT origin.*, destination.*
        // FROM origin
        // JOIN pivot ON pivot.originId = origin.id
        // JOIN destination ON destination.id = pivot.destinationId
        //
        // let association = Origin.hasMany(
        //     Destination.self,
        //     through: Origin.hasMany(Pivot.self),
        //     via: Pivot.belongsTo(Destination.self))
        // Origin.including(required: association)
        //
        // Let's recurse toward a direct join, by making a new association which
        // ends on the last pivot, to which we join our destination:
        var reducedAssociation = SQLAssociation(steps: Array(initialSteps))
        reducedAssociation = reducedAssociation.mapRelation {
            $0.appendingChild(destinationChild, forKey: destination.key)
        }
        // Intermediate steps are not prefetched
        reducedAssociation = reducedAssociation.mapRelation {
            $0.select([])
        }
        
        switch kind {
        case .oneRequired, .oneOptional, .allNotPrefetched:
            return reducedAssociation.extendedRelation(origin, kind: kind)
        case .allPrefetched:
            // Intermediate steps of indirect associations are not prefetched.
            //
            // For example, the request below prefetches citizens, not
            // intermediate passports:
            //
            //      extension Country {
            //          static let passports = hasMany(Passport.self)
            //          static let citizens = hasMany(Citizens.self, through: passports, using: Passport.citizen)
            //      }
            //      let request = Country.including(all: Country.citizens)
            //
            // Also, pick a unique pivot key.
            //
            // Why? Consider this request:
            //
            //      let request = Country
            //          .including(all: Country.passports.filter(Column("isExpired") == true))
            //          .including(all: Country.citizens)
            //
            // A unique key makes the citizens' passports distinct from the
            // expired passports. This has two desirable consequences:
            //
            // 1. As expected (since Country.citizens is included from Country),
            //    it attaches prefetched citizens to countries, not
            //    to passports.
            // 2. It loads all citizens, not only citizens who have an expired
            //    passport. This is debatable actually, because unlike
            //    prefetches, joins are merged by keys. Joins require user to
            //    provide explicit disambiguation keys in order to prevent
            //    merging. But this inconsistency really helps our
            //    implementation here. And it's not sure it is very wrong, from
            //    the user's point of view.
            //
            // On the other side, if we would NOT pick a unique pivot key, then
            // our current implementation makes the above request equivalent to
            // the one below, which attaches citizens to passports, not
            // to countries:
            //
            //      let request = Country
            //          .including(all: Country.passports
            //              .filter(Column("isExpired") == true)
            //              .including(all: Passport.citizens))
            //
            // 1. It attaches citizens to passports, not to countries (BUG).
            // 2. When we fetch citizens, we generate an SQL query which does
            //    not contain country columns: we can not dispatch citizens
            //    in countries when we have to (BUG).
            // 3. It fetches citizens who have an expired passport (we have
            //    decided it's a BUG).
            //
            // Conclusion: for better or for worse, let's pick a unique pivot
            // key, and prevent merging of intermediate steps of
            // indirect associations:
            return reducedAssociation
                .forPivotKey("grdb_\(UUID().uuidString)")
                .extendedRelation(origin, kind: .allNotPrefetched)
        }
    }
    
    /// Given an origin alias and rows, returns the destination of the
    /// association as a relation.
    ///
    /// This method provides support for association methods such
    /// as `request(for:)`:
    ///
    ///     struct Destination: TableRecord { }
    ///     struct Origin: TableRecord, EncodableRecord {
    ///         static let destinations = hasMany(Destination.self)
    ///         var destinations: QueryInterface<Destination> {
    ///             return request(for: Origin.destinations)
    ///         }
    ///     }
    ///
    ///     // SELECT destination.*
    ///     // FROM destination
    ///     // WHERE destination.originId = 1
    ///     let origin = Origin(id: 1)
    ///     let destinations = origin.destinations.fetchAll(db)
    ///
    /// At low-level, this gives:
    ///
    ///     let origin = Origin(id: 1)
    ///     let originAlias = TableAlias(tableName: Origin.databaseTableName)
    ///     let sqlAssociation = Origin.destination.sqlAssociation
    ///     let destinationRelation = sqlAssociation.destinationRelation(
    ///         from: originAlias,
    ///         rows: { db in try [Row(PersistenceContainer(db, origin))] })
    ///     let query = SQLSelectQuery(relation: destinationRelation)
    ///     let generator = SQLSelectQueryGenerator(query)
    ///     let statement, _ = try generator.prepare(db)
    ///     print(statement.sql)
    ///     // SELECT destination.*
    ///     // FROM destination
    ///     // WHERE destination.originId = 1
    ///
    /// This method works for simple direct associations such as BelongsTo or
    /// HasMany in the above examples, but also for indirect associations such
    /// as HasManyThrough, which have any number of pivot relations between the
    /// origin and the destination.
    func destinationRelation(fromOriginRows originRows: @escaping (Database) throws -> [Row]) -> SQLRelation {
        // Filter the pivot
        let pivot = self.pivot
        let pivotAlias = TableAlias()
        let filteredPivotRelation = pivot.relation
            .qualified(with: pivotAlias)
            .filter({ db in
                // `pivot.originId = 123` or `pivot.originId IN (1, 2, 3)`
                try pivot.condition.filteringExpression(db, leftRows: originRows(db), rightAlias: pivotAlias)
            })
        
        if steps.count == 1 {
            // This is a direct join from origin to destination, without
            // intermediate step.
            //
            // SELECT destination.*
            // FROM destination
            // WHERE destination.originId = 1
            //
            // let association = Origin.hasMany(Destination.self)
            // Origin(id: 1).request(for: association)
            return filteredPivotRelation
        }
        
        // This is an indirect join from origin to destination, through
        // some intermediate steps:
        //
        // SELECT destination.*
        // FROM destination
        // JOIN pivot ON (pivot.destinationId = destination.id) AND (pivot.originId = 1)
        //
        // let association = Origin.hasMany(
        //     Destination.self,
        //     through: Origin.hasMany(Pivot.self),
        //     via: Pivot.belongsTo(Destination.self))
        // Origin(id: 1).request(for: association)
        let reversedSteps = zip(steps, steps.dropFirst())
            .map { (step, nextStep) -> AssociationStep in
                // Intermediate steps are not included in the selection, and
                // don't have any child.
                let relation = step.relation.select([]).deletingChildren()
                return AssociationStep(
                    key: step.key,
                    condition: nextStep.condition.reversed,
                    relation: relation)
            }
            .reversed()
        
        var reversedAssociation = SQLAssociation(steps: Array(reversedSteps))
        // Replace pivot with the filtered one (not included in the selection,
        // without children).
        reversedAssociation = reversedAssociation.mapRelation { _ in
            filteredPivotRelation.select([]).deletingChildren()
        }
        return reversedAssociation.extendedRelation(destination.relation, kind: .oneRequired)
    }
}
