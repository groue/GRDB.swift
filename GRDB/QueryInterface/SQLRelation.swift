/// A "relation" as defined by the [relational terminology](https://en.wikipedia.org/wiki/Relational_database#Terminology):
///
/// > A set of tuples sharing the same attributes; a set of columns and rows.
struct SQLRelation {
    var source: SQLSource
    var selection: [SQLSelectable]
    var filterPromise: DatabasePromise<SQLExpression?>
    var ordering: SQLRelation.Ordering
    var joins: OrderedDictionary<String, SQLJoin>
    
    init(
        source: SQLSource,
        selection: [SQLSelectable] = [],
        filterPromise: DatabasePromise<SQLExpression?> = DatabasePromise(value: nil),
        ordering: SQLRelation.Ordering = SQLRelation.Ordering(),
        joins: OrderedDictionary<String, SQLJoin> = [:])
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
        relation.filterPromise = relation.filterPromise.flatMap { filter in
            if let filter = filter {
                return DatabasePromise { try filter && predicate($0) }
            } else {
                return DatabasePromise { try predicate($0).sqlExpression }
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
    
    func appendingJoin(_ join: SQLJoin, forKey key: String) -> SQLRelation {
        var relation = self
        if let existingJoin = relation.joins.removeValue(forKey: key) {
            guard let mergedJoin = existingJoin.merged(with: join) else {
                // can't merge
                fatalError("The association key \"\(key)\" is ambiguous. Use the Association.forKey(_:) method is order to disambiguate.")
            }
            relation.joins.appendValue(mergedJoin, forKey: key)
        } else {
            relation.joins.appendValue(join, forKey: key)
        }
        return relation
    }
    
    func qualified(with alias: TableAlias) -> SQLRelation {
        var relation = self
        relation.source = source.qualified(with: alias)
        return relation
    }
}

// MARK: - SQLSource

enum SQLSource {
    case table(tableName: String, alias: TableAlias?)
    indirect case query(SQLSelectQuery)
    
    func qualified(with alias: TableAlias) -> SQLSource {
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
                    return .terms(terms.map { $0.map { $0.reversed } })
                case .ordering(let ordering):
                    return .ordering(ordering.reversed)
                }
            }
            
            func qualified(with alias: TableAlias) -> Element {
                switch self {
                case .terms(let terms):
                    return .terms(terms.map { $0.map { $0.qualifiedOrdering(with: alias) } })
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

// MARK: - SQLJoin

struct SQLJoin {
    /// The condition that links two joined tables.
    ///
    /// Currently, we only support one kind of join condition: foreign keys.
    ///
    ///     SELECT ... FROM book JOIN author ON author.id = book.authorId
    ///                                         <- the join condition -->
    ///
    /// When we eventually add support for new ways to join tables, Condition
    /// is the type we'll need to update.
    ///
    /// Condition equality allows merging of associations:
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
    struct Condition: Equatable {
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
        
        var reversed: Condition {
            return Condition(foreignKeyRequest: foreignKeyRequest, originIsLeft: !originIsLeft)
        }
        
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
            let foreignKeyMapping = try foreignKeyRequest.fetchMapping(db)
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
    
    var isRequired: Bool
    var condition: Condition
    var relation: SQLRelation
}

// MARK: - Merging
//
// "Merging" is an operation that takes two relations and, if they are
// compatible, gathers them into a merged relation.
//
// It is an important feature that allows the user to define associated requests
// in several steps. For example, in the sample code below, both requests are
// equivalent and generate the same SQL query, thanks to merging:
//
//      let request1 = Book.including(required: Book.author)
//
//      let request2 = Book
//          .including(required: Book.author)
//          .including(required: Book.author)

extension SQLRelation {
    /// Returns nil if relations can't be merged (conflict in source, joins...)
    func merged(with other: SQLRelation) -> SQLRelation? {
        guard let mergedSource = source.merged(with: other.source) else {
            // can't merge
            return nil
        }
        
        let mergedFilterPromise: DatabasePromise<SQLExpression?> = filterPromise.flatMap { expression in
            return DatabasePromise { db in
                let otherExpression = try other.filterPromise.resolve(db)
                let expressions = [expression, otherExpression].compactMap { $0 }
                if expressions.isEmpty {
                    return nil
                } else {
                    return expressions.joined(operator: .and)
                }
            }
        }
        
        var mergedJoins: OrderedDictionary<String, SQLJoin> = [:]
        for (key, join) in joins {
            if let otherJoin = other.joins[key] {
                guard let mergedJoin = join.merged(with: otherJoin) else {
                    // can't merge
                    return nil
                }
                mergedJoins.appendValue(mergedJoin, forKey: key)
            } else {
                mergedJoins.appendValue(join, forKey: key)
            }
        }
        for (key, join) in other.joins where mergedJoins[key] == nil {
            mergedJoins.appendValue(join, forKey: key)
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

extension SQLSource {
    /// Returns nil if sources can't be merged (conflict in tables, aliases...)
    func merged(with other: SQLSource) -> SQLSource? {
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
                guard let mergedAlias = alias.merged(with: otherAlias) else {
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

extension SQLJoin {
    /// Returns nil if joins can't be merged (conflict in condition, relation...)
    func merged(with other: SQLJoin) -> SQLJoin? {
        guard condition == other.condition else {
            // can't merge
            return nil
        }
        
        guard let mergedRelation = relation.merged(with: other.relation) else {
            // can't merge
            return nil
        }
        
        return SQLJoin(
            isRequired: isRequired || other.isRequired,
            condition: condition,
            relation: mergedRelation)
    }
}
