// MARK: - _SQLAssociation

/// An SQL association is a non-empty chain of steps which starts at the
/// "pivot" and ends on the "destination":
///
///     // SELECT origin.*, destination.*
///     // FROM origin
///     // JOIN pivot ON ...
///     // JOIN ...
///     // JOIN ...
///     // JOIN destination ON ...
///     Origin.including(required: association)
///
/// For direct associations such as BelongTo or HasMany, the chain contains a
/// single element, the "destination", without intermediate step:
///
///     // "Origin" belongsTo "destination":
///     // SELECT origin.*, destination.*
///     // FROM origin
///     // JOIN destination ON destination.originId = origin.id
///     let association = Origin.belongsTo(Destination.self)
///     Origin.including(required: association)
///
/// Indirect associations such as HasManyThrough have one or several
/// intermediate steps:
///
///     // "Origin" has many "destination" through "pivot":
///     // SELECT origin.*, destination.*
///     // FROM origin
///     // JOIN pivot ON pivot.originId = origin.id
///     // JOIN destination ON destination.id = pivot.destinationId
///     let association = Origin.hasMany(
///         Destination.self,
///         through: Origin.hasMany(Pivot.self),
///         via: Pivot.belongsTo(Destination.self))
///     Origin.including(required: association)
///
///     // "Origin" has many "destination" through "pivot1" and  "pivot2":
///     // SELECT origin.*, destination.*
///     // FROM origin
///     // JOIN pivot1 ON pivot1.originId = origin.id
///     // JOIN pivot2 ON pivot2.pivot1Id = pivot1.id
///     // JOIN destination ON destination.id = pivot.destinationId
///     let association = Origin.hasMany(
///         Destination.self,
///         through: Origin.hasMany(Pivot1.self),
///         via: Pivot1.hasMany(
///             Destination.self,
///             through: Pivot1.hasMany(Pivot2.self),
///             via: Pivot2.belongsTo(Destination.self)))
///     Origin.including(required: association)
///
/// :nodoc:
public struct _SQLAssociation {
    // All steps, from pivot to destination. Never empty.
    private(set) var steps: [SQLAssociationStep]
    var keyPath: [String] { steps.map(\.keyName) }
    
    var destination: SQLAssociationStep {
        get { steps[steps.count - 1] }
        set { steps[steps.count - 1] = newValue }
    }
    
    var pivot: SQLAssociationStep {
        get { steps[0] }
        set { steps[0] = newValue }
    }
    
    init(steps: [SQLAssociationStep]) {
        assert(!steps.isEmpty)
        self.steps = steps
    }
    
    init(
        key: SQLAssociationKey,
        condition: SQLAssociationCondition,
        relation: SQLRelation,
        cardinality: SQLAssociationCardinality)
    {
        let step = SQLAssociationStep(
            key: key,
            condition: condition,
            relation: relation,
            cardinality: cardinality)
        self.init(steps: [step])
    }
    
    /// Changes the destination key
    func forDestinationKey(_ key: SQLAssociationKey) -> Self {
        with {
            $0.destination.key = key
        }
    }
    
    /// Returns a new association
    func through(_ other: _SQLAssociation) -> Self {
        _SQLAssociation(steps: other.steps + steps)
    }
    
    /// Returns the destination of the association, reversing the association
    /// up to the pivot.
    ///
    /// This method feeds `TableRecord.request(for:)`, and allows
    /// `including(all:)` to prefetch associated records.
    func destinationRelation() -> SQLRelation {
        if steps.count == 1 {
            return destination.relation
        }
        
        // This is an indirect join from origin to destination, through
        // some intermediate steps:
        //
        // SELECT destination.*
        // FROM destination
        // JOIN pivot ON (pivot.destinationId = destination.id) AND (pivot.originId = 1)
        //
        // let association = Origin.hasMany(
        //     Destination.self,
        //     through: Origin.hasMany(Pivot.self),
        //     via: Pivot.belongsTo(Destination.self))
        // Origin(id: 1).request(for: association)
        let reversedSteps = zip(steps, steps.dropFirst())
            .map { (step, nextStep) -> SQLAssociationStep in
                // Intermediate steps are not selected, and including(all:)
                // children are useless:
                let relation = step.relation
                    .selectOnly([])
                    .removingChildrenForPrefetchedAssociations()
                
                // Don't interfere with user-defined keys that could be added later
                let key = step.key.with {
                    $0.baseName = "grdb_\($0.baseName)"
                }
                
                return SQLAssociationStep(
                    key: key,
                    condition: nextStep.condition.reversed(to: step.relation.source.tableName),
                    relation: relation,
                    cardinality: .toOne)
            }
            .reversed()
        let reversedAssociation = _SQLAssociation(steps: Array(reversedSteps))
        return destination.relation.appendingChild(for: reversedAssociation, kind: .oneRequired)
    }
}

extension _SQLAssociation: Refinable { }

struct SQLAssociationStep: Refinable {
    var key: SQLAssociationKey
    var condition: SQLAssociationCondition
    var relation: SQLRelation
    var cardinality: SQLAssociationCardinality
    
    var keyName: String { key.name(singular: cardinality.isSingular) }
}

enum SQLAssociationCardinality {
    case toOne
    case toMany
    
    var isSingular: Bool {
        switch self {
        case .toOne:
            return true
        case .toMany:
            return false
        }
    }
}

// MARK: - SQLAssociationKey

/// Associations are meant to be consumed, most often into Decodable records.
///
/// Those records have singular or plural property names, and we want
/// associations to be able to fill those singular or plural names
/// automatically, so that the user does not have to perform explicit
/// decoding configuration.
///
/// Those plural or singular names are not decided when the association is
/// defined. For example, the Author.books association, which looks plural, may
/// actually generate "book" or "books" depending on the context:
///
///     struct Author: TableRecord {
///         static let books = hasMany(Book.self)
///     }
///     struct Book: TableRecord {
///     }
///
///     // "books"
///     struct AuthorInfo: FetchableRecord, Decodable {
///         var author: Author
///         var books: [Book]
///     }
///     let request = Author.including(all: Author.books)
///     let authorInfos = try AuthorInfo.fetchAll(db, request)
///
///     "book"
///     struct AuthorInfo: FetchableRecord, Decodable {
///         var author: Author
///         var book: Book
///     }
///     let request = Author.including(required: Author.books)
///     let authorInfos = try AuthorInfo.fetchAll(db, request)
///
///     "bookCount"
///     struct AuthorInfo: FetchableRecord, Decodable {
///         var author: Author
///         var bookCount: Int
///     }
///     let request = Author.annotated(with: Author.books.count)
///     let authorInfos = try AuthorInfo.fetchAll(db, request)
///
/// The SQLAssociationKey type aims at providing the necessary support for
/// those various inflections.
enum SQLAssociationKey: Refinable {
    /// A key that is inflected in singular and plural contexts.
    ///
    /// For example:
    ///
    ///     struct Author: TableRecord {
    ///         static let databaseTableName = "authors"
    ///     }
    ///     struct Book: TableRecord {
    ///         let author = belongsTo(Author.self)
    ///     }
    ///
    ///     let request = Book.including(required: Book.author)
    ///     let row = try Row.fetchOne(db, request)!
    ///     row.scopes["author"]  // singularized "authors" table name
    case inflected(String)
    
    /// A key that is inflected in plural contexts, but stricly honors
    /// user-provided name in singular contexts.
    ///
    /// For example:
    ///
    ///     struct Country: TableRecord {
    ///         let demographics = hasOne(Demographics.self, key: "demographics")
    ///     }
    ///
    ///     let request = Country.including(required: Country.demographics)
    ///     let row = try Row.fetchOne(db, request)!
    ///     row.scopes["demographics"]  // not singularized
    case fixedSingular(String)
    
    /// A key that is inflected in singular contexts, but stricly honors
    /// user-provided name in plural contexts.
    /// See .inflected and .fixedSingular for some context.
    case fixedPlural(String)
    
    /// A key that is never inflected.
    case fixed(String)
    
    var baseName: String {
        get {
            switch self {
            case let .inflected(name),
                 let .fixedSingular(name),
                 let .fixedPlural(name),
                 let .fixed(name):
                return name
            }
        }
        set {
            switch self {
            case .inflected:
                self = .inflected(newValue)
            case .fixedSingular:
                self = .fixedSingular(newValue)
            case .fixedPlural:
                self = .fixedPlural(newValue)
            case .fixed:
                self = .fixed(newValue)
            }
        }
    }
    
    func name(singular: Bool) -> String {
        if singular {
            return singularizedName
        } else {
            return pluralizedName
        }
    }
    
    var pluralizedName: String {
        switch self {
        case .inflected(let name):
            return name.pluralized
        case .fixedSingular(let name):
            return name.pluralized
        case .fixedPlural(let name):
            return name
        case .fixed(let name):
            return name
        }
    }
    
    var singularizedName: String {
        switch self {
        case .inflected(let name):
            return name.singularized
        case .fixedSingular(let name):
            return name
        case .fixedPlural(let name):
            return name.singularized
        case .fixed(let name):
            return name
        }
    }
}
