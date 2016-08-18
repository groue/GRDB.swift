#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #endif
#endif


/// TODO
struct SQLSelectQuery {
    var selection: [SQLSelectable]
    var distinct: Bool
    let source: SQLSource?
    let whereExpression: _SQLExpression?
    let groupByExpressions: [_SQLExpression]
    var orderings: [_SQLOrdering]
    var reversed: Bool
    let havingPredicate: _SQLExpression?
    let limit: SQLLimit?

    func sql(db: Database, inout _ arguments: StatementArguments?) throws -> String {
        if let source = source {
            // Give all sources unique names
            var sourcesByName: [String: [SQLSource]] = [:]
            for source in source.properlyNamedSources {
                let name = source.name
                var sources = sourcesByName[name] ?? []
                guard !sources.contains({ $0 === source }) else { continue }
                sources.append(source)
                sourcesByName[name] = sources
            }
            for (name, sources) in sourcesByName where sources.count > 1 {
                for (index, source) in sources.enumerate() {
                    source.name = "\(name)\(index)"
                }
            }
        }
        
        var sql = "SELECT"
        
        if distinct {
            sql += " DISTINCT"
        }
        
        assert(!selection.isEmpty)
        sql += try " " + selection.map { try $0.selectionSQL(db, from: source, &arguments) }.joinWithSeparator(", ")
        
        if let source = source {
            sql += try " FROM " + source.sourceSQL(db, &arguments)
        }
        
        if let whereExpression = whereExpression {
            sql += try " WHERE " + whereExpression.sql(db, &arguments)
        }
        
        if !groupByExpressions.isEmpty {
            sql += try " GROUP BY " + groupByExpressions.map { try $0.sql(db, &arguments) }.joinWithSeparator(", ")
        }
        
        if let havingPredicate = havingPredicate {
            sql += try " HAVING " + havingPredicate.sql(db, &arguments)
        }
        
        var orderings = self.orderings
        if reversed {
            if orderings.isEmpty {
                // https://www.sqlite.org/lang_createtable.html#rowid
                //
                // > The rowid value can be accessed using one of the special
                // > case-independent names "rowid", "oid", or "_rowid_" in
                // > place of a column name. If a table contains a user defined
                // > column named "rowid", "oid" or "_rowid_", then that name
                // > always refers the explicitly declared column and cannot be
                // > used to retrieve the integer rowid value.
                //
                // Here we assume that _rowid_ is not a custom column.
                // TODO: support for user-defined _rowid_ column.
                // TODO: support for WITHOUT ROWID tables.
                guard source is SQLTableSource else {   // TODO: avoid this runtime check
                    // TODO: find natural reversed ordering for a complex query
                    fatalError("Not Implemented")
                }
                orderings = [SQLColumn("_rowid_").desc]
            } else {
                orderings = orderings.map { $0.reversedSortDescriptor }
            }
        }
        if !orderings.isEmpty {
            sql += try " ORDER BY " + orderings.map { try $0.orderingSQL(db, &arguments) }.joinWithSeparator(", ")
        }
        
        if let limit = limit {
            sql += " LIMIT " + limit.sql
        }
        
        return sql
    }
    
    func adapter(db: Database) throws -> RowAdapter? {
        guard let source = source else {
            return nil
        }
        
        // Our sources define row scopes based on selection index:
        //
        //      SELECT a.*, b.* FROM a JOIN b ...
        //                  ^ scope "b" from selection index 1
        //
        // Now that we have a database, we can turn those indexes into
        // column indexes:
        //
        //      SELECT a.id, a.name, b.id, b.title FROM a JOIN b ...
        //                           ^ scope "b" from column 2
        var columnIndex = 0
        var columnIndexForSelectionIndex: [Int: Int] = [:]
        for (selectionIndex, selectable) in selection.enumerate() {
            columnIndexForSelectionIndex[selectionIndex] = columnIndex
            columnIndex += try selectable.numberOfColumns(db)
        }
        
        return source.adapter(columnIndexForSelectionIndex)
    }
}

extension SQLSelectQuery : FetchRequest {
    /// TODO
    func prepare(db: Database) throws -> (SelectStatement, RowAdapter?) {
        var arguments: StatementArguments? = StatementArguments()
        let sql = try self.sql(db, &arguments)
        let statement = try db.selectStatement(sql)
        try statement.setArgumentsWithValidation(arguments!)
        let adapter = try self.adapter(db)
        return (statement, adapter)
    }
}

extension SQLSelectQuery {
    
    /// Returns a query that counts the number of rows matched by self.
    var countQuery: SQLSelectQuery {
        guard groupByExpressions.isEmpty && limit == nil else {
            // SELECT ... GROUP BY ...
            // SELECT ... LIMIT ...
            return trivialCountQuery
        }
        
        guard let source = source as? SQLTableSource else { // TODO: avoid this runtime check
            // SELECT ... FROM (something which is not a table)
            return trivialCountQuery
        }
        
        assert(!selection.isEmpty)
        if selection.count == 1 {
            let selectable = selection[0]
            switch selectable.selectableKind {
            case .Star(source: let starSource):
                guard !distinct else {
                    return trivialCountQuery
                }
                
                if starSource !== source {
                    return trivialCountQuery
                }
                
                // SELECT tableName.* FROM tableName ...
                // ->
                // SELECT COUNT(*) FROM tableName ...
                var countQuery = unorderedQuery
                countQuery.selection = [_SQLExpression.CountAll]
                return countQuery
                
            case .Expression(let expression):
                // SELECT [DISTINCT] expr FROM tableName ...
                if distinct {
                    // SELECT DISTINCT expr FROM tableName ...
                    // ->
                    // SELECT COUNT(DISTINCT expr) FROM tableName ...
                    var countQuery = unorderedQuery
                    countQuery.distinct = false
                    countQuery.selection = [_SQLExpression.CountDistinct(expression)]
                    return countQuery
                } else {
                    // SELECT expr FROM tableName ...
                    // ->
                    // SELECT COUNT(*) FROM tableName ...
                    var countQuery = unorderedQuery
                    countQuery.selection = [_SQLExpression.CountAll]
                    return countQuery
                }
            }
        } else {
            // SELECT [DISTINCT] expr1, expr2, ... FROM tableName ...
            
            guard !distinct else {
                return trivialCountQuery
            }
            
            // SELECT expr1, expr2, ... FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            var countQuery = unorderedQuery
            countQuery.selection = [_SQLExpression.CountAll]
            return countQuery
        }
    }
    
    // SELECT COUNT(*) FROM (self)
    private var trivialCountQuery: SQLSelectQuery {
        let source = SQLSelectQuerySource(query: unorderedQuery, alias: nil)
        return SQLSelectQuery(
            selection: [_SQLExpression.CountAll],
            distinct: false,
            source: source,
            whereExpression: nil,
            groupByExpressions: [],
            orderings: [],
            reversed: false,
            havingPredicate: nil,
            limit: nil)
    }
    
    /// Remove ordering
    private var unorderedQuery: SQLSelectQuery {
        var query = self
        query.reversed = false
        query.orderings = []
        return query
    }
}


// MARK: - SQLSource

/// TODO: documentation
public protocol _SQLSource : class {
    /// TODO: documentation
    var name: String { get set }
    /// TODO: documentation
    var includedSelection: [SQLSelectable] { get }
    /// TODO: documentation
    var properlyNamedSources: [SQLSource] { get }
    /// TODO: documentation
    func sourceSQL(db: Database, inout _ arguments: StatementArguments?) throws -> String
    /// TODO: documentation
    func primaryKey(db: Database) throws -> PrimaryKeyInfo?
    /// TODO: documentation
    func numberOfColumns(db: Database) throws -> Int
    /// TODO: documentation
    func adapter(columnIndexForSelectionIndex: [Int: Int]) -> RowAdapter?
    /// TODO: documentation
    func scoped(on scopes: [Scope]) -> SQLSource!
}

/// TODO: documentation
public protocol SQLSource : _SQLSource {
}

extension SQLSource {
    // MARK: - Scoping
    
    /// TODO: documentation
    public func scoped(on scopes: String...) -> SQLSource! {
        return scoped(on: scopes)
    }
    
    /// TODO: documentation
    public func scoped(on scopes: [String]) -> SQLSource! {
        return scoped(on: scopes.map { Scope($0) })
    }
    
    /// TODO: documentation
    public func scoped(on relations: Relation...) -> SQLSource! {
        return scoped(on: relations)
    }
    
    /// TODO: documentation
    public func scoped(on relations: [Relation]) -> SQLSource! {
        return scoped(on: relations.map { $0.scope })
    }
}

extension SQLSource {
    // MARK: - Columns
    
    /// TODO: documentation
    public subscript(column: String) -> SQLColumn {
        return SQLColumn(column, source: self)
    }
    
    /// TODO: documentation
    public subscript(column: SQLColumn) -> SQLColumn {
        return SQLColumn(column.name, source: self)
    }
}


// MARK: - SQLTableSource

class SQLTableSource {
    let tableName: String
    var alias: String?
    
    init(tableName: String, alias: String?) {
        self.tableName = tableName
        self.alias = alias
    }
}

extension SQLTableSource : SQLSourceDefinition {
    func makeSource(db: Database) throws -> SQLSource {
        // This method is called when a query definition turns into an actual
        // query: SQLSelectQueryDefinition.makeSelectQuery()
        //
        // Because `SELECT foo.* FROM foo` is implemented with a common source
        // shared between the selection (foo.*) and the source (FROM foo), we
        // can't return a new instance. This would break the link between the
        // selection and the source, and this link must be kept in order to
        // allow source renaming (SQL aliasing).
        //
        // So we have to return self.
        //
        // Now SQLSelectQuery.sql() is about to rename ambiguous sources. So
        // let's reset self's name:
        alias = nil
        
        return self
    }
    
    func joining(join: SQLJoinable) -> SQLSourceDefinition {
        return SQLJoinSourceDefinition(leftSource: self, rightJoins: [join.joinDefinition])
    }
}

extension SQLTableSource : SQLSource {
    var name: String {
        get {
            return alias ?? tableName
        }
        set {
            alias = newValue
        }
    }
    
    var includedSelection: [SQLSelectable] {
        return []
    }
    
    var properlyNamedSources: [SQLSource] {
        return [self]
    }
    
    func sourceSQL(db: Database, inout _ arguments: StatementArguments?) throws -> String {
        if let alias = alias where alias != tableName {
            return tableName.quotedDatabaseIdentifier + " " + alias.quotedDatabaseIdentifier
        } else {
            return tableName.quotedDatabaseIdentifier
        }
    }
    
    func primaryKey(db: Database) throws -> PrimaryKeyInfo? {
        return try db.primaryKey(tableName)
    }
    
    func numberOfColumns(db: Database) throws -> Int {
        return try db.numberOfColumns(tableName)
    }
    
    func adapter(columnIndexForSelectionIndex: [Int: Int]) -> RowAdapter? {
        return nil
    }
    
    func scoped(on scopes: [Scope]) -> SQLSource! {
        if scopes.isEmpty { return self }
        return nil
    }
}


// MARK: - SQLSelectQuerySource

class SQLSelectQuerySource {
    let query: SQLSelectQuery
    var alias: String?
    
    init(query: SQLSelectQuery, alias: String?) {
        self.query = query
        self.alias = alias
    }
}

extension SQLSelectQuerySource : SQLSource {
    var name: String {
        get {
            return alias ?? "q"
        }
        set {
            alias = newValue
        }
    }
    
    var includedSelection: [SQLSelectable] {
        return []
    }
    
    var properlyNamedSources: [SQLSource] {
        return [self]
    }
    
    func sourceSQL(db: Database, inout _ arguments: StatementArguments?) throws -> String {
        if let alias = alias {
            return try "(" + query.sql(db, &arguments) + ") AS " + alias.quotedDatabaseIdentifier
        } else {
            return try "(" + query.sql(db, &arguments) + ")"
        }
    }
    
    func primaryKey(db: Database) throws -> PrimaryKeyInfo? {
        return nil
    }
    
    func numberOfColumns(db: Database) throws -> Int {
        return try query.selection.reduce(0) { try $0 + $1.numberOfColumns(db) }
    }
    
    func adapter(columnIndexForSelectionIndex: [Int: Int]) -> RowAdapter? {
        return nil
    }
    
    func scoped(on scopes: [Scope]) -> SQLSource! {
        if scopes.isEmpty { return self }
        return nil
    }
}


// MARK: - _SQLOrdering

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _SQLOrdering {
    var reversedSortDescriptor: _SQLSortDescriptor { get }
    func orderingSQL(db: Database, inout _ arguments: StatementArguments?) throws -> String
}

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public enum _SQLSortDescriptor {
    case Asc(_SQLExpression)
    case Desc(_SQLExpression)
}

extension _SQLSortDescriptor : _SQLOrdering {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var reversedSortDescriptor: _SQLSortDescriptor {
        switch self {
        case .Asc(let expression):
            return .Desc(expression)
        case .Desc(let expression):
            return .Asc(expression)
        }
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func orderingSQL(db: Database, inout _ arguments: StatementArguments?) throws -> String {
        switch self {
        case .Asc(let expression):
            return try expression.sql(db, &arguments) + " ASC"
        case .Desc(let expression):
            return try expression.sql(db, &arguments) + " DESC"
        }
    }
}


// MARK: - SQLLimit

struct SQLLimit {
    let limit: Int
    let offset: Int?
    
    var sql: String {
        if let offset = offset {
            return "\(limit) OFFSET \(offset)"
        } else {
            return "\(limit)"
        }
    }
}


// MARK: - SQLSelectable

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol _SQLSelectable {
    func selectionSQL(db: Database, from querySource: SQLSource?, inout _ arguments: StatementArguments?) throws -> String
    func countedSQL(db: Database, inout _ arguments: StatementArguments?) throws -> String
    var selectableKind: _SQLSelectableKind { get }
    func numberOfColumns(db: Database) throws -> Int
}

/// TODO: documentation
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol SQLSelectable : _SQLSelectable {
}

/// This type is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public enum _SQLSelectableKind {
    case Star(source: SQLSource)
    case Expression(expression: _SQLExpression)
}

enum _SQLSelectionElement {
    case Star(source: SQLSource)
    case Expression(expression: _SQLExpression, alias: String)
}

extension _SQLSelectionElement : SQLSelectable {
    
    func selectionSQL(db: Database, from querySource: SQLSource?, inout _ arguments: StatementArguments?) throws -> String {
        switch self {
        case .Star(let starSource):
            if starSource === querySource {
                return "*"
            } else {
                return starSource.name.quotedDatabaseIdentifier + ".*"
            }
        case .Expression(expression: let expression, alias: let alias):
            return try expression.sql(db, &arguments) + " AS " + alias.quotedDatabaseIdentifier
        }
    }
    
    func countedSQL(db: Database, inout _ arguments: StatementArguments?) throws -> String {
        switch self {
        case .Star:
            fatalError("Not implemented")
        case .Expression(expression: let expression, alias: _):
            return try expression.sql(db, &arguments)
        }
    }
    
    var selectableKind: _SQLSelectableKind {
        switch self {
        case .Star(let source):
            return .Star(source: source)
        case .Expression(expression: let expression, alias: _):
            return .Expression(expression: expression)
        }
    }
    
    func numberOfColumns(db: Database) throws -> Int {
        switch self {
        case .Star(let starSource):
            return try starSource.numberOfColumns(db)
        case .Expression:
            return 1
        }
    }
}
