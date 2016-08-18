// MARK: - SQLJoinable

/// TODO: documentation
public protocol _SQLJoinable {
    /// TODO: documentation
    var joinDefinition: SQLJoinDefinition { get }
}

/// TODO: documentation
public protocol SQLJoinable : _SQLJoinable {
}

extension SQLJoinable {
    
    /// TODO: documentation
    @warn_unused_result
    func include(required required: Bool, _ joinables: [SQLJoinable]) -> SQLJoinDefinition {
        var join = joinDefinition
        join.rightJoins.appendContentsOf(joinables.map {
            var join = $0.joinDefinition
            join.joinKind = required ? .Inner : .Left
            return join
            })
        return join
    }
    
    /// TODO: documentation
    @warn_unused_result
    func join(required required: Bool, _ joinables: [SQLJoinable]) -> SQLJoinDefinition {
        var join = joinDefinition
        join.rightJoins.appendContentsOf(joinables.map {
            var join = $0.joinDefinition
            join.joinKind = required ? .Inner : .Left
            join.selection = { _ in [] }
            return join
            })
        return join
    }
}

extension SQLJoinable {
    
    /// TODO: documentation
    @warn_unused_result
    public func include(joinables: SQLJoinable...) -> SQLJoinDefinition {
        return include(required: false, joinables)
    }
    
    /// TODO: documentation
    @warn_unused_result
    public func include(required joinables: SQLJoinable...) -> SQLJoinDefinition {
        return include(required: true, joinables)
    }
    
    /// TODO: documentation
    @warn_unused_result
    public func include(joinables: [SQLJoinable]) -> SQLJoinDefinition {
        return include(required: false, joinables)
    }
    
    /// TODO: documentation
    @warn_unused_result
    public func include(required joinables: [SQLJoinable]) -> SQLJoinDefinition {
        return include(required: true, joinables)
    }
    
    /// TODO: documentation
    @warn_unused_result
    public func join(joinables: SQLJoinable...) -> SQLJoinDefinition {
        return join(required: false, joinables)
    }
    
    /// TODO: documentation
    @warn_unused_result
    public func join(required joinables: SQLJoinable...) -> SQLJoinDefinition {
        return join(required: true, joinables)
    }
    
    /// TODO: documentation
    @warn_unused_result
    public func join(joinables: [SQLJoinable]) -> SQLJoinDefinition {
        return join(required: false, joinables)
    }
    
    /// TODO: documentation
    @warn_unused_result
    public func join(required joinables: [SQLJoinable]) -> SQLJoinDefinition {
        return join(required: true, joinables)
    }
    
    /// TODO: documentation
    @warn_unused_result
    public func aliased(alias: String) -> SQLJoinDefinition {
        var join = joinDefinition
        join.alias = alias
        return join
    }
    
    /// TODO: documentation
    @warn_unused_result
    public func filter(sql sql: String, arguments: StatementArguments? = nil) -> SQLJoinDefinition {
        fatalError("Not implemented")
    }
}


// MARK: - SQLJoinDefinition

/// TODO: documentation
public struct SQLJoinDefinition {
    let scope: Scope
    var joinKind: SQLJoinKind
    var selection: (Database, SQLSource) throws -> [SQLSelectable]
    let tableName: String
    var alias: String?
    var joinPredicate: (db: Database, left: SQLSource, right: SQLSource) throws -> _SQLExpression
    var rightJoins: [SQLJoinDefinition]
    
    func makeJoin(db: Database, leftSource: SQLSource) throws -> SQLJoin {
        let source = SQLTableSource(tableName: tableName, alias: alias)
        return try SQLJoin(
            scope: scope,
            joinKind: joinKind,
            selection: selection(db, source),
            source: source,
            joinPredicate: joinPredicate(db: db, left: leftSource, right: source),
            rightJoins: rightJoins.map { try $0.makeJoin(db, leftSource: source) })
    }
}

extension SQLJoinDefinition : SQLJoinable {
    /// TODO: documentation
    public var joinDefinition: SQLJoinDefinition { return self }
}

enum SQLJoinKind : String {
    case Inner = "JOIN"
    case Left = "LEFT JOIN"
    case Cross = "CROSS JOIN"
}


// MARK: - Relation

/// TODO: documentation
public struct Relation {
    /// TODO: documentation
    public let tableName: String
    /// TODO: documentation
    public var alias: String?
    
    let scope = Scope()
    var selection: (Database, SQLSource) throws -> [SQLSelectable] = { (db, source) in [_SQLSelectionElement.Star(source: source)] }
    var joinPredicate: ((db: Database, left: SQLSource, right: SQLSource) throws -> _SQLExpression)
    
    /// TODO: documentation
    public init(to tableName: String, columns rightColumns: [String]) {
        self.init(to: tableName, foreignKey: { (db, left, right) in
            guard let pk = try left.primaryKey(db) else {
                fatalError("can't join from \(left.name): it has no primary key")
            }
            return (leftColumns: pk.columns, rightColumns: rightColumns)
        })
    }
    
    /// TODO: documentation
    public init(to tableName: String, columns rightColumns: [SQLColumn]) {
        self.init(to: tableName, columns: rightColumns.map { $0.name })
    }
    
    /// TODO: documentation
    public init(to tableName: String, fromColumns leftColumns: [String]) {
        self.init(to: tableName, foreignKey: { (db, left, right) in
            guard let pk = try db.primaryKey(tableName) else {
                fatalError("can't join on \(tableName): it has no primary key")
            }
            return (leftColumns: leftColumns, rightColumns: pk.columns)
        })
    }
    
    /// TODO: documentation
    public init(to tableName: String, fromColumns leftColumns: [SQLColumn]) {
        self.init(to: tableName, fromColumns: leftColumns.map { $0.name })
    }
    
    /// TODO: documentation
    public init(to tableName: String, columns rightColumns: [String], fromColumns leftColumns: [String]) {
        self.init(to: tableName, foreignKey: { (db, left, right) in
            return (leftColumns: leftColumns, rightColumns: rightColumns)
        })
    }
    
    /// TODO: documentation
    public init(to tableName: String, columns rightColumns: [SQLColumn], fromColumns leftColumns: [SQLColumn]) {
        self.init(to: tableName, columns: rightColumns.map { $0.name }, fromColumns: leftColumns.map { $0.name })
    }
    
    /// TODO: documentation
    public init(to tableName: String, on predicate: (leftSource: SQLSource, rightSource: SQLSource) -> SQLExpressible) {
        self.tableName = tableName
        self.joinPredicate = { (db, left, right) in predicate(leftSource: left, rightSource: right).sqlExpression }
    }
    
    /// TODO: documentation
    init(to tableName: String, foreignKey: (db: Database, leftSource: SQLSource, rightSource: SQLSource) throws -> (leftColumns: [String], rightColumns: [String])) {
        self.tableName = tableName
        joinPredicate = { (db, left, right) in
            let (leftColumns, rightColumns) = try foreignKey(db:db, leftSource: left, rightSource: right)
            GRDBPrecondition(rightColumns.count == leftColumns.count, "left and right column counts don't match")
            GRDBPrecondition(!rightColumns.isEmpty, "invalid empty foreign key")
            return zip(leftColumns, rightColumns).map { (leftColumn, rightColumn) in right[rightColumn] == left[leftColumn] }.reduce(&&)!
        }
    }
}

extension Relation {
    // MARK: - Private Relation Derivation
    
    func select(selection: (Database, SQLSource) throws -> [SQLSelectable]) -> Relation {
        var relation = self
        relation.selection = selection
        return relation
    }
}

extension Relation {
    // MARK: - Relation Derivation
    
    /// TODO: documentation
    public func aliased(alias: String) -> Relation {
        var relation = self
        relation.alias = alias
        return relation
    }
    
    /// TODO: documentation
    public func select(selection: (SQLSource) -> SQLSelectable) -> Relation {
        return select { [selection($0)] }
    }
    
    /// TODO: documentation
    public func select(selection: (SQLSource) -> [SQLSelectable]) -> Relation {
        return select { (db, source) in selection(source) }
    }
    
    /// TODO: documentation
    public func on(predicate: (SQLSource) -> SQLExpressible) -> Relation {
        var relation = self
        let existingPredicate = relation.joinPredicate
        relation.joinPredicate = { (db, left, right) in
            try existingPredicate(db: db, left: left, right: right) && predicate(right).sqlExpression
        }
        return relation
    }

    /// TODO: documentation
    public func on(sql sql: String, arguments: StatementArguments? = nil) -> Relation {
        return on { _ in _SQLExpression.Literal("(\(sql))", arguments) }
    }
}

extension Relation : SQLJoinable {
    /// TODO: documentation
    public var joinDefinition: SQLJoinDefinition {
        return SQLJoinDefinition(
            scope: scope,
            joinKind: .Left,
            selection: selection,
            tableName: tableName,
            alias: alias,
            joinPredicate: joinPredicate,
            rightJoins: [])
    }
}


// MARK: - Annotation

/// TODO: documentation
public struct Annotation {
    let relation: Relation
    let alias: String
    let expression: (Database, SQLSource) throws -> _SQLExpression
}

extension Annotation {
    public func aliased(alias: String) -> Annotation {
        return Annotation(relation: relation, alias: alias, expression: expression)
    }
}

/// TODO: documentation
public func count(relation: Relation) -> Annotation {
    return Annotation(relation: relation, alias: "\(relation.tableName)Count", expression: { (db, source) in
        guard let primaryKey = try source.primaryKey(db),
            let pkColumn = primaryKey.columns.first
            where primaryKey.columns.count == 1 else {
                // TODO: not all tables have a rowid
                return count(source["_rowid_"])
        }
        return count(source[pkColumn])
    })
}

/// TODO: documentation
public func count(distinct relation: Relation) -> Annotation {
    return Annotation(relation: relation, alias: "\(relation.tableName)Count", expression: { (db, source) in
        guard let primaryKey = try source.primaryKey(db),
            let pkColumn = primaryKey.columns.first
            where primaryKey.columns.count == 1 else {
                // TODO: not all tables have a rowid
                return count(distinct: source["_rowid_"])
        }
        return count(distinct: source[pkColumn])
    })
}


// MARK: - SQLJoinSourceDefinition

struct SQLJoinSourceDefinition : SQLSourceDefinition {
    let leftSource: SQLSourceDefinition
    let rightJoins: [SQLJoinDefinition]
    
    init(leftSource: SQLSourceDefinition, rightJoins: [SQLJoinDefinition]) {
        self.leftSource = leftSource
        self.rightJoins = rightJoins
    }
    
    func makeSource(db: Database) throws -> SQLSource {
        let leftSource = try self.leftSource.makeSource(db)
        let rightJoins = try self.rightJoins.map { try $0.makeJoin(db, leftSource: leftSource) }
        return SQLJoinSource(leftSource: leftSource, rightJoins: rightJoins)
    }
    
    func joining(join: SQLJoinable) -> SQLSourceDefinition {
        return SQLJoinSourceDefinition(leftSource: leftSource, rightJoins: rightJoins + [join.joinDefinition])
    }
}

