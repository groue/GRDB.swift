/// A "relation" as defined by the [relational terminology](https://en.wikipedia.org/wiki/Relational_database#Terminology):
///
/// > A set of tuples sharing the same attributes; a set of columns and rows.
///
///     SELECT ... FROM ... JOIN ... WHERE ... ORDER BY ...
///            |        |        |         |            |
///            |        |        |         |            • ordering
///            |        |        |         • filterPromise
///            |        |        • children
///            |        • source
///            • selection
struct SQLRelation {
    struct Child {
        enum Kind {
            // Record.including(optional: association)
            case oneOptional
            // Record.including(required: association)
            case oneRequired
            // Record.including(all: association)
            case allPrefetched
            // Record.including(all: associationThroughPivot)
            case allNotPrefetched
        }
        
        var kind: Kind
        var condition: SQLAssociationCondition
        var relation: SQLRelation
        
        /// Returns true iff this child can change the parent count.
        ///
        /// Record.including(required: association) // true
        /// Record.including(all: association)      // false
        var impactsParentCount: Bool {
            switch kind {
            case .oneOptional, .oneRequired:
                return true
            case .allPrefetched, .allNotPrefetched:
                return false
            }
        }
    }
    
    var source: SQLSource
    var selection: [SQLSelectable]
    var filterPromise: DatabasePromise<SQLExpression?>
    var ordering: SQLRelation.Ordering
    var children: OrderedDictionary<String, Child>
    
    init(
        source: SQLSource,
        selection: [SQLSelectable] = [],
        filterPromise: DatabasePromise<SQLExpression?> = DatabasePromise(value: nil),
        ordering: SQLRelation.Ordering = SQLRelation.Ordering(),
        children: OrderedDictionary<String, Child> = [:])
    {
        self.source = source
        self.selection = selection
        self.filterPromise = filterPromise
        self.ordering = ordering
        self.children = children
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
    
    func appendingChild(_ child: SQLRelation.Child, forKey key: String) -> SQLRelation {
        var relation = self
        if let existingChild = relation.children.removeValue(forKey: key) {
            guard let mergedChild = existingChild.merged(with: child) else {
                // can't merge
                fatalError("The association key \"\(key)\" is ambiguous. Use the Association.forKey(_:) method is order to disambiguate.")
            }
            relation.children.appendValue(mergedChild, forKey: key)
        } else {
            relation.children.appendValue(child, forKey: key)
        }
        return relation
    }
    
    func deletingChildren() -> SQLRelation {
        var relation = self
        relation.children = [:]
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

// MARK: - SQLAssociationCondition

/// The condition that links two tables.
///
/// Currently, we only support one kind of condition: foreign keys.
///
///     SELECT ... FROM book JOIN author ON author.id = book.authorId
///                                         <---- the condition ---->
///
/// When we eventually add support for new ways to link tables,
/// SQLAssociationCondition is the type we'll need to update.
///
/// SQLAssociationCondition adopts Equatable so that we can merge associations:
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
struct SQLAssociationCondition: Equatable {
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
    
    var reversed: SQLAssociationCondition {
        return SQLAssociationCondition(
            foreignKeyRequest: foreignKeyRequest,
            originIsLeft: !originIsLeft)
    }
    
    /// Orient foreignKey according to the originIsLeft flag
    private func columnMapping(_ db: Database) throws -> [(left: String, right: String)] {
        let foreignKeyMapping = try foreignKeyRequest.fetchMapping(db)
        if originIsLeft {
            return foreignKeyMapping.map { (left: $0.origin, right: $0.destination) }
        } else {
            return foreignKeyMapping.map { (left: $0.destination, right: $0.origin) }
        }
    }
    
    /// Resolves the condition into an SQL expression which involves both left
    /// and right tables.
    ///
    ///     SELECT * FROM left JOIN right ON (right.a = left.b)
    ///                                      <---------------->
    ///
    /// - parameter db: A database connection.
    /// - parameter leftAlias: A TableAlias for the table on the left of the
    ///   JOIN operator.
    /// - parameter rightAlias: A TableAlias for the table on the right of the
    ///   JOIN operator.
    /// - Returns: An SQL expression.
    func joinExpression(_ db: Database, leftAlias: TableAlias, rightAlias: TableAlias) throws -> SQLExpression {
        return try columnMapping(db)
            .map { QualifiedColumn($0.right, alias: rightAlias) == QualifiedColumn($0.left, alias: leftAlias) }
            .joined(operator: .and)
    }
    
    /// Resolves the condition into an SQL expression which involves only the
    /// right table.
    ///
    /// Given `right.a = left.b`, returns `right.a = 1` or
    /// `right.a IN (1, 2, 3)`.
    func filteringExpression(_ db: Database, leftRows: [Row], rightAlias: TableAlias) throws -> SQLExpression {
        if leftRows.isEmpty {
            // Degenerate case: therre is no row to attach
            return false.sqlExpression
        }
        
        let columnMapping = try self.columnMapping(db)
        let valueMappings = columnMapping.map { columns in
            (column: QualifiedColumn(columns.right, alias: rightAlias),
             dbValues: leftRows.map { $0[columns.left] as DatabaseValue })
        }
        
        guard let valueMapping = valueMappings.first else {
            // Degenerate case: no joining column
            return true.sqlExpression
        }
        
        if valueMappings.count == 1 {
            // Join on a single column.
            // Unique and sort database values for nicer output:
            let dbValues = valueMapping.dbValues
                .reduce(into: Set<DatabaseValue>(), { $0.insert($1) })
                .sorted(by: <)
            
            if dbValues.count == 1 {
                // Single row: table.a = 1
                return (valueMapping.column == dbValues[0])
            } else {
                // Multiple rows: table.a IN (1, 2, 3)
                return dbValues.contains(valueMapping.column)
            }
        } else {
            // Join on a multiple columns.
            if valueMapping.dbValues.count == 1 {
                // Single row: (table.a = 1) AND (table.b = 2)
                return valueMappings
                    .map { $0.column == $0.dbValues[0] }
                    .joined(operator: .and)
            } else {
                // Multiple rows: TODO
                fatalError("not implemented")
            }
        }
    }
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
        
        var mergedChildren: OrderedDictionary<String, SQLRelation.Child> = [:]
        for (key, child) in children {
            if let otherChild = other.children[key] {
                guard let mergedChild = child.merged(with: otherChild) else {
                    // can't merge
                    return nil
                }
                mergedChildren.appendValue(mergedChild, forKey: key)
            } else {
                mergedChildren.appendValue(child, forKey: key)
            }
        }
        for (key, child) in other.children where mergedChildren[key] == nil {
            mergedChildren.appendValue(child, forKey: key)
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
            children: mergedChildren)
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

extension SQLRelation.Child {
    /// Returns nil if joins can't be merged (conflict in condition, relation...)
    func merged(with other: SQLRelation.Child) -> SQLRelation.Child? {
        guard condition == other.condition else {
            // can't merge
            return nil
        }
        
        guard let mergedRelation = relation.merged(with: other.relation) else {
            // can't merge
            return nil
        }
        
        guard let mergedKind = kind.merged(with: other.kind) else {
            // can't merge
            return nil
        }
        
        return SQLRelation.Child(
            kind: mergedKind,
            condition: condition,
            relation: mergedRelation)
    }
}

extension SQLRelation.Child.Kind {
    /// Returns nil if kinds can't be merged
    func merged(with other: SQLRelation.Child.Kind) -> SQLRelation.Child.Kind? {
        switch (self, other) {
        case (.oneRequired, .oneRequired),
             (.oneRequired, .oneOptional),
             (.oneOptional, .oneRequired):
            // Equivalent to Record.including(required: association):
            //
            // Record
            //   .including(required: association)
            //   .including(optional: association)
            return .oneRequired
            
        case (.oneOptional, .oneOptional):
            // Equivalent to Record.including(optional: association):
            //
            // Record
            //   .including(optional: association)
            //   .including(optional: association)
            return .oneOptional
            
        case (.allPrefetched, .allPrefetched),
             (.allPrefetched, .allNotPrefetched),
             (.allNotPrefetched, .allPrefetched):
            // Prefetches both Pivot and Destination:
            //
            // Record
            //   .including(all: associationToDestinationThroughPivot)
            //   .including(all: associationToPivot)
            return .allPrefetched
            
        case (.allNotPrefetched, .allNotPrefetched):
            // Equivalent to Record.including(all: association)
            //
            // Record
            //   .including(all: association)
            //   .including(all: association)
            return .allNotPrefetched
            
        default:
            // Likely a programmer error:
            //
            // Record
            //   .including(all: Author.books.forKey("foo"))
            //   .including(optional: Author.books.forKey("foo"))
            return nil
        }
    }
}
