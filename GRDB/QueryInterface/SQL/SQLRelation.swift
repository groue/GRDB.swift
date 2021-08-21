/// A "relation", as defined by the [relational
/// terminology](https://en.wikipedia.org/wiki/Relational_database#Terminology),
/// is "a set of tuples sharing the same attributes; a set of columns and rows."
///
///     WITH ...     -- ctes
///     SELECT ...   -- selectionPromise
///     FROM ...     -- source
///     JOIN ...     -- children
///     WHERE ...    -- filterPromise
///     GROUP BY ... -- groupPromise
///     HAVING ...   -- havingExpressionPromise
///     ORDER BY ... -- ordering
///     LIMIT ...    -- limit
///
/// ## Promises
///
/// Most relation elements are "promises" which are resolved when a database
/// connection is available. This is how we can implement requests such
/// as `Record.filter(key: 1)` or `Record.orderByPrimaryKey()`: both need a
/// database connection in order to introspect the primary key. For example:
///
///     // SELECT * FROM country ORDER BY code
///     //                       ~~~~~~~~~~~~~
///     // primary key infered from the database schema
///     Country.orderByPrimaryKey()
///
/// ## Children
///
/// Relations have children. A child is a link to another relation, and
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
/// - `.all`:
///
///     Such children are prefetched using an extra SQL request:
///
///         // SELECT * FROM countries;
///         // SELECT * FROM passport
///         //  WHERE countryCode IN ('BE', 'DE', 'FR', ...);
///         Country.including(all: Country.passports)
///
/// - `.bridge`:
///
///     Such children are not joined, and not prefetched. They are used as
///     intermediate children towards a prefetched child. In the example
///     below, the country relation has a `.bridge` child to passports, and the
///     passport relation has an `.all` child to citizens.
///
///         // SELECT * FROM countries;
///         // SELECT citizens.* FROM citizens
///         // JOIN passport ON passport.citizenId = citizens.id
///         //              AND passport.countryCode IN ('BE', 'DE', 'FR', ...);
///         Country.including(all: Country.citizens)
struct SQLRelation {
    struct Child: Refinable {
        enum Kind {
            // Record.including(optional: association)
            case oneOptional
            // Record.including(required: association)
            case oneRequired
            // Record.including(all: association)
            case all
            // Record.including(all: associationThroughPivot)
            case bridge
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
            case .all, .bridge:
                return false
            }
        }
        
        init(kind: SQLRelation.Child.Kind, condition: SQLAssociationCondition, relation: SQLRelation) {
            switch kind {
            case .oneOptional, .oneRequired, .bridge:
                if relation.isDistinct {
                    fatalError("Not implemented: join an association that selects DISTINCT rows")
                }
                if relation.groupPromise != nil || relation.havingExpressionPromise != nil {
                    fatalError("Not implemented: join an association with a GROUP BY clause")
                }
                if relation.limit != nil {
                    fatalError("Not implemented: join an association with a LIMIT clause")
                }
            case .all:
                break
            }
            
            self.kind = kind
            self.condition = condition
            self.relation = relation
        }
        
        fileprivate func makeAssociationForKey(_ key: String) -> _SQLAssociation {
            let key = SQLAssociationKey.fixed(key)
            
            let cardinality: SQLAssociationCardinality
            switch kind {
            case .oneOptional, .oneRequired:
                cardinality = .toOne
            case .all, .bridge:
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
    var selectionPromise: DatabasePromise<[SQLSelection]>
    var filterPromise: DatabasePromise<SQLExpression>?
    var ordering: SQLRelation.Ordering = SQLRelation.Ordering()
    var ctes: OrderedDictionary<String, SQLCTE> = [:] // See also `allCTEs`
    var children: OrderedDictionary<String, Child> = [:]
    
    // Properties below MUST NOT be used when joining to-one associations.
    // This is guaranteed by Child.init().
    var isDistinct = false
    var groupPromise: DatabasePromise<[SQLExpression]>?
    var havingExpressionPromise: DatabasePromise<SQLExpression>?
    var limit: SQLLimit?
}

extension SQLRelation {
    /// Convenience factory methods which selects all rows from a table.
    static func all(
        fromTable tableName: String,
        selection: @escaping (Database) -> [SQLSelection] = { _ in [.allColumns] })
    -> Self
    {
        SQLRelation(
            source: SQLSource(tableName: tableName, alias: nil),
            selectionPromise: DatabasePromise(selection))
    }
}

extension SQLRelation: Refinable {
    func select(_ selection: @escaping (Database) throws -> [SQLSelection]) -> Self {
        with {
            $0.selectionPromise = DatabasePromise(selection)
        }
    }
    
    // Convenience
    func select(_ selection: [SQLSelection]) -> Self {
        select { _ in selection }
    }
    
    // Convenience
    func select(_ expressions: SQLExpression...) -> Self {
        select { _ in expressions.map { .expression($0) } }
    }
    
    /// Sets the selection, removes all selections from chidren, and clears the
    /// `isDistinct` flag.
    func selectOnly(_ selection: [SQLSelection]) -> Self {
        self
            .select(selection)
            .with {
                $0.isDistinct = false
                $0.children = children.mapValues { child in
                    child.with {
                        $0.relation = $0.relation.selectOnly([])
                    }
                }
            }
    }
    
    func annotated(with selection: @escaping (Database) throws -> [SQLSelection]) -> Self {
        with {
            let old = $0.selectionPromise
            $0.selectionPromise = DatabasePromise { db in
                try old.resolve(db) + selection(db)
            }
        }
    }
    
    // Convenience
    func annotated(with selection: [SQLSelection]) -> Self {
        annotated(with: { _ in selection })
    }
    
    func filter(_ predicate: @escaping (Database) throws -> SQLExpression) -> Self {
        with {
            if let old = $0.filterPromise {
                $0.filterPromise = DatabasePromise { db in
                    try old.resolve(db) && predicate(db)
                }
            } else {
                $0.filterPromise = DatabasePromise(predicate)
            }
        }
    }
    
    // Convenience
    func filter(_ predicate: SQLExpression) -> Self {
        filter { _ in predicate }
    }
    
    func order(_ orderings: @escaping (Database) throws -> [SQLOrdering]) -> Self {
        with {
            $0.ordering = SQLRelation.Ordering(orderings: orderings)
        }
    }
    
    func reversed() -> Self {
        with {
            $0.ordering = $0.ordering.reversed
        }
    }
    
    func unordered() -> Self {
        with {
            $0.ordering = SQLRelation.Ordering()
            $0.children = children.mapValues { child in
                child.with {
                    $0.relation = $0.relation.unordered()
                }
            }
        }
    }
    
    func group(_ expressions: @escaping (Database) throws -> [SQLExpression]) -> Self {
        with {
            $0.groupPromise = DatabasePromise(expressions)
        }
    }
    
    func having(_ predicate: @escaping (Database) throws -> SQLExpression) -> Self {
        with {
            if let old = $0.havingExpressionPromise {
                $0.havingExpressionPromise = DatabasePromise { db in
                    try old.resolve(db) && predicate(db)
                }
            } else {
                $0.havingExpressionPromise = DatabasePromise(predicate)
            }
        }
    }
    
    func aliased(_ alias: TableAlias) -> Self {
        with {
            $0.source = $0.source.aliased(alias)
        }
    }
}

extension SQLRelation {
    /// All prefetched associations (`including(all:)`), recursively
    var prefetchedAssociations: [_SQLAssociation] {
        children.flatMap { key, child -> [_SQLAssociation] in
            switch child.kind {
            case .all:
                return [child.makeAssociationForKey(key)]
            case .oneOptional, .oneRequired, .bridge:
                return child.relation.prefetchedAssociations.map { association in
                    // Remove redundant pivot child
                    let pivotKey = association.pivot.keyName
                    let child = child.with {
                        assert($0.relation.children[pivotKey] != nil)
                        $0.relation = $0.relation.removingChild(forKey: pivotKey)
                    }
                    return association.through(child.makeAssociationForKey(key))
                }
            }
        }
    }
    
    /// All common table expressions, including those of joined children.
    var allCTEs: OrderedDictionary<String, SQLCTE> {
        children.values.reduce(into: ctes) { (ctes, child) in
            switch child.kind {
            case .all, .bridge:
                break
            case .oneOptional, .oneRequired:
                ctes.merge(child.relation.allCTEs, uniquingKeysWith: { (_, new) in new })
            }
        }
    }
    
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
        // Our goal here is to append a child with a correct (singular or
        // plural) key, so that the user can decode it later under the expected
        // name.
        //
        // To know if the child key should be singular or plural, we look at the
        // association, which may be to-one or to-many, and at the kind of the
        // child, which may be joined (singular), or prefetched (plural).
        //
        // We prefer the cardinality of the child kind, but for the specific
        // case of the `.bridge` child kind, involved in prefetched
        // has-many-through associations, where we user the cardinality of
        // the association instead.
        //
        // By prefering the cardinality of the child kind in general, we make it
        // possible to join to a plural association and decode it in a singular
        // key. In the example below, we have a singular kind `.oneRequired`,
        // a plural to-many association, and we use a singular key:
        //
        //      // Decode a Player in the singular "player" key
        //      //
        //      // SELECT team.*, player.*
        //      // FROM team
        //      // JOIN player ON player.teamID = team.id
        //      Team.joining(required: Team.players)
        //
        // The exception for has-many-through associations exists because the
        // pivot of the association may be singular, and may conflict with a
        // plural association with the same association key, as in the example
        // below:
        //
        // We want the child for the "captain" in the following request to be
        // registered under the singular "player" key, and not the plural
        // "players" key, so that it does not conflict with the other child
        // named "players" (we can not have two distinct children with the
        // same key):
        //
        //     struct Team: TableRecord {
        //         static let players = hasMany(Player.self)
        //         static let captain = hasOne(Player.self).filter(Column("isCaptain") == true)
        //         static let captainAwards = hasMany(Award.self, through: captain, using: Player.awards)
        //     }
        //     struct Player: TableRecord {
        //         static let awards = hasMany(Award.self)
        //     }
        //     struct Award: TableRecord { }
        //     let request = Team
        //         .including(all: Team.captainAwards) // child "player" (with an "awards" child inside)
        //         .including(all: Team.players)       // child "players"
        let isSingular: Bool
        switch kind {
        case .oneOptional, .oneRequired:
            isSingular = true
        case .all:
            isSingular = false
        case .bridge:
            isSingular = association.destination.cardinality.isSingular
        }
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
        case .oneRequired, .oneOptional, .bridge:
            return appendingChild(for: reducedAssociation, kind: kind)
        case .all:
            // Intermediate steps of an indirect association are not prefetched:
            // use the `.bridge` kind.
            //
            // For example, the request below prefetches citizens, not
            // intermediate passports:
            //
            //      extension Country {
            //          static let passports = hasMany(Passport.self)
            //          static let citizens = hasMany(Citizens.self, through: passports, using: Passport.citizen)
            //      }
            //      let request = Country.including(all: Country.citizens)
            return appendingChild(for: reducedAssociation, kind: .bridge)
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
        with {
            $0.children.removeValue(forKey: key)
        }
    }
    
    func filteringChildren(_ included: (Child) throws -> Bool) rethrows -> Self {
        try with {
            $0.children = try $0.children.filter { (_, child) in try included(child) }
        }
    }
    
    func removingChildrenForPrefetchedAssociations() -> Self {
        filteringChildren {
            switch $0.kind {
            case .all, .bridge: return false
            case .oneRequired, .oneOptional: return true
            }
        }
    }
}

extension SQLRelation {
    func _including(all association: _SQLAssociation) -> Self {
        appendingChild(for: association, kind: .all)
    }
    
    func _including(optional association: _SQLAssociation) -> Self {
        appendingChild(for: association, kind: .oneOptional)
    }
    
    func _including(required association: _SQLAssociation) -> Self {
        appendingChild(for: association, kind: .oneRequired)
    }
    
    func _joining(optional association: _SQLAssociation) -> Self {
        // Remove association selection
        let associationWithEmptySelection = association.with {
            $0.destination.relation = $0.destination.relation.select([])
        }
        return appendingChild(for: associationWithEmptySelection, kind: .oneOptional)
    }
    
    func _joining(required association: _SQLAssociation) -> Self {
        // Remove association selection
        let associationWithEmptySelection = association.with {
            $0.destination.relation = $0.destination.relation.select([])
        }
        return appendingChild(for: associationWithEmptySelection, kind: .oneRequired)
    }
}

extension SQLRelation {
    func fetchCount(_ db: Database) throws -> Int {
        guard groupPromise == nil && limit == nil && ctes.isEmpty else {
            // SELECT ... GROUP BY ...
            // SELECT ... LIMIT ...
            // WITH ... SELECT ...
            return try fetchTrivialCount(db)
        }
    
        if children.contains(where: { $0.value.impactsParentCount }) { // TODO: not tested
            // SELECT ... FROM ... JOIN ...
            return try fetchTrivialCount(db)
        }
    
        let selection = try selectionPromise.resolve(db)
        GRDBPrecondition(!selection.isEmpty, "Can't generate SQL with empty selection")
        if selection.count == 1 {
            guard let count = selection[0].count(distinct: isDistinct) else {
                return try fetchTrivialCount(db)
            }
            var countRelation = self.unordered()
            countRelation.isDistinct = false
            switch count {
            case .all:
                countRelation = countRelation.select(.countAll)
            case .distinct(let expression):
                countRelation = countRelation.select(.countDistinct(expression))
            }
            return try QueryInterfaceRequest(relation: countRelation).fetchOne(db)!
        } else {
            // SELECT [DISTINCT] expr1, expr2, ... FROM tableName ...
    
            guard !isDistinct else {
                return try fetchTrivialCount(db)
            }
    
            // SELECT expr1, expr2, ... FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            let countRelation = unordered().select(.countAll)
            return try QueryInterfaceRequest(relation: countRelation).fetchOne(db)!
        }
    }
    
    // SELECT COUNT(*) FROM (self)
    private func fetchTrivialCount(_ db: Database) throws -> Int {
        let countRequest: SQLRequest<Int> = "SELECT COUNT(*) FROM (\(SQLSubquery.relation(unordered())))"
        return try countRequest.fetchOne(db)!
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

// MARK: - SQLSource

struct SQLSource {
    var tableName: String
    var alias: TableAlias?
    
    func aliased(_ alias: TableAlias) -> SQLSource {
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
            case terms(DatabasePromise<[SQLOrdering]>)
            case ordering(SQLRelation.Ordering)
            
            var reversed: Element {
                switch self {
                case .terms(let terms):
                    return .terms(terms.map { $0.map(\.reversed) })
                case .ordering(let ordering):
                    return .ordering(ordering.reversed)
                }
            }
            
            func qualified(with alias: TableAlias) -> Element {
                switch self {
                case .terms(let terms):
                    return .terms(terms.map { $0.map { $0.qualified(with: alias) } })
                case .ordering(let ordering):
                    return .ordering(ordering.qualified(with: alias))
                }
            }
            
            func resolve(_ db: Database) throws -> [SQLOrdering] {
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
        
        init(orderings: @escaping (Database) throws -> [SQLOrdering]) {
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
        
        func resolve(_ db: Database) throws -> [SQLOrdering] {
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
    case foreignKey(SQLForeignKeyCondition)
    
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
    case expression((_ left: TableAlias, _ right: TableAlias) -> SQLExpression?)
    
    /// The condition that does not constrain the two associated tables
    /// in any way.
    static let none = expression({ _, _ in nil })
    
    func reversed(to destinationTable: String) -> SQLAssociationCondition {
        switch self {
        case let .foreignKey(foreignKey):
            return .foreignKey(foreignKey.reversed(to: destinationTable))
        case let .expression(condition):
            return .expression { condition($1, $0) }
        }
    }
    
    func joinExpression(
        _ db: Database,
        leftAlias: TableAlias,
        rightAlias: TableAlias)
    throws -> SQLExpression?
    {
        switch self {
        case let .expression(condition):
            return condition(leftAlias, rightAlias)
        case let .foreignKey(foreignKey):
            return try foreignKey
                .joinMapping(db, from: leftAlias.tableName)
                .joinExpression(leftAlias: leftAlias, rightAlias: rightAlias)
        }
    }
}

/// An association condition based on a foreign key.
struct SQLForeignKeyCondition: Equatable {
    /// The destination table of an association.
    ///
    /// In `Author.hasMany(Book.self)`, the destination is `book`.
    var destinationTable: String
    
    /// A user-provided foreign key. When nil, we introspect the database in
    /// order to look for a foreign key in the schema.
    var foreignKey: ForeignKey?
    
    /// `originIsLeft` is true if the table at the origin of the foreign key is
    /// on the left of the sql JOIN operator.
    ///
    /// Let's consider the `book.authorId -> author.id` foreign key.
    /// Its origin table is `book`.
    ///
    /// The origin table `book` is on the left of the JOIN operator for
    /// the `BelongsTo` association:
    ///
    ///     -- Book.including(required: Book.author)
    ///     SELECT ... FROM book JOIN author ON author.id = book.authorId
    ///                     ~~~~ ~~~~
    ///
    /// The origin table `book`is on the right of the JOIN operator for
    /// the `HasMany` and `HasOne` associations:
    ///
    ///     -- Author.including(required: Author.books)
    ///     SELECT ... FROM author JOIN book ON author.id = book.authorId
    ///                            ~~~~ ~~~~
    ///
    /// See also `ForeignKeyMapping.joinMapping(originIsLeft:)`
    var originIsLeft: Bool
    
    func reversed(to destinationTable: String) -> SQLForeignKeyCondition {
        SQLForeignKeyCondition(
            destinationTable: destinationTable,
            foreignKey: foreignKey,
            originIsLeft: !originIsLeft)
    }
    
    /// Turns the foreign key condition into a `JoinMapping` that can feed an
    /// SQL JOIN clause.
    func joinMapping(_ db: Database, from originTable: String) throws -> JoinMapping {
        try foreignKeyRequest(from: originTable)
            .fetchForeignKeyMapping(db)
            .joinMapping(originIsLeft: originIsLeft)
    }
    
    private func foreignKeyRequest(from originTable: String) -> SQLForeignKeyRequest {
        // Convert association destination/origin to
        // foreign key destination/origin.
        if originIsLeft {
            return SQLForeignKeyRequest(
                originTable: originTable,
                destinationTable: destinationTable,
                foreignKey: foreignKey)
        } else {
            return SQLForeignKeyRequest(
                originTable: destinationTable,
                destinationTable: originTable,
                foreignKey: foreignKey)
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
        
        // SQLite doesn't match foreign keys on NULL: https://www.sqlite.org/foreignkeys.html
        // > The foreign key constraint is satisfied if for each row in the
        // > child table either one or more of the child key columns are NULL,
        // > or there exists a row in the parent table for which each parent key
        // > column contains a value equal to the value in its associated child
        // > key column.
        //
        // Since a single NULL value satisfies the foreign key constraint
        // without requiring a matching matching parent row, below we'll ignore
        // left rows (children) that attempt at matching on NULL.
        if mappings.count == 1 {
            // Join on a single right column.
            // table.a IN (1, 2, 3, ...)
            
            // Unique database values and filter out NULL because SQLite doesn't
            // match foreign keys on NULL
            let leftIndex = mapping.leftIndex
            var dbValues = Set(leftRows.map { $0.databaseValue(at: leftIndex) })
            dbValues.remove(.null)
            
            // Sort database values for nicer output.
            return dbValues.sorted(by: <).contains(mapping.rightColumn)
        } else {
            // Join on a multiple columns.
            // ((table.a = 1) AND (table.b = 2)) OR ((table.a = 3) AND (table.b = 4)) ...
            return leftRows
                .compactMap { leftRow -> SQLExpression? in
                    // (table.a = 1) AND (table.b = 2)
                    var conditions: [SQLExpression] = []
                    for mapping in mappings {
                        let dbValue = leftRow.databaseValue(at: mapping.leftIndex)
                        if dbValue.isNull {
                            // SQLite doesn't match foreign keys on NULL:
                            // give up this left row.
                            return nil
                        }
                        conditions.append(mapping.rightColumn == dbValue)
                    }
                    return conditions.joined(operator: .and)
                }
                .joined(operator: .or)
        }
    }
    
    /// Resolves the condition into an SQL expression which involve both left
    /// and right tables.
    ///
    ///     SELECT * FROM left JOIN right ON (right.a = left.b)
    ///                                      <---------------->
    ///
    /// - parameter leftAlias: A TableAlias for the table on the left of the
    ///   JOIN operator.
    /// - parameter rightAlias: A TableAlias for the table on the right of the
    ///   JOIN operator.
    func joinExpression(leftAlias: TableAlias, rightAlias: TableAlias) -> SQLExpression {
        map { rightAlias[$0.right] == leftAlias[$0.left] }.joined(operator: .and)
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
    func databaseValue(at index: DummyIndex) -> DatabaseValue { DatabaseValue(storage: .int64(1)) }
}

/// Row has columns
extension Row: ColumnAddressable {
    func databaseValue(at index: Int) -> DatabaseValue { self[index] }
}

/// PersistenceContainer has columns
extension PersistenceContainer: ColumnAddressable {
    func index(forColumn column: String) -> String? { column }
    func databaseValue(at column: String) -> DatabaseValue {
        self[caseInsensitive: column]?.databaseValue ?? .null
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
        // Source
        guard let mergedSource = source.merged(with: other.source) else {
            // can't merge
            return nil
        }
        
        // Filter: merge with AND
        let mergedFilterPromise: DatabasePromise<SQLExpression>?
        switch (filterPromise, other.filterPromise) {
        case let (lhs?, rhs?):
            mergedFilterPromise = DatabasePromise {
                try lhs.resolve($0) && rhs.resolve($0)
            }
        case let (nil, promise?), let (promise?, nil):
            mergedFilterPromise = promise
        case (nil, nil):
            mergedFilterPromise = nil
        }
        
        // Children: merge recursively
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
        
        // Selection: replace unless empty
        let mergedSelectionPromise = DatabasePromise { db -> [SQLSelection] in
            let otherSelection = try other.selectionPromise.resolve(db)
            if otherSelection.isEmpty {
                return try self.selectionPromise.resolve(db)
            } else {
                return otherSelection
            }
        }
        
        // Ordering: prefer other
        let mergedOrdering = other.ordering.isEmpty ? ordering : other.ordering
        
        // Distinct
        let mergedDistinct = isDistinct || other.isDistinct
        
        // Grouping: prefer other
        let mergedGroupPromise = other.groupPromise ?? groupPromise
        
        // Having: merge with AND
        let mergedHavingExpressionPromise: DatabasePromise<SQLExpression>?
        switch (havingExpressionPromise, other.havingExpressionPromise) {
        case let (lhs?, rhs?):
            mergedHavingExpressionPromise = DatabasePromise {
                try lhs.resolve($0) && rhs.resolve($0)
            }
        case let (nil, promise?), let (promise?, nil):
            mergedHavingExpressionPromise = promise
        case (nil, nil):
            mergedHavingExpressionPromise = nil
        }
        
        // Limit: prefer other
        let mergedLimit = other.limit ?? limit
        
        // CTEs: merge & prefer other
        let mergedCTEs = ctes.merging(other.ctes, uniquingKeysWith: { (_, other) in other })
        
        return SQLRelation(
            source: mergedSource,
            selectionPromise: mergedSelectionPromise,
            filterPromise: mergedFilterPromise,
            ordering: mergedOrdering,
            ctes: mergedCTEs,
            children: mergedChildren,
            isDistinct: mergedDistinct,
            groupPromise: mergedGroupPromise,
            havingExpressionPromise: mergedHavingExpressionPromise,
            limit: mergedLimit)
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
        case let (.foreignKey(lhs), .foreignKey(rhs)):
            if lhs == rhs {
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
            
        case (.all, .all):
            // Equivalent to Record.including(all: association):
            //
            // Record
            //   .including(all: association)
            //   .including(all: association)
            return .all
            
        case (.all, .bridge),
             (.bridge, .all):
            // Record
            //   .including(all: associationToDestinationThroughPivot)
            //   .including(all: associationToPivot)
            fatalError("Not implemented: merging a direct association and an indirect one with including(all:)")
            
        case (.bridge, .bridge):
            // Equivalent to Record.including(all: association)
            //
            // Record
            //   .including(all: association)
            //   .including(all: association)
            return .bridge
            
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
