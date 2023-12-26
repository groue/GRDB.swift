import Foundation

extension AssociationToMany {
    private func makeAggregate(_ expression: SQLExpression) -> AssociationAggregate<OriginRowDecoder> {
        AssociationAggregate(preparation: BasePreparation(association: self, expression: expression))
    }
    
    /// The number of associated records.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Team: FetchableRecord, TableRecord {
    ///     static let players = Team.hasMany(Player.self)
    /// }
    ///
    /// try dbQueue.read { db in
    ///     // Fetch all teams with at least ten players:
    ///     let teams: [Team] = try Team
    ///         .having(Team.players.count >= 10)
    ///         .fetchAll(db)
    /// }
    /// ```
    ///
    /// The returned association aggregate is named `"[key]Count"`, where `key`
    /// is the association key. For example:
    ///
    /// ```swift
    /// struct TeamInfo: FetchableRecord, Decodable {
    ///     var team: Team
    ///     var playerCount: Int
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let infos: [TeamInfo] = try Team
    ///         .annotated(with: Team.players.count)
    ///         .asRequest(of: TeamInfo.self)
    ///         .fetchAll(db)
    /// }
    /// ```
    public var count: AssociationAggregate<OriginRowDecoder> {
        makeAggregate(.countDistinct(.fastPrimaryKey))
            .forKey("\(key.singularizedName)Count")
    }
    
    /// Returns a boolean aggregate that is true if no associated
    /// records exist.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Team: FetchableRecord, TableRecord {
    ///     static let players = Team.hasMany(Player.self)
    /// }
    ///
    /// try dbQueue.read { db in
    ///     // Fetch all teams without any player
    ///     let teams: [Team] = try Team
    ///         .having(Team.players.isEmpty)
    ///         .fetchAll(db)
    ///
    ///     // Fetch all teams without some player
    ///     let teams: [Team] = try Team
    ///         .having(Team.players.isEmpty == false)
    ///         .fetchAll(db)
    /// }
    /// ```
    ///
    /// The returned association aggregate is named `"hasNo[key]"`, where `key`
    /// is the association key. For example:
    ///
    /// ```swift
    /// struct TeamInfo: FetchableRecord, Decodable {
    ///     var team: Team
    ///     var hasNoPlayer: Int
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let infos: [TeamInfo] = try Team
    ///         .annotated(with: Team.players.isEmpty)
    ///         .asRequest(of: TeamInfo.self)
    ///         .fetchAll(db)
    /// }
    /// ```
    public var isEmpty: AssociationAggregate<OriginRowDecoder> {
        makeAggregate(.isEmpty(.countDistinct(.fastPrimaryKey)))
            .forKey("hasNo\(key.singularizedName.uppercasingFirstCharacter)")
    }
    
    /// Returns the average of the given expression in associated records.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Team: FetchableRecord, TableRecord {
    ///     static let players = Team.hasMany(Player.self)
    /// }
    ///
    /// try dbQueue.read { db in
    ///     // Fetch all teams whose average player score is greater than 1000
    ///     let averageScore = Team.players.average(Column("score"))
    ///     let teams: [Team] = try Team
    ///         .having(averageScore >= 1000)
    ///         .fetchAll(db)
    /// }
    /// ```
    ///
    /// When the input expression is a ``ColumnExpression``, the returned
    /// association aggregate is named `"average[Key][Column]"`, where `key` is
    /// the association key. For example:
    ///
    /// ```swift
    /// struct TeamInfo: FetchableRecord, Decodable {
    ///     var team: Team
    ///     var averagePlayerScore: Double
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let averageScore = Team.players.average(Column("score"))
    ///     let infos: [TeamInfo] = try Team
    ///         .annotated(with: averageScore)
    ///         .asRequest(of: TeamInfo.self)
    ///         .fetchAll(db)
    /// }
    /// ```
    public func average(_ expression: some SQLSpecificExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.function("AVG", [expression.sqlExpression]))
        if let column = expression as? any ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("average\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// Returns the maximum value of the given expression in associated records.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Team: FetchableRecord, TableRecord {
    ///     static let players = Team.hasMany(Player.self)
    /// }
    ///
    /// try dbQueue.read { db in
    ///     // Fetch all teams whose maximum player score is greater than 1000
    ///     let maxScore = Team.players.max(Column("score"))
    ///     let teams: [Team] = try Team
    ///         .having(maxScore >= 1000)
    ///         .fetchAll(db)
    /// }
    /// ```
    ///
    /// When the input expression is a ``ColumnExpression``, the returned
    /// association aggregate is named `"maximum[Key][Column]"`, where `key` is
    /// the association key. For example:
    ///
    /// ```swift
    /// struct TeamInfo: FetchableRecord, Decodable {
    ///     var team: Team
    ///     var maximumPlayerScore: Double
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let maxScore = Team.players.max(Column("score"))
    ///     let infos: [TeamInfo] = try Team
    ///         .annotated(with: maxScore)
    ///         .asRequest(of: TeamInfo.self)
    ///         .fetchAll(db)
    /// }
    /// ```
    public func max(_ expression: some SQLSpecificExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.function("MAX", [expression.sqlExpression]))
        if let column = expression as? any ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("max\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// Returns the minimum value of the given expression in associated records.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Team: FetchableRecord, TableRecord {
    ///     static let players = Team.hasMany(Player.self)
    /// }
    ///
    /// try dbQueue.read { db in
    ///     // Fetch all teams whose minimum player score is less than 1000
    ///     let minScore = Team.players.min(Column("score"))
    ///     let teams: [Team] = try Team
    ///         .having(minScore < 1000)
    ///         .fetchAll(db)
    /// }
    /// ```
    ///
    /// When the input expression is a ``ColumnExpression``, the returned
    /// association aggregate is named `"minimum[Key][Column]"`, where `key` is
    /// the association key. For example:
    ///
    /// ```swift
    /// struct TeamInfo: FetchableRecord, Decodable {
    ///     var team: Team
    ///     var minimumPlayerScore: Double
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let minScore = Team.players.min(Column("score"))
    ///     let infos: [TeamInfo] = try Team
    ///         .annotated(with: minScore)
    ///         .asRequest(of: TeamInfo.self)
    ///         .fetchAll(db)
    /// }
    /// ```
    public func min(_ expression: some SQLSpecificExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.function("MIN", [expression.sqlExpression]))
        if let column = expression as? any ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("min\(name.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// Returns the sum of the given expression in associated records.
    ///
    /// This aggregate invokes the `SUM` SQL function. See also ``total(_:)``
    /// and <https://www.sqlite.org/lang_aggfunc.html#sumunc>.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Team: FetchableRecord, TableRecord {
    ///     static let players = Team.hasMany(Player.self)
    /// }
    ///
    /// try dbQueue.read { db in
    ///     // Fetch all teams whose sum of player scores is greater than 1000
    ///     let scoreSum = Team.players.sum(Column("score"))
    ///     let teams: [Team] = try Team
    ///         .having(scoreSum >= 1000)
    ///         .fetchAll(db)
    /// }
    /// ```
    ///
    /// When the input expression is a ``ColumnExpression``, the returned
    /// association aggregate is named `"[key][Column]Sum"`, where `key` is the
    /// association key. For example:
    ///
    /// ```swift
    /// struct TeamInfo: FetchableRecord, Decodable {
    ///     var team: Team
    ///     var playerScoreSum: Double
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let scoreSum = Team.players.sum(Column("score"))
    ///     let infos: [TeamInfo] = try Team
    ///         .annotated(with: scoreSum)
    ///         .asRequest(of: TeamInfo.self)
    ///         .fetchAll(db)
    /// }
    /// ```
    public func sum(_ expression: some SQLSpecificExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.function("SUM", [expression.sqlExpression]))
        if let column = expression as? any ColumnExpression {
            let name = key.singularizedName
            return aggregate.forKey("\(name)\(column.name.uppercasingFirstCharacter)Sum")
        } else {
            return aggregate
        }
    }
    
    /// Returns the sum of the given expression in associated records.
    ///
    /// This aggregate invokes the `TOTAL` SQL function. See also ``sum(_:)``
    /// and <https://www.sqlite.org/lang_aggfunc.html#sumunc>.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Team: FetchableRecord, TableRecord {
    ///     static let players = Team.hasMany(Player.self)
    /// }
    ///
    /// try dbQueue.read { db in
    ///     // Fetch all teams whose sum of player scores is greater than 1000
    ///     let totalScore = Team.players.total(Column("score"))
    ///     let teams: [Team] = try Team
    ///         .having(totalScore >= 1000)
    ///         .fetchAll(db)
    /// }
    /// ```
    ///
    /// When the input expression is a ``ColumnExpression``, the returned
    /// association aggregate is named `"[key][Column]Sum"`, where `key` is the
    /// association key. For example:
    ///
    /// ```swift
    /// struct TeamInfo: FetchableRecord, Decodable {
    ///     var team: Team
    ///     var playerScoreSum: Double
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let totalScore = Team.players.total(Column("score"))
    ///     let infos: [TeamInfo] = try Team
    ///         .annotated(with: totalScore)
    ///         .asRequest(of: TeamInfo.self)
    ///         .fetchAll(db)
    /// }
    /// ```
    public func total(_ expression: some SQLSpecificExpressible) -> AssociationAggregate<OriginRowDecoder> {
        let aggregate = makeAggregate(.function("TOTAL", [expression.sqlExpression]))
        if let column = expression as? any ColumnExpression {
            let name = key.singularizedName
            // Yes we use the `Sum` suffix instead of `Total`. Both `total(_:)`
            // and `sum(_:)` compute sums.
            return aggregate.forKey("\(name)\(column.name.uppercasingFirstCharacter)Sum")
        } else {
            return aggregate
        }
    }
}

/// A value aggregated from a population of associated records.
///
/// You build an `AssociationAggregate` from an ``AssociationToMany``.
///
/// For example:
///
/// ```swift
/// struct Player: TableRecord { }
/// struct Team: FetchableRecord, TableRecord {
///     static let players = Team.hasMany(Player.self)
/// }
///
/// try dbQueue.read { db in
///     // An association aggregate
///     let playerCount = Team.players.count
///
///     // Fetch all teams with at least ten players:
///     let teams: [Team] = try Team
///         .having(playerCount >= 10)
///         .fetchAll(db)
/// }
/// ```
///
/// ## Topics
///
/// ### Instance Methods
///
/// - ``forKey(_:)-1rvux``
/// - ``forKey(_:)-1ua4j``
///
/// ### Top-Level Functions
///
/// - ``abs(_:)-43n8v``
/// - ``length(_:)-9dr2v``
public struct AssociationAggregate<RowDecoder> {
    fileprivate let preparation: AssociationAggregatePreparation<RowDecoder>
    
    /// The SQL name for the value of this aggregate. See forKey(_:).
    var key: String? = nil
    
    /// Extends the request with the associated records used to compute the
    /// aggregate, and returns the aggregated expression.
    ///
    /// For example:
    ///
    ///     struct Author: TableRecord {
    ///         static let books = hasMany(Book.self)
    ///     }
    ///
    ///     // SELECT * FROM author
    ///     var request = Author.all()
    ///
    ///     let aggregate = Author.books.count
    ///     let expression = aggregate.prepare(&request)
    ///
    ///     // The request has been extended with associated records:
    ///     //
    ///     //  SELECT author.* FROM author
    ///     //  LEFT JOIN book ON book.authorId = author.id
    ///     //  GROUP BY author.id
    ///     request
    ///
    ///     // The aggregated value:
    ///     //
    ///     //  COUNT(DISTINCT book.id)
    ///     expression
    ///
    /// The aggregated expression is not embedded in the extended request:
    ///
    /// - We don't know yet if the aggregated expression will be used in the
    ///   SQL selection, or in the HAVING clause.
    /// - It helps implementing aggregate operators such as `&&`, `+`, etc.
    func prepare(_ request: inout some DerivableRequest<RowDecoder>) -> SQLExpression {
        preparation.prepare(&request)
    }
}

extension AssociationAggregate: Refinable {
    /// Returns an aggregate that is selected in a column with the given name.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord { }
    /// struct Team: FetchableRecord, TableRecord {
    ///     static let players = Team.hasMany(Player.self)
    /// }
    ///
    /// struct TeamInfo: FetchableRecord, Decodable {
    ///     var team: Team
    ///     var numberOfBooks: Int
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let playerCount = Team.players.count.forKey("numberOfBooks")
    ///
    ///     let infos: [TeamInfo] = try Team
    ///         .annotated(with: playerCount)
    ///         .asRequest(of: TeamInfo.self)
    ///         .fetchAll(db)
    /// }
    /// ```
    public func forKey(_ key: String) -> Self {
        with {
            $0.key = key
        }
    }
    
    /// Returns an aggregate that is selected in a column named like the given
    /// coding key.
    ///
    /// See ``forKey(_:)-1rvux``.
    public func forKey(_ key: some CodingKey) -> Self {
        forKey(key.stringValue)
    }
}

// MARK: - AssociationAggregatePreparation

/// An abstract class that only exists as support for
/// `AssociationAggregate.prepare(_:)`, which needs to prepare both query
/// interface requests and associations through their conformance
/// to `DerivableRequest`:
///
///     aggregate.prepare(&request)
///     aggregate.prepare(&association)
///
/// We could have used a generic closure instead of this class... if only Swift
/// would support generic closures.
private class AssociationAggregatePreparation<RowDecoder> {
    func prepare(_ request: inout some DerivableRequest<RowDecoder>) -> SQLExpression {
        fatalError("subclass must override")
    }
}

/// Prepares a request so that it can use association aggregates.
private class BasePreparation<Association: AssociationToMany>:
    AssociationAggregatePreparation<Association.OriginRowDecoder>
{
    private let association: Association
    private let expression: SQLExpression
    
    init(association: Association, expression: SQLExpression) {
        self.association = association
        self.expression = expression
    }
    
    override func prepare(_ request: inout some DerivableRequest<Association.OriginRowDecoder>) -> SQLExpression {
        // The fundamental request that supports association aggregate:
        //
        //     SELECT parent.*
        //     LEFT JOIN child ON child.parentID = parent.id
        //     GROUP BY parent.id
        let tableAlias = TableAlias()
        request = request
            .joining(optional: association.aliased(tableAlias))
            .groupByPrimaryKey()
        
        // The fundamental request can now be annotated, or filtered in the
        // having clause, with the association aggregate expression:
        // MIN(child.score), COUNT(DISTINCT child.id), etc.
        return expression.qualified(with: tableAlias)
    }
}

/// Transforms the expression of an aggregate.
private class MapPreparation<RowDecoder>: AssociationAggregatePreparation<RowDecoder> {
    private let base: AssociationAggregatePreparation<RowDecoder>
    private let transform: (SQLExpression) -> SQLExpression
    
    init(
        base: AssociationAggregatePreparation<RowDecoder>,
        transform: @escaping (SQLExpression) -> SQLExpression)
    {
        self.base = base
        self.transform = transform
    }
    
    override func prepare(_ request: inout some DerivableRequest<RowDecoder>) -> SQLExpression {
        transform(base.prepare(&request))
    }
}

extension AssociationAggregate {
    /// Transforms the expression, and does not preserve key.
    fileprivate func map(_ transform: @escaping (SQLExpression) -> SQLExpression) -> Self {
        AssociationAggregate(preparation: MapPreparation(base: preparation, transform: transform))
    }
}

/// Combines the expressions of two aggregates.
private class CombinePreparation<RowDecoder>: AssociationAggregatePreparation<RowDecoder> {
    private let lhs: AssociationAggregatePreparation<RowDecoder>
    private let rhs: AssociationAggregatePreparation<RowDecoder>
    private let combine: (_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLExpression
    
    init(
        _ lhs: AssociationAggregatePreparation<RowDecoder>,
        _ rhs: AssociationAggregatePreparation<RowDecoder>,
        combine: @escaping (_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLExpression)
    {
        self.lhs = lhs
        self.rhs = rhs
        self.combine = combine
    }
    
    override func prepare(_ request: inout some DerivableRequest<RowDecoder>) -> SQLExpression {
        let lhsExpression = lhs.prepare(&request)
        let rhsExpression = rhs.prepare(&request)
        return combine(lhsExpression, rhsExpression)
    }
}

/// Combines the expression of two aggregates.
private func combine<RowDecoder>(
    _ lhs: AssociationAggregate<RowDecoder>,
    _ rhs: AssociationAggregate<RowDecoder>,
    with combine: @escaping (_ lhs: SQLExpression, _ rhs: SQLExpression) -> SQLExpression)
-> AssociationAggregate<RowDecoder>
{
    AssociationAggregate(preparation: CombinePreparation(lhs.preparation, rhs.preparation, combine: combine))
}

// MARK: - Logical Operators (AND, OR, NOT)

extension AssociationAggregate {
    /// A negated logical aggregate.
    ///
    /// For example:
    ///
    /// ```swift
    /// Author.having(!Author.books.isEmpty)
    /// ```
    public static prefix func ! (aggregate: Self) -> Self {
        aggregate.map { !$0 }
    }
    
    /// The `AND` SQL operator.
    public static func && (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: &&)
    }
    
    // TODO: test
    /// The `AND` SQL operator.
    public static func && (lhs: Self, rhs: some SQLExpressible) -> Self {
        lhs.map { $0 && rhs }
    }
    
    // TODO: test
    /// The `AND` SQL operator.
    public static func && (lhs: some SQLExpressible, rhs: Self) -> Self {
        rhs.map { lhs && $0 }
    }
    
    
    /// The `OR` SQL operator.
    public static func || (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: ||)
    }
    
    // TODO: test
    /// The `OR` SQL operator.
    public static func || (lhs: Self, rhs: some SQLExpressible) -> Self {
        lhs.map { $0 || rhs }
    }
    
    // TODO: test
    /// The `OR` SQL operator.
    public static func || (lhs: some SQLExpressible, rhs: Self) -> Self {
        rhs.map { lhs || $0 }
    }
}

// MARK: - Egality and Identity Operators (=, <>, IS, IS NOT)

extension AssociationAggregate {
    /// The `=` SQL operator.
    public static func == (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: ==)
    }
    
    /// The `=` SQL operator.
    ///
    /// When the right operand is nil, `IS NULL` is used instead of the
    /// `=` operator.
    public static func == (lhs: Self, rhs: (any SQLExpressible)?) -> Self {
        lhs.map { $0 == rhs }
    }
    
    /// The `=` SQL operator.
    ///
    /// When the left operand is nil, `IS NULL` is used instead of the
    /// `=` operator.
    public static func == (lhs: (any SQLExpressible)?, rhs: Self) -> Self {
        rhs.map { lhs == $0 }
    }
    
    /// The `=` SQL operator.
    public static func == (lhs: Self, rhs: Bool) -> Self {
        lhs.map { $0 == rhs }
    }
    
    /// The `=` SQL operator.
    public static func == (lhs: Bool, rhs: Self) -> Self {
        rhs.map { lhs == $0 }
    }
    
    /// The `<>` SQL operator.
    public static func != (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: !=)
    }
    
    /// The `<>` SQL operator.
    ///
    /// When the right operand is nil, `IS NOT NULL` is used instead of the
    /// `<>` operator.
    public static func != (lhs: Self, rhs: (any SQLExpressible)?) -> Self {
        lhs.map { $0 != rhs }
    }
    
    /// The `<>` SQL operator.
    ///
    /// When the left operand is nil, `IS NOT NULL` is used instead of the
    /// `<>` operator.
    public static func != (lhs: (any SQLExpressible)?, rhs: Self) -> Self {
        rhs.map { lhs != $0 }
    }
    
    /// The `<>` SQL operator.
    public static func != (lhs: Self, rhs: Bool) -> Self {
        lhs.map { $0 != rhs }
    }
    
    /// The `<>` SQL operator.
    public static func != (lhs: Bool, rhs: Self) -> Self {
        rhs.map { lhs != $0 }
    }
    
    /// The `IS` SQL operator.
    public static func === (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: ===)
    }
    
    /// The `IS` SQL operator.
    public static func === (lhs: Self, rhs: (any SQLExpressible)?) -> Self {
        lhs.map { $0 === rhs }
    }
    
    /// The `IS` SQL operator.
    public static func === (lhs: (any SQLExpressible)?, rhs: Self) -> Self {
        rhs.map { lhs === $0 }
    }
    
    /// The `IS NOT` SQL operator.
    public static func !== (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: !==)
    }
    
    /// The `IS NOT` SQL operator.
    public static func !== (lhs: Self, rhs: (any SQLExpressible)?) -> Self {
        lhs.map { $0 !== rhs }
    }
    
    /// The `IS NOT` SQL operator.
    public static func !== (lhs: (any SQLExpressible)?, rhs: Self) -> Self {
        rhs.map { lhs !== $0 }
    }
}

// MARK: - Comparison Operators (<, >, <=, >=)

extension AssociationAggregate {
    /// The `<=` SQL operator.
    public static func <= (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: <=)
    }
    
    /// The `<=` SQL operator.
    public static func <= (lhs: Self, rhs: some SQLExpressible) -> Self {
        lhs.map { $0 <= rhs }
    }
    
    /// The `<=` SQL operator.
    public static func <= (lhs: some SQLExpressible, rhs: Self) -> Self {
        rhs.map { lhs <= $0 }
    }
    
    /// The `<` SQL operator.
    public static func < (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: <)
    }
    
    /// The `<` SQL operator.
    public static func < (lhs: Self, rhs: some SQLExpressible) -> Self {
        lhs.map { $0 < rhs }
    }
    
    /// The `<` SQL operator.
    public static func < (lhs: some SQLExpressible, rhs: Self) -> Self {
        rhs.map { lhs < $0 }
    }
    
    /// The `>` SQL operator.
    public static func > (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: >)
    }
    
    /// The `>` SQL operator.
    public static func > (lhs: Self, rhs: some SQLExpressible) -> Self {
        lhs.map { $0 > rhs }
    }
    
    /// The `>` SQL operator.
    public static func > (lhs: some SQLExpressible, rhs: Self) -> Self {
        rhs.map { lhs > $0 }
    }
    
    /// The `>=` SQL operator.
    public static func >= (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: >=)
    }
    
    /// The `>=` SQL operator.
    public static func >= (lhs: Self, rhs: some SQLExpressible) -> Self {
        lhs.map { $0 >= rhs }
    }
    
    /// The `>=` SQL operator.
    public static func >= (lhs: some SQLExpressible, rhs: Self) -> Self {
        rhs.map { lhs >= $0 }
    }
}

// MARK: - Arithmetic Operators (+, -, *, /)

extension AssociationAggregate {
    /// The `-` SQL operator.
    public static prefix func - (aggregate: Self) -> Self {
        aggregate.map { -$0 }
    }
    
    /// The `+` SQL operator.
    public static func + (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: +)
    }
    
    /// The `+` SQL operator.
    public static func + (lhs: Self, rhs: some SQLExpressible) -> Self {
        lhs.map { $0 + rhs }
    }
    
    /// The `+` SQL operator.
    public static func + (lhs: some SQLExpressible, rhs: Self) -> Self {
        rhs.map { lhs + $0 }
    }
    
    /// The `-` SQL operator.
    public static func - (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: -)
    }
    
    /// The `-` SQL operator.
    public static func - (lhs: Self, rhs: some SQLExpressible) -> Self {
        lhs.map { $0 - rhs }
    }
    
    /// The `-` SQL operator.
    public static func - (lhs: some SQLExpressible, rhs: Self) -> Self {
        rhs.map { lhs - $0 }
    }
    
    /// The `*` SQL operator.
    public static func * (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: *)
    }
    
    /// The `*` SQL operator.
    public static func * (lhs: Self, rhs: some SQLExpressible) -> Self {
        lhs.map { $0 * rhs }
    }
    
    /// The `*` SQL operator.
    public static func * (lhs: some SQLExpressible, rhs: Self) -> Self {
        rhs.map { lhs * $0 }
    }
    
    /// The `/` SQL operator.
    public static func / (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, with: /)
    }
    
    /// The `/` SQL operator.
    public static func / (lhs: Self, rhs: some SQLExpressible) -> Self {
        lhs.map { $0 / rhs }
    }
    
    /// The `/` SQL operator.
    public static func / (lhs: some SQLExpressible, rhs: Self) -> Self {
        rhs.map { lhs / $0 }
    }
}

// MARK: - IFNULL(...)

extension AssociationAggregate {
    /// The `IFNULL` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// Team.annotated(with: Team.players.min(Column("score")) ?? 0)
    /// ```
    ///
    /// The returned aggregate has the same key as the input.
    public static func ?? (lhs: Self, rhs: some SQLExpressible) -> Self {
        lhs
            .map { $0 ?? rhs }
            .with { $0.key = lhs.key } // Preserve key
    }
}

// MARK: - ABS(...)

/// The `ABS` SQL function.
public func abs<RowDecoder>(_ aggregate: AssociationAggregate<RowDecoder>)
-> AssociationAggregate<RowDecoder>
{
    aggregate.map(abs)
}

// MARK: - LENGTH(...)

/// The `LENGTH` SQL function.
public func length<RowDecoder>(_ aggregate: AssociationAggregate<RowDecoder>)
-> AssociationAggregate<RowDecoder>
{
    aggregate.map(length)
}
