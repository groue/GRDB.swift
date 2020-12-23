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
    struct Child: Refinable {
        enum Kind {
            // Record.including(optional: association)
            case oneOptional
            // Record.including(required: association)
            case oneRequired
            // Record.including(all: association)
            case allPrefetched
            // Record.including(all: associationThroughPivot)
            case allNotPrefetched
            
            var isSingular: Bool {
                switch self {
                case .oneOptional, .oneRequired:
                    return true
                case .allPrefetched, .allNotPrefetched:
                    return false
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
        
        fileprivate func makeAssociationForKey(_ key: String) -> _SQLAssociation {
            let key = SQLAssociationKey.fixed(key)
            
            let cardinality: SQLAssociationCardinality
            switch kind {
            case .oneOptional, .oneRequired:
                cardinality = .toOne
            case .allPrefetched, .allNotPrefetched:
                cardinality = .toMany
            }
            
            return _SQLAssociation(
                key: key,
                condition: condition,
                relation: relation,
                cardinality: cardinality)
        }
    }
    
    var source: SQLSource
    var selectionPromise: DatabasePromise<[SQLSelectable]> = DatabasePromise(value: [])
    // Filter is an array of expressions that we'll join with the AND operator.
    // This gives nicer output in generated SQL: `(a AND b AND c)` instead of
    // `((a AND b) AND c)`.
    var filtersPromise: DatabasePromise<[SQLExpression]> = DatabasePromise(value: [])
    var ordering: SQLRelation.Ordering = SQLRelation.Ordering()
    var children: OrderedDictionary<String, Child> = [:]
    
    var prefetchedAssociations: [_SQLAssociation] {
        children.flatMap { key, child -> [_SQLAssociation] in
            switch child.kind {
            case .allPrefetched:
                return [child.makeAssociationForKey(key)]
            case .oneOptional, .oneRequired, .allNotPrefetched:
                return child.relation.prefetchedAssociations.map { association in
                    // Remove redundant pivot child
                    let pivotKey = association.pivot.keyName
                    let child = child.map(\.relation) { relation in
                        assert(relation.children[pivotKey] != nil)
                        return relation.removingChild(forKey: pivotKey)
                    }
                    return association.through(child.makeAssociationForKey(key))
                }
            }
        }
    }
}

extension SQLRelation: Refinable {
    func select(_ selection: @escaping (Database) throws -> [SQLSelectable]) -> Self {
        with(\.selectionPromise, DatabasePromise(selection))
    }
    
    // Convenience
    func select(_ selection: [SQLSelectable]) -> Self {
        select { _ in selection }
    }
    
    /// Removes all selections from chidren
    func selectOnly(_ selection: [SQLSelectable]) -> Self {
        select(selection).map(\.children, { $0.mapValues { $0.map(\.relation, { $0.selectOnly([]) }) } })
    }
    
    func annotated(with selection: @escaping (Database) throws -> [SQLSelectable]) -> Self {
        map(\.selectionPromise) { selectionPromise in
            DatabasePromise { db in
                try selectionPromise.resolve(db) + selection(db)
            }
        }
    }
    
    // Convenience
    func annotated(with selection: [SQLSelectable]) -> Self {
        annotated(with: { _ in selection })
    }
    
    func order(_ orderings: @escaping (Database) throws -> [SQLOrderingTerm]) -> Self {
        with(\.ordering, SQLRelation.Ordering(orderings: orderings))
    }
    
    func reversed() -> Self {
        map(\.ordering, \.reversed)
    }
    
    func unordered() -> Self {
        self.with(\.ordering, SQLRelation.Ordering())
            .map(\.children, { $0.mapValues { $0.map(\.relation, { $0.unordered() }) } })
    }
    
    func qualified(with alias: TableAlias) -> Self {
        map(\.source) { $0.qualified(with: alias) }
    }
}

extension SQLRelation: FilteredRequest {
    func filter(_ predicate: @escaping (Database) throws -> SQLExpressible) -> Self {
        map(\.filtersPromise) { filtersPromise in
            DatabasePromise { db in
                try filtersPromise.resolve(db) + [predicate(db).sqlExpression]
            }
        }
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
    ///     let sqlAssociation = Origin.destination._sqlAssociation
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
    func appendingChild(for association: _SQLAssociation, kind: SQLRelation.Child.Kind) -> Self {
        // Preserve association cardinality in intermediate steps of
        // including(all:), and force desired cardinality otherwize
        let isSingular = (kind == .allNotPrefetched)
            ? association.destination.cardinality.isSingular
            : kind.isSingular
        let childKey = association.destination.key.name(singular: isSingular)
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
        var reducedAssociation = _SQLAssociation(steps: Array(initialSteps))
        
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
    
    private func appendingChild(_ child: SQLRelation.Child, forKey key: String) -> Self {
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
    
    func removingChild(forKey key: String) -> Self {
        mapInto(\.children) { $0.removeValue(forKey: key) }
    }
    
    func filteringChildren(_ included: (Child) throws -> Bool) rethrows -> Self {
        try map(\.children) { try $0.filter { try included($1) } }
    }
    
    func removingChildrenForPrefetchedAssociations() -> Self {
        filteringChildren {
            switch $0.kind {
            case .allPrefetched, .allNotPrefetched: return false
            case .oneRequired, .oneOptional: return true
            }
        }
    }
}

extension SQLRelation: _JoinableRequest {
    func _including(all association: _SQLAssociation) -> Self {
        appendingChild(for: association, kind: .allPrefetched)
    }
    
    func _including(optional association: _SQLAssociation) -> Self {
        appendingChild(for: association, kind: .oneOptional)
    }
    
    func _including(required association: _SQLAssociation) -> Self {
        appendingChild(for: association, kind: .oneRequired)
    }
    
    func _joining(optional association: _SQLAssociation) -> Self {
        appendingChild(for: association.map(\.destination.relation, { $0.select([]) }), kind: .oneOptional)
    }
    
    func _joining(required association: _SQLAssociation) -> Self {
        appendingChild(for: association.map(\.destination.relation, { $0.select([]) }), kind: .oneRequired)
    }
}

// MARK: - SQLSource

struct SQLSource {
    var tableName: String
    var alias: TableAlias?
    
    func qualified(with alias: TableAlias) -> SQLSource {
        if let sourceAlias = self.alias {
            alias.becomeProxy(of: sourceAlias)
            return self
        } else {
            alias.setTableName(tableName)
            return SQLSource(tableName: tableName, alias: alias)
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
                    return .terms(terms.map { $0.map(\._reversed) })
                case .ordering(let ordering):
                    return .ordering(ordering.reversed)
                }
            }
            
            func qualified(with alias: TableAlias) -> Element {
                switch self {
                case .terms(let terms):
                    return .terms(terms.map { $0.map { $0._qualifiedOrdering(with: alias) } })
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
        
        var isEmpty: Bool { elements.isEmpty }
        
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
            Ordering(
                elements: elements,
                isReversed: !isReversed)
        }
        
        func qualified(with alias: TableAlias) -> Ordering {
            Ordering(
                elements: elements.map { $0.qualified(with: alias) },
                isReversed: isReversed)
        }
        
        func appending(_ ordering: Ordering) -> Ordering {
            Ordering(
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

/// The condition that links two tables of an association.
///
/// Conditions can feed a `JOIN` clause:
///
///     // SELECT ... FROM book JOIN author ON author.id = book.authorId
///     //                                     ~~~~~~~~~~~~~~~~~~~~~~~~~
///     Book.including(required: Book.author)
///
/// Conditions help eager loading of to-many associations:
///
///     // SELECT * FROM author WHERE ...
///     // SELECT * FROM book WHERE author.id IN (1, 2, 3)
///     //                          ~~~~~~~~~~~~~~~~~~~~~~
///     Author.filter(...).including(all: Author.books)
///
/// Conditions help fetching associated records:
///
///     // SELECT * FROM book WHERE author.id = 1
///     //                          ~~~~~~~~~~~~~
///     author.request(for: Author.books)
enum SQLAssociationCondition {
    /// A condition based on a foreign key.
    ///
    /// originIsLeft is true if the table at the origin of the foreign key is on
    /// the left of the sql JOIN operator.
    ///
    /// Let's consider the `book.authorId -> author.id` foreign key.
    /// Its origin table is `book`.
    ///
    /// The origin table `book` is on the left of the JOIN operator for
    /// the BelongsTo association:
    ///
    ///     -- Book.including(required: Book.author)
    ///     SELECT ... FROM book JOIN author ON author.id = book.authorId
    ///                                         ~~~~~~~~~~~~~~~~~~~~~~~~~
    ///
    /// The origin table `book`is on the right of the JOIN operator for
    /// the HasMany and HasOne associations:
    ///
    ///     -- Author.including(required: Author.books)
    ///     SELECT ... FROM author JOIN book ON author.id = book.authorId
    ///                                         ~~~~~~~~~~~~~~~~~~~~~~~~~
    case foreignKey(request: SQLForeignKeyRequest, originIsLeft: Bool)
    
    /// A condition based on a function that returns an expression.
    ///
    /// The two arguments `left` and `right` are aliases for the left and right
    /// tables in a `JOIN` clause:
    ///
    ///     // WITH bonus AS (...)
    ///     // SELECT * FROM player
    ///     // JOIN bonus ON player.id = bonus.playerID
    ///     //               ~~~~~~~~~~~~~~~~~~~~~~~~~~
    ///     let bonus = CommonTableExpression(...)
    ///     let association = Player.association(to: bonus, on: { player, bonus in
    ///         player[Column("id")] == bonus[Column("playerID")]
    ///     })
    ///     Player.with(bonus).joining(required: association)
    case expression((_ left: TableAlias, _ right: TableAlias) -> SQLExpressible)
    
    /// The condition that does not constrain the two associated tables
    /// in any way.
    static let none = expression({ _, _ in true })
    
    var reversed: SQLAssociationCondition {
        switch self {
        case let .foreignKey(request: request, originIsLeft: originIsLeft):
            return .foreignKey(request: request, originIsLeft: !originIsLeft)
        case let .expression(condition):
            return .expression { condition($1, $0) }
        }
    }
}

extension JoinMapping {
    /// Resolves the mapping into an SQL expression which involves only the
    /// right table, and feeds left columns from `leftRows`.
    ///
    /// For example, given `[(left: "id", right: "authorID")]`,
    /// returns `right.authorID = 1` or `right.authorID IN (1, 2, 3)`.
    ///
    /// - precondition: leftRows is not empty.
    /// - precondition: leftRows contains all mapping left columns.
    /// - precondition: All rows have the same layout: a column index returned
    ///   by `index(forColumn:)` refers to the same column in all rows.
    func joinExpression<Rows>(leftRows: Rows)
    -> SQLExpression
    where Rows: Collection, Rows.Element: ColumnAddressable
    {
        guard let firstLeftRow = leftRows.first else {
            // We could return `false.sqlExpression`.
            //
            // But we need to take care of database observation, and generate
            // SQL that involves all used columns. Consider using a `DummyRow`.
            fatalError("Provide at least one left row, or this method can't generate SQL that can be observed.")
        }
        
        let mappings: [(leftIndex: Rows.Element.ColumnIndex, rightColumn: Column)] = map { mapping in
            guard let leftIndex = firstLeftRow.index(forColumn: mapping.left) else {
                fatalError("Missing column: \(mapping.left)")
            }
            return (leftIndex: leftIndex, rightColumn: Column(mapping.right))
        }
        guard let mapping = mappings.first else {
            // Degenerate case: no joining column
            return true.sqlExpression
        }
        
        if mappings.count == 1 {
            // Join on a single right column.
            
            // Unique database values and filter out NULL:
            let leftIndex = mapping.leftIndex
            var dbValues = Set(leftRows.map { $0.databaseValue(at: leftIndex) })
            dbValues.remove(.null) // SQLite doesn't match foreign keys on NULL
            // table.a IN (1, 2, 3, ...)
            // Sort database values for nicer output.
            return dbValues.sorted(by: <).contains(mapping.rightColumn)
        } else {
            // Join on a multiple columns.
            // ((table.a = 1) AND (table.b = 2)) OR ((table.a = 3) AND (table.b = 4)) ...
            return leftRows
                .map({ leftRow in
                    // (table.a = 1) AND (table.b = 2)
                    mappings
                        .map({ mapping -> SQLExpression in
                            let leftValue = leftRow.databaseValue(at: mapping.leftIndex)
                            // Force `=` operator, because SQLite doesn't match foreign keys on NULL
                            return SQLExpressionEqual(.equal, mapping.rightColumn, leftValue)
                        })
                        .joined(operator: .and)
                })
                .joined(operator: .or)
        }
    }
    
    /// Resolves the condition into SQL expressions which involve both left
    /// and right tables.
    ///
    ///     SELECT * FROM left JOIN right ON (right.a = left.b)
    ///                                      <---------------->
    ///
    /// - parameter leftAlias: A TableAlias for the table on the left of the
    ///   JOIN operator.
    /// - Returns: An array of SQL expression that should be joined with
    ///   the AND operator and qualified with the right table.
    func joinExpressions(leftAlias: TableAlias) -> [SQLExpression] {
        map {
            Column($0.right) == SQLQualifiedColumn($0.left, alias: leftAlias)
        }
    }
}

/// A protocol for row-like containers
protocol ColumnAddressable {
    associatedtype ColumnIndex
    func index(forColumn column: String) -> ColumnIndex?
    func databaseValue(at index: ColumnIndex) -> DatabaseValue
}

/// A "row" that contains a dummy value for all columns
struct DummyRow: ColumnAddressable {
    struct DummyIndex { }
    func index(forColumn column: String) -> DummyIndex? { DummyIndex() }
    @inline(__always)
    func databaseValue(at index: DummyIndex) -> DatabaseValue { DatabaseValue(storage: .int64(1)) }
}

/// Row has columns
extension Row: ColumnAddressable {
    @inline(__always)
    func databaseValue(at index: Int) -> DatabaseValue { self[index] }
}

/// PersistenceContainer has columns
extension PersistenceContainer: ColumnAddressable {
    func index(forColumn column: String) -> String? { column }
    @inline(__always)
    func databaseValue(at column: String) -> DatabaseValue {
        guard let value = self[caseInsensitive: column] else {
            fatalError("Missing column: \(column)")
        }
        return value.databaseValue
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
    func merged(with other: SQLRelation) -> Self? {
        guard let mergedSource = source.merged(with: other.source) else {
            // can't merge
            return nil
        }
        
        let mergedFiltersPromise = DatabasePromise<[SQLExpression]> { db in
            try self.filtersPromise.resolve(db) + other.filtersPromise.resolve(db)
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
        let mergedSelectionPromise = DatabasePromise { db -> [SQLSelectable] in
            let otherSelection = try other.selectionPromise.resolve(db)
            if otherSelection.isEmpty {
                return try self.selectionPromise.resolve(db)
            } else {
                return otherSelection
            }
        }
        
        // replace ordering unless empty
        let mergedOrdering = other.ordering.isEmpty ? ordering : other.ordering
        
        return SQLRelation(
            source: mergedSource,
            selectionPromise: mergedSelectionPromise,
            filtersPromise: mergedFiltersPromise,
            ordering: mergedOrdering,
            children: mergedChildren)
    }
}

extension SQLSource {
    /// Returns nil if sources can't be merged (conflict in tables, aliases...)
    func merged(with other: SQLSource) -> SQLSource? {
        guard tableName == other.tableName else {
            // can't merge
            return nil
        }
        switch (alias, other.alias) {
        case (nil, nil):
            return SQLSource(tableName: tableName, alias: nil)
        case let (alias?, nil), let (nil, alias?):
            return SQLSource(tableName: tableName, alias: alias)
        case let (alias?, otherAlias?):
            guard let mergedAlias = alias.merged(with: otherAlias) else {
                // can't merge
                return nil
            }
            return SQLSource(tableName: tableName, alias: mergedAlias)
        }
    }
}

extension SQLAssociationCondition {
    func merged(with other: SQLAssociationCondition) -> Self? {
        switch (self, other) {
        case let (.foreignKey(lr, lo), .foreignKey(rr, ro)):
            if lr == rr && lo == ro {
                return self
            } else {
                // can't merge
                return nil
            }
        case let (.expression, .expression(rhs)):
            // Can't compare functions: the last one wins
            return .expression(rhs)
        default:
            // can't merge
            return nil
        }
    }
}

extension SQLRelation.Child {
    /// Returns nil if joins can't be merged (conflict in condition, relation...)
    func merged(with other: SQLRelation.Child) -> Self? {
        guard let mergedCondition = condition.merged(with: other.condition) else {
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
            condition: mergedCondition,
            relation: mergedRelation)
    }
}

extension SQLRelation.Child.Kind {
    /// Returns nil if kinds can't be merged
    func merged(with other: SQLRelation.Child.Kind) -> Self? {
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
