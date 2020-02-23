/// A "relation", as defined by the [relational
/// terminology](https://en.wikipedia.org/wiki/Relational_database#Terminology),
/// is "a set of tuples sharing the same attributes; a set of columns and rows."
///
/// SQLRelation is defined with a selection, a source table of query, and an
/// eventual filter and ordering.
///
///     SELECT ... FROM ... WHERE ... ORDER BY ...
///            |        |         |            |
///            |        |         |            • ordering
///            |        |         • filter
///            |        • source
///            • selection
///
/// Other SQL clauses such as GROUP BY, LIMIT are defined one level up, in the
/// SQLQuery type.
///
/// ## Promises
///
/// Filter and ordering are actually "promises", which are only resolved
/// when a database connection is available. This is how we can implement
/// requests such as `Record.filter(key: 1)` or `Record.orderByPrimaryKey()`:
/// both need a database connection in order to introspect the primary key.
///
///     // SELECT * FROM player
///     // WHERE continent = 'EU'
///     // ORDER BY code -- primary key infered from the database schema
///     Country
///         .filter(Column("continent") == "EU")
///         .orderByPrimaryKey()
///
/// ## Children
///
/// Relations may also have children. A child is a link to another relation, and
/// provide support for joins and prefetched relations.
///
/// Relations and their children constitute a tree of relations, which the user
/// builds with associations:
///
///     // Builds a relation with two children:
///     Author
///         .including(required: Author.country)
///         .including(all: Author.books)
///
/// There are four kinds of children:
///
/// - `.oneOptional`:
///
///     Such children are left joined. They may, or not, be included in
///     the selection.
///
///         // SELECT book.*
///         // FROM book
///         // LEFT JOIN author ON author.id = book.id
///         Book.joining(optional: Book.author)
///
///         // SELECT book.*, author.*
///         // FROM book
///         // LEFT JOIN author ON author.id = book.id
///         Book.including(optional: Book.author)
///
/// - `.oneRequired`:
///
///     Such children are inner joined. They may, or not, be included in
///     the selection.
///
///         // SELECT book.*
///         // FROM book
///         // JOIN author ON author.id = book.id AND author.country = 'FR'
///         Book.joining(required: Book.author.filter(Column("country") == "FR"))
///
///         // SELECT book.*, author.*
///         // FROM book
///         // JOIN author ON author.id = book.id AND author.country = 'FR'
///         Book.including(required: Book.author.filter(Column("country") == "FR"))
///
/// - `.allPrefetched`:
///
///     Such children are prefetched using several SQL requests:
///
///         // SELECT * FROM countries WHERE continent = 'EU'
///         // SELECT * FROM passport WHERE countryCode IN ('BE', 'DE', 'FR', ...)
///         Country
///             .filter(Column("continent") == "EU")
///             .including(all: Country.passports)
///
/// - `.allNotPrefetched`:
///
///     Such children are not joined, and not prefetched. They are used as
///     intermediate children towards a prefetched child. In the example
///     below, the country relation has a `.allNotPrefetched` child to
///     passports, and the passport relation has a `.allPrefetched` child
///     to citizens.
///
///         // SELECT * FROM countries WHERE continent = 'EU'
///         // SELECT citizens.* FROM citizens
///         // JOIN passport ON passport.citizenId = citizens.id
///         //              AND passport.countryCode IN ('BE', 'DE', 'FR', ...)
///         Country
///             .filter(Column("continent") == "EU")
///             .including(all: Country.citizens)
struct SQLRelation {
    struct Child: KeyPathRefining {
        enum Kind {
            // Record.including(optional: association)
            case oneOptional
            // Record.including(required: association)
            case oneRequired
            // Record.including(all: association)
            case allPrefetched
            // Record.including(all: associationThroughPivot)
            case allNotPrefetched
            
            var cardinality: SQLAssociationCardinality {
                switch self {
                case .oneOptional, .oneRequired:
                    return .toOne
                case .allPrefetched, .allNotPrefetched:
                    return .toMany
                }
            }
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
        
        fileprivate func makeAssociationForKey(_ key: String) -> SQLAssociation {
            let key = SQLAssociationKey.fixed(key)
            return SQLAssociation(
                key: key,
                condition: condition,
                relation: relation,
                cardinality: kind.cardinality)
        }
    }
    
    var source: SQLSource
    var selection: [SQLSelectable]
    // Filter is an array of expressions that we'll join with the AND operator.
    // This gives nicer output in generated SQL: `(a AND b AND c)` instead of
    // `((a AND b) AND c)`.
    var filtersPromise: DatabasePromise<[SQLExpression]>
    var ordering: SQLRelation.Ordering
    var children: OrderedDictionary<String, Child>
    
    var prefetchedAssociations: [SQLAssociation] {
        return children.flatMap { key, child -> [SQLAssociation] in
            switch child.kind {
            case .allPrefetched:
                return [child.makeAssociationForKey(key)]
            case .oneOptional, .oneRequired, .allNotPrefetched:
                return child.relation.prefetchedAssociations.map { association in
                    // Remove redundant pivot child
                    let pivotKey = association.pivot.keyName
                    let child = child.map(\.relation, { relation in
                        assert(relation.children[pivotKey] != nil)
                        return relation.removingChild(forKey: pivotKey)
                    })
                    return association.through(child.makeAssociationForKey(key))
                }
            }
        }
    }
    
    init(
        source: SQLSource,
        selection: [SQLSelectable] = [],
        filtersPromise: DatabasePromise<[SQLExpression]> = DatabasePromise(value: []),
        ordering: SQLRelation.Ordering = SQLRelation.Ordering(),
        children: OrderedDictionary<String, Child> = [:])
    {
        self.source = source
        self.selection = selection
        self.filtersPromise = filtersPromise
        self.ordering = ordering
        self.children = children
    }
}

extension SQLRelation: KeyPathRefining {
    func select(_ selection: [SQLSelectable]) -> SQLRelation {
        return with(\.selection, selection)
    }
    
    /// Removes all selections from chidren
    func selectOnly(_ selection: [SQLSelectable]) -> SQLRelation {
        return self
            .with(\.selection, selection)
            .map(\.children, { $0.mapValues { $0.map(\.relation, { $0.selectOnly([]) }) } })
    }
    
    func annotated(with selection: [SQLSelectable]) -> SQLRelation {
        return mapInto(\.selection, { $0.append(contentsOf: selection) })
    }
    
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> SQLRelation {
        return map(\.filtersPromise, { filtersPromise in
            filtersPromise.flatMap { filters in
                DatabasePromise { try filters + [predicate($0).sqlExpression] }
            }
        })
    }
    
    func order(_ orderings: @escaping (Database) throws -> [SQLOrderingTerm]) -> SQLRelation {
        return with(\.ordering, SQLRelation.Ordering(orderings: orderings))
    }
    
    func reversed() -> SQLRelation {
        return map(\.ordering, { $0.reversed })
    }
    
    func unordered() -> SQLRelation {
        return self
            .with(\.ordering, SQLRelation.Ordering())
            .map(\.children, { $0.mapValues { $0.map(\.relation, { $0.unordered() }) } })
    }
    
    func qualified(with alias: TableAlias) -> SQLRelation {
        return map(\.source, { $0.qualified(with: alias) })
    }
}

extension SQLRelation {
    /// Returns a relation extended with an association.
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
    ///     let relation = origin.appending(sqlAssociation, kind: .oneRequired)
    ///     let query = SQLQuery(relation: relation)
    ///     let generator = SQLQueryGenerator(query)
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
    func appendingChild(for association: SQLAssociation, kind: SQLRelation.Child.Kind) -> SQLRelation {
        // Preserve association cardinality in intermediate steps of
        // including(all:), and force desired cardinality otherwize
        let childCardinality = (kind == .allNotPrefetched)
            ? association.destination.cardinality
            : kind.cardinality
        let childKey = association.destination.key.name(for: childCardinality)
        let child = SQLRelation.Child(
            kind: kind,
            condition: association.destination.condition,
            relation: association.destination.relation)
        
        let initialSteps = association.steps.dropLast()
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
            return appendingChild(child, forKey: childKey)
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
        
        reducedAssociation.destination.relation = reducedAssociation.destination.relation
            .select([]) // Intermediate steps are not prefetched
            .appendingChild(child, forKey: childKey)
        
        switch kind {
        case .oneRequired, .oneOptional, .allNotPrefetched:
            return appendingChild(for: reducedAssociation, kind: kind)
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
            return appendingChild(for: reducedAssociation, kind: .allNotPrefetched)
        }
    }
    
    private func appendingChild(_ child: SQLRelation.Child, forKey key: String) -> SQLRelation {
        var relation = self
        if let existingChild = relation.children.removeValue(forKey: key) {
            guard let mergedChild = existingChild.merged(with: child) else {
                // can't merge
                fatalError("""
                    The association key \"\(key)\" is ambiguous. \
                    Use the Association.forKey(_:) method is order to disambiguate.
                    """)
            }
            relation.children.appendValue(mergedChild, forKey: key)
        } else {
            relation.children.appendValue(child, forKey: key)
        }
        return relation
    }
    
    func removingChild(forKey key: String) -> SQLRelation {
        return mapInto(\.children, { $0.removeValue(forKey: key) })
    }
    
    func filteringChildren(_ included: (Child) throws -> Bool) rethrows -> SQLRelation {
        return try map(\.children, { try $0.filter { try included($1) } })
    }
}

extension SQLRelation: _JoinableRequest {
    func _including(all association: SQLAssociation) -> SQLRelation {
        return appendingChild(for: association, kind: .allPrefetched)
    }
    
    func _including(optional association: SQLAssociation) -> SQLRelation {
        return appendingChild(for: association, kind: .oneOptional)
    }
    
    func _including(required association: SQLAssociation) -> SQLRelation {
        return appendingChild(for: association, kind: .oneRequired)
    }
    
    func _joining(optional association: SQLAssociation) -> SQLRelation {
        return appendingChild(for: association.map(\.destination.relation, { $0.select([]) }), kind: .oneOptional)
    }
    
    func _joining(required association: SQLAssociation) -> SQLRelation {
        return appendingChild(for: association.map(\.destination.relation, { $0.select([]) }), kind: .oneRequired)
    }
}

// MARK: - SQLSource

enum SQLSource {
    case table(tableName: String, alias: TableAlias?)
    indirect case query(SQLQuery)
    
    func qualified(with alias: TableAlias) -> SQLSource {
        switch self {
        case let .table(tableName, sourceAlias):
            if let sourceAlias = sourceAlias {
                alias.becomeProxy(of: sourceAlias)
                return self
            } else {
                alias.setTableName(tableName)
                return .table(tableName: tableName, alias: alias)
            }
        case let .query(query):
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
    var foreignKeyRequest: SQLForeignKeyRequest
    
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
    func columnMappings(_ db: Database) throws -> [(left: String, right: String)] {
        let foreignKeyMapping = try foreignKeyRequest.fetchMapping(db)
        if originIsLeft {
            return foreignKeyMapping.map { (left: $0.origin, right: $0.destination) }
        } else {
            return foreignKeyMapping.map { (left: $0.destination, right: $0.origin) }
        }
    }
    
    /// Resolves the condition into SQL expressions which involve both left
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
    /// - Returns: An array of SQL expression that should be joined with
    ///   the AND operator.
    func expressions(_ db: Database, leftAlias: TableAlias, rightAlias: TableAlias) throws -> [SQLExpression] {
        return try columnMappings(db).map {
            QualifiedColumn($0.right, alias: rightAlias) == QualifiedColumn($0.left, alias: leftAlias)
        }
    }
    
    /// Resolves the condition into an SQL expression which involves only the
    /// right table.
    ///
    /// Given `right.a = left.b`, returns `right.a = 1` or
    /// `right.a IN (1, 2, 3)`.
    func filteringExpression(_ db: Database, leftRows: [Row], rightAlias: TableAlias) throws -> SQLExpression {
        if leftRows.isEmpty {
            // Degenerate case: there is no row to attach
            return false.sqlExpression
        }
        
        let columnMappings = try self.columnMappings(db)
        guard let columnMapping = columnMappings.first else {
            // Degenerate case: no joining column
            return true.sqlExpression
        }
        
        if columnMappings.count == 1 {
            // Join on a single right column.
            let rightColumn = QualifiedColumn(columnMapping.right, alias: rightAlias)
            
            // Unique database values and filter out NULL:
            var dbValues = Set(leftRows.map { $0[columnMapping.left] as DatabaseValue })
            dbValues.remove(.null)
            
            if dbValues.isEmpty {
                // Can't join
                return false.sqlExpression
            } else {
                // table.a IN (1, 2, 3, ...)
                // Sort database values for nicer output.
                return dbValues.sorted(by: <).contains(rightColumn)
            }
        } else {
            // Join on a multiple columns.
            // ((table.a = 1) AND (table.b = 2)) OR ((table.a = 3) AND (table.b = 4)) ...
            return leftRows
                .map({ leftRow in
                    // (table.a = 1) AND (table.b = 2)
                    columnMappings
                        .map({ columns -> SQLExpression in
                            let rightColumn = QualifiedColumn(columns.right, alias: rightAlias)
                            let leftValue = leftRow[columns.left] as DatabaseValue
                            return rightColumn == leftValue
                        })
                        .joined(operator: .and)
                })
                .joined(operator: .or)
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
        
        let mergedFiltersPromise: DatabasePromise<[SQLExpression]> = filtersPromise.flatMap { filters in
            DatabasePromise { try filters + other.filtersPromise.resolve($0) }
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
            filtersPromise: mergedFiltersPromise,
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
            
        case (.allPrefetched, .allPrefetched):
            // Equivalent to Record.including(all: association):
            //
            // Record
            //   .including(all: association)
            //   .including(all: association)
            return .allPrefetched
            
        case (.allPrefetched, .allNotPrefetched),
             (.allNotPrefetched, .allPrefetched):
            // Record
            //   .including(all: associationToDestinationThroughPivot)
            //   .including(all: associationToPivot)
            fatalError("Not implemented: merging a direct association and an indirect one with including(all:)")
            
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
