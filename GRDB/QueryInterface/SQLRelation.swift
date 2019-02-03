/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// A "relation" as defined by the [relational terminology](https://en.wikipedia.org/wiki/Relational_database#Terminology):
///
/// > A set of tuples sharing the same attributes; a set of columns and rows.
///
/// :nodoc:
public /* TODO: internal */ struct SQLRelation {
    var source: SQLRelation.Source
    var selection: [SQLSelectable]
    var filterPromise: DatabasePromise<SQLExpression?>
    var ordering: SQLRelation.Ordering
    var joins: OrderedDictionary<String, Join>
    
    var alias: TableAlias? {
        return source.alias
    }
    
    init(
        source: SQLRelation.Source,
        selection: [SQLSelectable] = [],
        filterPromise: DatabasePromise<SQLExpression?> = DatabasePromise(value: nil),
        ordering: SQLRelation.Ordering = SQLRelation.Ordering(),
        joins: OrderedDictionary<String, Join> = [:])
    {
        self.source = source
        self.selection = selection
        self.filterPromise = filterPromise
        self.ordering = ordering
        self.joins = joins
    }
}

extension SQLRelation {
    func select(_ selection: [SQLSelectable]) -> SQLRelation {
        var relation = self
        relation.selection = selection
        return relation
    }
    
    func annotated(with selection: [SQLSelectable]) -> SQLRelation {
        var relation = self
        relation.selection.append(contentsOf: selection)
        return relation
    }

    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> SQLRelation {
        var relation = self
        relation.filterPromise = relation.filterPromise.map { (db, filter) in
            if let filter = filter {
                return try filter && predicate(db)
            } else {
                return try predicate(db).sqlExpression
            }
        }
        return relation
    }
    
    func order(_ orderings: @escaping (Database) throws -> [SQLOrderingTerm]) -> SQLRelation {
        return order(SQLRelation.Ordering(orderings: orderings))
    }
    
    func reversed() -> SQLRelation {
        return order(ordering.reversed)
    }
    
    private func order(_ ordering: SQLRelation.Ordering) -> SQLRelation {
        var relation = self
        relation.ordering = ordering
        return relation
    }
    
    func unordered() -> SQLRelation {
        return order(SQLRelation.Ordering())
    }
    
    func appendingJoin(_ join: Join, forKey key: String) -> SQLRelation {
        var relation = self
        if let existingJoin = relation.joins.removeValue(forKey: key) {
            guard let mergedJoin = existingJoin.merged(with: join) else {
                // can't merge
                fatalError("The association key \"\(key)\" is ambiguous. Use the Association.forKey(_:) method is order to disambiguate.")
            }
            relation.joins.append(value: mergedJoin, forKey: key)
        } else {
            relation.joins.append(value: join, forKey: key)
        }
        return relation
    }
    
    func qualified(with alias: TableAlias) -> SQLRelation {
        var relation = self
        relation.source = source.qualified(with: alias)
        return relation
    }
}

extension SQLRelation {
    /// A finalized relation is ready for SQL generation
    var finalizedRelation: SQLRelation {
        var relation = self
        
        let alias = TableAlias()
        relation.source = source.qualified(with: alias)
        relation.selection = selection.map { $0.qualifiedSelectable(with: alias) }
        relation.filterPromise = filterPromise.map { [alias] (_, expr) in expr?.qualifiedExpression(with: alias) }
        relation.ordering = ordering.qualified(with: alias)
        relation.joins = joins.mapValues { $0.finalizedJoin }
        
        return relation
    }
    
    /// - precondition: self is the result of finalizedRelation
    var finalizedAliases: [TableAlias] {
        var aliases: [TableAlias] = []
        if let alias = alias {
            aliases.append(alias)
        }
        return joins.reduce(into: aliases) {
            $0.append(contentsOf: $1.value.relation.finalizedAliases)
        }
    }
    
    /// - precondition: self is the result of finalizedRelation
    var finalizedSelection: [SQLSelectable] {
        return joins.reduce(into: selection) {
            $0.append(contentsOf: $1.value.relation.finalizedSelection)
        }
    }
    
    /// - precondition: self is the result of finalizedRelation
    var finalizedOrdering: SQLRelation.Ordering {
        return joins.reduce(ordering) {
            $0.appending($1.value.relation.finalizedOrdering)
        }
    }
    
    /// - precondition: self is the result of finalizedRelation
    func finalizedRowAdapter(_ db: Database, fromIndex startIndex: Int, forKeyPath keyPath: [String]) throws -> (adapter: RowAdapter, endIndex: Int)? {
        let selectionWidth = try selection
            .map { try $0.columnCount(db) }
            .reduce(0, +)
        
        var endIndex = startIndex + selectionWidth
        var scopes: [String: RowAdapter] = [:]
        for (key, join) in joins {
            if let (joinAdapter, joinEndIndex) = try join.relation.finalizedRowAdapter(db, fromIndex: endIndex, forKeyPath: keyPath + [key]) {
                scopes[key] = joinAdapter
                endIndex = joinEndIndex
            }
        }
        
        if selectionWidth == 0 && scopes.isEmpty {
            return nil
        }
        
        let adapter = RangeRowAdapter(startIndex ..< (startIndex + selectionWidth))
        return (adapter: adapter.addingScopes(scopes), endIndex: endIndex)
    }
}

extension SQLRelation {
    /// Returns nil if queries can't be merged (conflict in source, joins...)
    func merged(with other: SQLRelation) -> SQLRelation? {
        guard let mergedSource = source.merged(with: other.source) else {
            // can't merge
            return nil
        }
        
        let mergedFilterPromise = filterPromise.map { (db, expression) -> SQLExpression? in
            let otherExpression = try other.filterPromise.resolve(db)
            let expressions = [expression, otherExpression].compactMap { $0 }
            if expressions.isEmpty {
                return nil
            }
            return expressions.joined(operator: .and)
        }
        
        var mergedJoins: OrderedDictionary<String, Join> = [:]
        for (key, join) in joins {
            if let otherJoin = other.joins[key] {
                guard let mergedJoin = join.merged(with: otherJoin) else {
                    // can't merge
                    return nil
                }
                mergedJoins.append(value: mergedJoin, forKey: key)
            } else {
                mergedJoins.append(value: join, forKey: key)
            }
        }
        for (key, join) in other.joins where mergedJoins[key] == nil {
            mergedJoins.append(value: join, forKey: key)
        }
        
        // replace selection unless empty
        let mergedSelection = other.selection.isEmpty ? selection : other.selection
        
        // replace ordering unless empty
        let mergedOrdering = other.ordering.isEmpty ? ordering : other.ordering
        
        return SQLRelation(
            source: mergedSource,
            selection: mergedSelection,
            filterPromise: mergedFilterPromise,
            ordering: mergedOrdering,
            joins: mergedJoins)
    }
}

// MARK: - SQLRelation.Source

extension SQLRelation {
    enum Source {
        case table(tableName: String, alias: TableAlias?)
        indirect case query(SQLSelectQuery)
        
        var alias: TableAlias? {
            switch self {
            case .table(_, let alias):
                return alias
            case .query(let query):
                return query.alias
            }
        }
        
        func sourceSQL(_ db: Database, _ context: inout SQLGenerationContext) throws -> String {
            switch self {
            case .table(let tableName, let alias):
                if let alias = alias, let aliasName = context.aliasName(for: alias) {
                    return "\(tableName.quotedDatabaseIdentifier) \(aliasName.quotedDatabaseIdentifier)"
                } else {
                    return "\(tableName.quotedDatabaseIdentifier)"
                }
            case .query(let query):
                return try "(\(query.sql(db, &context)))"
            }
        }
        
        func qualified(with alias: TableAlias) -> Source {
            switch self {
            case .table(let tableName, let sourceAlias):
                if let sourceAlias = sourceAlias {
                    alias.becomeProxy(of: sourceAlias)
                    return self
                } else {
                    alias.setTableName(tableName)
                    return .table(tableName: tableName, alias: alias)
                }
            case .query(let query):
                return .query(query.qualified(with: alias))
            }
        }
        
        /// Returns nil if sources can't be merged (conflict in tables, aliases...)
        func merged(with other: Source) -> Source? {
            switch (self, other) {
            case let (.table(tableName: tableName, alias: alias), .table(tableName: otherTableName, alias: otherAlias)):
                guard tableName == otherTableName else {
                    // can't merge
                    return nil
                }
                switch (alias, otherAlias) {
                case (nil, nil):
                    return .table(tableName: tableName, alias: nil)
                case let (alias?, nil), let (nil, alias?):
                    return .table(tableName: tableName, alias: alias)
                case let (alias?, otherAlias?):
                    guard let mergedAlias = alias.merge(with: otherAlias) else {
                        // can't merge
                        return nil
                    }
                    return .table(tableName: tableName, alias: mergedAlias)
                }
            default:
                // can't merge
                return nil
            }
        }
    }
}

// MARK: - SQLRelation.Ordering

extension SQLRelation {
    /// SQLRelation.Ordering provides the order clause to SQLRelation.
    struct Ordering {
        private enum Element {
            case terms(DatabasePromise<[SQLOrderingTerm]>)
            case ordering(SQLRelation.Ordering)
            
            var reversed: Element {
                switch self {
                case .terms(let terms):
                    return .terms(terms.map { (db, terms) in terms.map { $0.reversed } })
                case .ordering(let ordering):
                    return .ordering(ordering.reversed)
                }
            }
            
            func qualified(with alias: TableAlias) -> Element {
                switch self {
                case .terms(let terms):
                    return .terms(terms.map { (db, terms) in terms.map { $0.qualifiedOrdering(with: alias) } })
                case .ordering(let ordering):
                    return .ordering(ordering.qualified(with: alias))
                }
            }
            
            func resolve(_ db: Database) throws -> [SQLOrderingTerm] {
                switch self {
                case .terms(let terms):
                    return try terms.resolve(db)
                case .ordering(let ordering):
                    return try ordering.resolve(db)
                }
            }
        }
        
        private var elements: [Element] = []
        var isReversed: Bool
        
        var isEmpty: Bool {
            return elements.isEmpty
        }
        
        private init(elements: [Element], isReversed: Bool) {
            self.elements = elements
            self.isReversed = isReversed
        }
        
        init() {
            self.init(
                elements: [],
                isReversed: false)
        }
        
        init(orderings: @escaping (Database) throws -> [SQLOrderingTerm]) {
            self.init(
                elements: [.terms(DatabasePromise(orderings))],
                isReversed: false)
        }
        
        var reversed: Ordering {
            return Ordering(
                elements: elements,
                isReversed: !isReversed)
        }
        
        func qualified(with alias: TableAlias) -> Ordering {
            return Ordering(
                elements: elements.map { $0.qualified(with: alias) },
                isReversed: isReversed)
        }
        
        func appending(_ ordering: Ordering) -> Ordering {
            return Ordering(
                elements: elements + [.ordering(ordering)],
                isReversed: isReversed)
        }
        
        func resolve(_ db: Database) throws -> [SQLOrderingTerm] {
            if isReversed {
                return try elements.flatMap { try $0.reversed.resolve(db) }
            } else {
                return try elements.flatMap { try $0.resolve(db) }
            }
        }
    }
}

// MARK: - Join

/// Not to be mismatched with SQL join operators (inner join, left join).
///
/// JoinOperator is designed to be hierarchically nested, unlike
/// SQL join operators.
///
/// Consider the following request for (A, B, C) tuples:
///
///     let r = A.including(optional: A.b.including(required: B.c))
///
/// It chains three associations, the first optional, the second required.
///
/// It looks like it means: "Give me all As, along with their Bs, granted those
/// Bs have their Cs. For As whose B has no C, give me a nil B".
///
/// It can not be expressed as one left join, and a regular join, as below,
/// Because this would not honor the first optional:
///
///     -- dubious
///     SELECT a.*, b.*, c.*
///     FROM a
///     LEFT JOIN b ON ...
///     JOIN c ON ...
///
/// Instead, it should:
/// - allow (A + missing (B + C))
/// - prevent (A + (B + missing C)).
///
/// This can be expressed in SQL with two left joins, and an extra condition:
///
///     -- likely correct
///     SELECT a.*, b.*, c.*
///     FROM a
///     LEFT JOIN b ON ...
///     LEFT JOIN c ON ...
///     WHERE NOT((b.id IS NOT NULL) AND (c.id IS NULL)) -- no B without C
///
/// This is currently not implemented, and requires a little more thought.
/// I don't even know if inventing a whole new way to perform joins should even
/// be on the table. But we have a hierarchical way to express joined queries,
/// and they have a meaning:
///
///     // what is my meaning?
///     A.including(optional: A.b.including(required: B.c))
///
/// :nodoc:
public /* TODO: internal */ enum JoinOperator {
    case required, optional
}

/// The condition that links two joined tables.
///
/// Currently, we only support one kind of join condition: foreign keys.
///
///     SELECT ... FROM book JOIN author ON author.id = book.authorId
///                                         <- the join condition -->
///
/// When we eventually add support for new ways to join tables, JoinCondition
/// is the type we'll need to update.
///
/// JoinCondition equality allows merging of associations:
///
///     // request1 and request2 are equivalent
///     let request1 = Book
///         .including(required: Book.author)
///     let request2 = Book
///         .including(required: Book.author)
///         .including(required: Book.author)
///
///     // request3 and request4 are equivalent
///     let request3 = Book
///         .including(required: Book.author.filter(condition1 && condition2))
///     let request4 = Book
///         .joining(required: Book.author.filter(condition1))
///         .including(optional: Book.author.filter(condition2))
///
/// :nodoc:
public /* TODO: internal */ struct JoinCondition: Equatable {
    /// Definition of a foreign key
    var foreignKeyRequest: ForeignKeyRequest
    
    /// True if the table at the origin of the foreign key is on the left of
    /// the sql JOIN operator.
    ///
    /// Let's consider the `book.authorId -> author.id` foreign key.
    /// Its origin table is `book`.
    ///
    /// The origin table `book` is on the left of the JOIN operator for
    /// the BelongsTo association:
    ///
    ///     -- Book.including(required: Book.author)
    ///     SELECT ... FROM book JOIN author ON author.id = book.authorId
    ///
    /// The origin table `book`is on the right of the JOIN operator for
    /// the HasMany and HasOne associations:
    ///
    ///     -- Author.including(required: Author.books)
    ///     SELECT ... FROM author JOIN book ON author.id = book.authorId
    var originIsLeft: Bool
    
    /// Returns an SQL expression for the join condition.
    ///
    ///     SELECT ... FROM book JOIN author ON author.id = book.authorId
    ///                                         <- the SQL expression -->
    ///
    /// - parameter db: A database connection.
    /// - parameter leftAlias: A TableAlias for the table on the left of the
    ///   JOIN operator.
    /// - parameter rightAlias: A TableAlias for the table on the right of the
    ///   JOIN operator.
    /// - Returns: An SQL expression.
    func sqlExpression(_ db: Database, leftAlias: TableAlias, rightAlias: TableAlias) throws -> SQLExpression {
        let foreignKeyMapping = try foreignKeyRequest.fetch(db).mapping
        let columnMapping: [(left: Column, right: Column)]
        if originIsLeft {
            columnMapping = foreignKeyMapping.map { (left: Column($0.origin), right: Column($0.destination)) }
        } else {
            columnMapping = foreignKeyMapping.map { (left: Column($0.destination), right: Column($0.origin)) }
        }
        
        return columnMapping
            .map { $0.right.qualifiedExpression(with: rightAlias) == $0.left.qualifiedExpression(with: leftAlias) }
            .joined(operator: .and)
    }
}

struct Join {
    var joinOperator: JoinOperator
    var joinCondition: JoinCondition
    var relation: SQLRelation
    
    var finalizedJoin: Join {
        var join = self
        join.relation = relation.finalizedRelation
        return join
    }
    
    /// - precondition: relation is the result of finalizedRelation
    func joinSQL(_ db: Database,_ context: inout SQLGenerationContext, leftAlias: TableAlias, isRequiredAllowed: Bool) throws -> String {
        var isRequiredAllowed = isRequiredAllowed
        var sql = ""
        switch joinOperator {
        case .optional:
            isRequiredAllowed = false
            sql += "LEFT JOIN"
        case .required:
            guard isRequiredAllowed else {
                // TODO: chainOptionalRequired
                fatalError("Not implemented: chaining a required association behind an optional association")
            }
            sql += "JOIN"
        }
        
        sql += try " " + relation.source.sourceSQL(db, &context)
        
        let rightAlias = relation.alias!
        let filters = try [
            joinCondition.sqlExpression(db, leftAlias: leftAlias, rightAlias: rightAlias),
            relation.filterPromise.resolve(db)
            ].compactMap { $0 }
        if !filters.isEmpty {
            sql += " ON " + filters.joined(operator: .and).expressionSQL(&context)
        }
        
        for (_, join) in relation.joins {
            sql += try " " + join.joinSQL(db, &context, leftAlias: rightAlias, isRequiredAllowed: isRequiredAllowed)
        }
        
        return sql
    }
    
    /// Returns nil if joins can't be merged (conflict in condition, relation...)
    func merged(with other: Join) -> Join? {
        guard joinCondition == other.joinCondition else {
            // can't merge
            return nil
        }
        
        guard let mergedRelation = relation.merged(with: other.relation) else {
            // can't merge
            return nil
        }
        
        let mergedJoinOperator: JoinOperator
        switch (joinOperator, other.joinOperator) {
        case (.required, _), (_, .required):
            mergedJoinOperator = .required
        default:
            mergedJoinOperator = .optional
        }
        
        return Join(
            joinOperator: mergedJoinOperator,
            joinCondition: joinCondition,
            relation: mergedRelation)
    }
}
