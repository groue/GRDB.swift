/// A QueryInterfaceRequest describes an SQL query.
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct QueryInterfaceRequest<T> {
    let query: SQLSelectQueryDefinition
    
    /// Initializes a QueryInterfaceRequest based on table *tableName*.
    ///
    /// It represents the SQL query `SELECT * FROM tableName`.
    public init(tableName: String) {
        let source = SQLTableSource(tableName: tableName, alias: nil)
        self.init(query: SQLSelectQueryDefinition(select: { _ in [_SQLSelectionElement.Star(source: source)] }, from: source))
    }
    
    init(query: SQLSelectQueryDefinition) {
        self.query = query
    }
}


extension QueryInterfaceRequest : FetchRequest {
    
    /// Returns a prepared statement that is ready to be executed.
    ///
    /// - throws: A DatabaseError whenever SQLite could not parse the sql query.
    @warn_unused_result
    public func prepare(db: Database) throws -> (SelectStatement, RowAdapter?) {
        return try query.makeSelectQuery(db).prepare(db)
    }
}


extension QueryInterfaceRequest where T: RowConvertible {
    
    // MARK: Fetching Record and RowConvertible
    
    /// Returns a sequence of values.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.order(nameColumn)
    ///     let persons = request.fetch(db) // DatabaseSequence<Person>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let persons = request.fetch(db)
    ///     Array(persons).count // 3
    ///     db.execute("DELETE ...")
    ///     Array(persons).count // 2
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    @warn_unused_result
    public func fetch(db: Database) -> DatabaseSequence<T> {
        return T.fetch(db, self)
    }
    
    /// Returns an array of values fetched from a fetch request.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.order(nameColumn)
    ///     let persons = request.fetchAll(db) // [Person]
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public func fetchAll(db: Database) -> [T] {
        return T.fetchAll(db, self)
    }
    
    /// Returns a single value fetched from a fetch request.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.order(nameColumn)
    ///     let person = request.fetchOne(db) // Person?
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public func fetchOne(db: Database) -> T? {
        return T.fetchOne(db, self)
    }
}

extension QueryInterfaceRequest {
    
    // MARK: Private Request Derivation
    
    /// Returns a new QueryInterfaceRequest grouped according to *expressions*.
    /// TODO: document closure
    @warn_unused_result
    func group(expressions: (Database, SQLSource?) throws -> [SQLExpressible]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.groupByExpressions = { (db, source) in try expressions(db, source).map { $0.sqlExpression } }
        return QueryInterfaceRequest(query: query)
    }
    
}

extension QueryInterfaceRequest {
    
    // MARK: Request Derivation
    
    /// Returns a QueryInterfaceRequest which selects *selection*.
    /// TODO: document the closure
    @warn_unused_result
    public func select(selection: (SQLSource) -> SQLSelectable) -> QueryInterfaceRequest<T> {
        return select { source in [selection(source)] }
    }
    
    /// Returns a QueryInterfaceRequest which selects *selection*.
    /// TODO: document the closure
    @warn_unused_result
    public func select(selection: (SQLSource) -> [SQLSelectable]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.mainSelection = { (db, source) in selection(source!) }
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with a new net of selected columns.
    @warn_unused_result
    public func select(selection: SQLSelectable...) -> QueryInterfaceRequest<T> {
        return select(selection)
    }
    
    /// Returns a new QueryInterfaceRequest with a new net of selected columns.
    @warn_unused_result
    public func select(selection: [SQLSelectable]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.mainSelection = { _ in selection }
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with a new net of selected columns.
    @warn_unused_result
    public func select(sql sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return select(_SQLExpression.Literal(sql, arguments))
    }
    
    /// Returns a new QueryInterfaceRequest which returns distinct rows.
    public var distinct: QueryInterfaceRequest<T> {
        var query = self.query
        query.distinct = true
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    /// TODO: document the closure
    @warn_unused_result
    public func filter(predicate: (SQLSource) -> SQLExpressible) -> QueryInterfaceRequest<T> {
        var query = self.query
        if let existingPredicate = query.wherePredicate {
            query.wherePredicate = { (db, source) in
                try existingPredicate(db, source).sqlExpression && predicate(source!).sqlExpression
            }
        } else {
            query.wherePredicate = { (db, source) in predicate(source!).sqlExpression }
        }
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    @warn_unused_result
    public func filter(predicate: SQLExpressible) -> QueryInterfaceRequest<T> {
        var query = self.query
        if let existingPredicate = query.wherePredicate {
            query.wherePredicate = { (db, source) in
                try existingPredicate(db, source).sqlExpression && predicate.sqlExpression
            }
        } else {
            query.wherePredicate = { (db, source) in predicate.sqlExpression }
        }
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    @warn_unused_result
    public func filter(sql sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return filter(_SQLExpression.Literal("(\(sql))", arguments))
    }
    
    /// Returns a new QueryInterfaceRequest grouped according to *expressions*.
    /// TODO: document closure
    @warn_unused_result
    public func group(expression: (SQLSource) -> SQLExpressible) -> QueryInterfaceRequest<T> {
        return group { source in [expression(source)] }
    }
    
    /// Returns a new QueryInterfaceRequest grouped according to *expressions*.
    /// TODO: document closure
    @warn_unused_result
    public func group(expressions: (SQLSource) -> [SQLExpressible]) -> QueryInterfaceRequest<T> {
        return group { (db, source) in expressions(source!).map { $0.sqlExpression } }
    }
    
    /// Returns a new QueryInterfaceRequest grouped according to *expressions*.
    @warn_unused_result
    public func group(expressions: SQLExpressible...) -> QueryInterfaceRequest<T> {
        return group(expressions)
    }
    
    /// Returns a new QueryInterfaceRequest grouped according to *expressions*.
    @warn_unused_result
    public func group(expressions: [SQLExpressible]) -> QueryInterfaceRequest<T> {
        return group { (db, source) in expressions.map { $0.sqlExpression } }
    }
    
    /// Returns a new QueryInterfaceRequest with a new grouping.
    @warn_unused_result
    public func group(sql sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return group(_SQLExpression.Literal(sql, arguments))
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    /// TODO: document closure
    @warn_unused_result
    public func having(predicate: (SQLSource) -> SQLExpressible) -> QueryInterfaceRequest<T> {
        var query = self.query
        if let existingPredicate = query.havingPredicate {
            query.havingPredicate = { (db, source) in
                try existingPredicate(db, source).sqlExpression && predicate(source!).sqlExpression
            }
        } else {
            query.havingPredicate = { (db, source) in predicate(source!).sqlExpression }
        }
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *predicate* added to the
    /// eventual set of already applied predicates.
    @warn_unused_result
    public func having(predicate: SQLExpressible) -> QueryInterfaceRequest<T> {
        var query = self.query
        if let existingPredicate = query.havingPredicate {
            query.havingPredicate = { (db, source) in
                try existingPredicate(db, source).sqlExpression && predicate.sqlExpression
            }
        } else {
            query.havingPredicate = { (db, source) in predicate.sqlExpression }
        }
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *sql* added to
    /// the eventual set of already applied predicates.
    @warn_unused_result
    public func having(sql sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return having(_SQLExpression.Literal(sql, arguments))
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *orderings* added to
    /// the eventual set of already applied orderings.
    /// TODO: document closure
    @warn_unused_result
    public func order(ordering: (SQLSource) -> _SQLOrdering) -> QueryInterfaceRequest<T> {
        return order { source in [ordering(source)] }
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *orderings* added to
    /// the eventual set of already applied orderings.
    /// TODO: document closure
    @warn_unused_result
    public func order(orderings: (SQLSource) -> [_SQLOrdering]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.orderings = { (db, source) in orderings(source!) }
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *orderings* added to
    /// the eventual set of already applied orderings.
    @warn_unused_result
    public func order(orderings: _SQLOrdering...) -> QueryInterfaceRequest<T> {
        return order(orderings)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *orderings* added to
    /// the eventual set of already applied orderings.
    @warn_unused_result
    public func order(orderings: [_SQLOrdering]) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.orderings = { _ in orderings }
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a new QueryInterfaceRequest with the provided *sql* added to the
    /// eventual set of already applied orderings.
    @warn_unused_result
    public func order(sql sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<T> {
        return order([_SQLExpression.Literal(sql, arguments)])
    }
    
    /// Returns a new QueryInterfaceRequest sorted in reversed order.
    @warn_unused_result
    public func reverse() -> QueryInterfaceRequest<T> {
        var query = self.query
        query.reversed = !query.reversed
        return QueryInterfaceRequest(query: query)
    }
    
    /// Returns a QueryInterfaceRequest which fetches *limit* rows, starting at
    /// *offset*.
    @warn_unused_result
    public func limit(limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<T> {
        var query = self.query
        query.limit = SQLLimit(limit: limit, offset: offset)
        return QueryInterfaceRequest(query: query)
    }
}


extension QueryInterfaceRequest {
    
    // MARK: Counting
    
    /// Returns the number of rows matched by the request.
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public func fetchCount(db: Database) -> Int {
        return try! Int.fetchOne(db, query.makeSelectQuery(db).countQuery)!
    }
}

extension QueryInterfaceRequest {
    
    /// TODO: test that request.include([assoc1, assoc2]) <=> request.include([assoc1]).include([assoc2])
    @warn_unused_result
    func include(required required: Bool, _ joinables: [SQLJoinable]) -> QueryInterfaceRequest<T> {
        var query = self.query
        guard let querySource = query.source else {
            fatalError("Can't join")
        }
        var source = querySource
        for joinable in joinables {
            var join = joinable.joinDefinition
            join.joinKind = required ? .Inner : .Left
            source = source.joining(join)
        }
        query.source = source
        return QueryInterfaceRequest(query: query)
    }
    
    /// TODO: test that request.join([assoc1, assoc2]) <=> request.join([assoc1]).join([assoc2])
    @warn_unused_result
    func join(required required: Bool, _ joinables: [SQLJoinable]) -> QueryInterfaceRequest<T> {
        var query = self.query
        guard let querySource = query.source else {
            fatalError("Can't join")
        }
        var source = querySource
        for joinable in joinables {
            var join = joinable.joinDefinition
            join.joinKind = required ? .Inner : .Left
            join.selection = { _ in [] }
            source = source.joining(join)
        }
        query.source = source
        return QueryInterfaceRequest(query: query)
    }
}


extension QueryInterfaceRequest {
    
    // MARK: Joins
    
    /// TODO: doc
    @warn_unused_result
    public func include(joinables: SQLJoinable...) -> QueryInterfaceRequest<T> {
        return include(required: false, joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public func include(required joinables: SQLJoinable...) -> QueryInterfaceRequest<T> {
        return include(required: true, joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public func include(joinables: [SQLJoinable]) -> QueryInterfaceRequest<T> {
        return include(required: false, joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public func include(required joinables: [SQLJoinable]) -> QueryInterfaceRequest<T> {
        return include(required: true, joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public func join(joinables: SQLJoinable...) -> QueryInterfaceRequest<T> {
        return join(required: false, joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public func join(required joinables: SQLJoinable...) -> QueryInterfaceRequest<T> {
        return join(required: true, joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public func join(joinables: [SQLJoinable]) -> QueryInterfaceRequest<T> {
        return join(required: false, joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public func join(required joinables: [SQLJoinable]) -> QueryInterfaceRequest<T> {
        return join(required: true, joinables)
    }
}


extension QueryInterfaceRequest {
    
    // MARK: Annotations
    
    /// TODO: documentation
    @warn_unused_result
    public func annotate(annotations: Annotation...) -> QueryInterfaceRequest<T> {
        return annotate(annotations)
    }
    
    /// TODO: documentation
    @warn_unused_result
    public func annotate(annotations: [Annotation]) -> QueryInterfaceRequest<T> {
        var request = group { (db, source) in
            guard let source = source else {
                fatalError("source required")
            }
            guard let primaryKey = try source.primaryKey(db) where !primaryKey.columns.isEmpty else {
                // TODO: not all tables have a rowid
                return [source["_rowid_"]]
            }
            return primaryKey.columns.map { source[$0] }
        }
        for annotation in annotations {
            let relation = annotation.relation.select { (db, source) in
                try [_SQLSelectionElement.Expression(expression: annotation.expression(db, source), alias: annotation.alias)]
            }
            request = request.include(relation)
        }
        return request
    }
}


extension QueryInterfaceRequest {
    
    // MARK: QueryInterfaceRequest as subquery
    
    /// Returns an SQL expression that checks the inclusion of a value in
    /// the results of another request.
    public func contains(element: SQLExpressible) -> _SQLExpression {
        return .InSubQuery(query, element.sqlExpression)
    }
    
    /// Returns an SQL expression that checks whether the receiver, as a
    /// subquery, returns any row.
    public var exists: _SQLExpression {
        return .Exists(query)
    }
}


extension TableMapping {
    
    // MARK: Request Derivation
    
    /// Returns a QueryInterfaceRequest which fetches all rows in the table.
    @warn_unused_result
    public static func all() -> QueryInterfaceRequest<Self> {
        return QueryInterfaceRequest(tableName: databaseTableName())
    }
    
    /// Returns a QueryInterfaceRequest which selects *selection*.
    /// TODO: document the closure
    @warn_unused_result
    public static func select(selection: (SQLSource) -> SQLSelectable) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
    }
    
    /// Returns a QueryInterfaceRequest which selects *selection*.
    /// TODO: document the closure
    @warn_unused_result
    public static func select(selection: (SQLSource) -> [SQLSelectable]) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
    }
    
    /// Returns a QueryInterfaceRequest which selects *selection*.
    @warn_unused_result
    public static func select(selection: SQLSelectable...) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
    }
    
    /// Returns a QueryInterfaceRequest which selects *selection*.
    @warn_unused_result
    public static func select(selection: [SQLSelectable]) -> QueryInterfaceRequest<Self> {
        return all().select(selection)
    }
    
    /// Returns a QueryInterfaceRequest which selects *sql*.
    @warn_unused_result
    public static func select(sql sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> {
        return all().select(sql: sql, arguments: arguments)
    }
    
    /// Returns a QueryInterfaceRequest with the provided *predicate*.
    /// TODO: Document the closure
    @warn_unused_result
    public static func filter(predicate: (SQLSource) -> SQLExpressible) -> QueryInterfaceRequest<Self> {
        return all().filter(predicate)
    }
    
    /// Returns a QueryInterfaceRequest with the provided *predicate*.
    @warn_unused_result
    public static func filter(predicate: SQLExpressible) -> QueryInterfaceRequest<Self> {
        return all().filter(predicate)
    }
    
    /// Returns a QueryInterfaceRequest with the provided *predicate*.
    @warn_unused_result
    public static func filter(sql sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> {
        return all().filter(sql: sql, arguments: arguments)
    }
    
    /// Returns a QueryInterfaceRequest sorted according to the
    /// provided *orderings*.
    /// TODO: document closure
    @warn_unused_result
    public static func order(orderings: (SQLSource) -> _SQLOrdering) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Returns a QueryInterfaceRequest sorted according to the
    /// provided *orderings*.
    /// TODO: document closure
    @warn_unused_result
    public static func order(orderings: (SQLSource) -> [_SQLOrdering]) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Returns a QueryInterfaceRequest sorted according to the
    /// provided *orderings*.
    @warn_unused_result
    public static func order(orderings: _SQLOrdering...) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Returns a QueryInterfaceRequest sorted according to the
    /// provided *orderings*.
    @warn_unused_result
    public static func order(orderings: [_SQLOrdering]) -> QueryInterfaceRequest<Self> {
        return all().order(orderings)
    }
    
    /// Returns a QueryInterfaceRequest sorted according to *sql*.
    @warn_unused_result
    public static func order(sql sql: String, arguments: StatementArguments? = nil) -> QueryInterfaceRequest<Self> {
        return all().order(sql: sql, arguments: arguments)
    }
    
    /// Returns a QueryInterfaceRequest which fetches *limit* rows, starting at
    /// *offset*.
    @warn_unused_result
    public static func limit(limit: Int, offset: Int? = nil) -> QueryInterfaceRequest<Self> {
        return all().limit(limit, offset: offset)
    }
}


extension TableMapping {
    
    // MARK: Counting
    
    /// Returns the number of records.
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchCount(db: Database) -> Int {
        return all().fetchCount(db)
    }
}

extension TableMapping {
    
    // MARK: Joins
    
    /// TODO: doc
    @warn_unused_result
    public static func include(joinables: SQLJoinable...) -> QueryInterfaceRequest<Self> {
        return all().include(joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public static func include(required joinables: SQLJoinable...) -> QueryInterfaceRequest<Self> {
        return all().include(required: joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public static func include(joinables: [SQLJoinable]) -> QueryInterfaceRequest<Self> {
        return all().include(joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public static func include(required joinables: [SQLJoinable]) -> QueryInterfaceRequest<Self> {
        return all().include(required: joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public static func join(joinables: SQLJoinable...) -> QueryInterfaceRequest<Self> {
        return all().join(joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public static func join(required joinables: SQLJoinable...) -> QueryInterfaceRequest<Self> {
        return all().join(required: joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public static func join(joinables: [SQLJoinable]) -> QueryInterfaceRequest<Self> {
        return all().join(joinables)
    }
    
    /// TODO: doc
    @warn_unused_result
    public static func join(required joinables: [SQLJoinable]) -> QueryInterfaceRequest<Self> {
        return all().join(required: joinables)
    }
}


extension TableMapping {
    
    // MARK: Annotations
    
    /// TODO: documentation
    @warn_unused_result
    public static func annotate(annotations: Annotation...) -> QueryInterfaceRequest<Self> {
        return all().annotate(annotations)
    }
    
    /// TODO: documentation
    @warn_unused_result
    public static func annotate(annotations: [Annotation]) -> QueryInterfaceRequest<Self> {
        return all().annotate(annotations)
    }
}


extension RowConvertible where Self: TableMapping {
    
    // MARK: Fetching All
    
    /// Returns a sequence of all records fetched from the database.
    ///
    ///     let persons = Person.fetch(db) // DatabaseSequence<Person>
    ///
    /// The returned sequence can be consumed several times, but it may yield
    /// different results, should database changes have occurred between two
    /// generations:
    ///
    ///     let persons = Person.fetch(db)
    ///     Array(persons).count // 3
    ///     db.execute("DELETE ...")
    ///     Array(persons).count // 2
    ///
    /// If the database is modified while the sequence is iterating, the
    /// remaining elements are undefined.
    @warn_unused_result
    public static func fetch(db: Database) -> DatabaseSequence<Self> {
        return all().fetch(db)
    }
    
    /// Returns an array of all records fetched from the database.
    ///
    ///     let persons = Person.fetchAll(db) // [Person]
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchAll(db: Database) -> [Self] {
        return all().fetchAll(db)
    }
    
    /// Returns the first record fetched from a fetch request.
    ///
    ///     let person = Person.fetchOne(db) // Person?
    ///
    /// - parameter db: A database connection.
    @warn_unused_result
    public static func fetchOne(db: Database) -> Self? {
        return all().fetchOne(db)
    }
}
