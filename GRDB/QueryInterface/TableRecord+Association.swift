extension TableRecord {
    /// Creates a "Belongs To" association between Self and the
    /// destination type.
    ///
    ///     struct Author: TableRecord { ... }
    ///     struct Book: TableRecord {
    ///         static let author = belongsTo(Author.self)
    ///     }
    ///
    /// The association will let you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all books with their authors:
    ///     let request = Book.including(optional: Book.author)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct BookInfo: FetchableRecord, Decodable {
    ///         var book: Book
    ///         var author: Author?
    ///     }
    ///
    ///     let bookInfos = try dbQueue.read { db in
    ///         return try BookInfo.fetchAll(db, request)
    ///     }
    ///     for bookInfo in bookInfos {
    ///         print("\(bookInfo.book.title) by \(bookInfo.author.name)")
    ///     }
    ///
    /// It is recommended that you define, alongside the static association, a
    /// property with the same name:
    ///
    ///     struct Book: TableRecord, EncodableRecord {
    ///         static let author = belongsTo(Author.self)
    ///         var author: QueryInterfaceRequest<Author> {
    ///             return request(for: Book.author)
    ///         }
    ///     }
    ///
    /// This property will let you navigate from the source type to the
    /// destination type:
    ///
    ///     try dbQueue.read { db in
    ///         let book: Book = ...
    ///         let author = try book.author.fetchOne(db) // Author?
    ///     }
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key to the destination table, or when the schema defines several
    ///       foreign keys to the destination table.
    public static func belongsTo<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> BelongsToAssociation<Self, Destination>
    {
        return BelongsToAssociation(key: key, using: foreignKey)
    }
    
    /// Creates a "Has many" association between Self and the
    /// destination type.
    ///
    ///     struct Book: TableRecord { ... }
    ///     struct Author: TableRecord {
    ///         static let books = hasMany(Book.self)
    ///     }
    ///
    /// The association will let you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all (author, book) pairs:
    ///     let request = Author.including(required: Author.books)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct Authorship: FetchableRecord, Decodable {
    ///         var author: Author
    ///         var book: Book
    ///     }
    ///
    ///     let authorships = try dbQueue.read { db in
    ///         return try Authorship.fetchAll(db, request)
    ///     }
    ///     for authorship in authorships {
    ///         print("\(authorship.author.name) wrote \(authorship.book.title)")
    ///     }
    ///
    /// It is recommended that you define, alongside the static association, a
    /// property with the same name:
    ///
    ///     struct Author: TableRecord, EncodableRecord {
    ///         static let books = hasMany(Book.self)
    ///         var books: QueryInterfaceRequest<Book> {
    ///             return request(for: Author.books)
    ///         }
    ///     }
    ///
    /// This property will let you navigate from the source type to the
    /// destination type:
    ///
    ///     try dbQueue.read { db in
    ///         let author: Author = ...
    ///         let books = try author.books.fetchAll(db) // [Book]
    ///     }
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key from the destination table, or when the schema defines several
    ///       foreign keys from the destination table.
    public static func hasMany<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> HasManyAssociation<Self, Destination>
    {
        return HasManyAssociation(key: key, using: foreignKey)
    }
    
    /// Creates a "Has Many Through" association between Self and the
    /// destination type.
    ///
    ///     struct Country: TableRecord {
    ///         static let passports = hasMany(Passport.self)
    ///         static let citizens = hasMany(Citizen.self, through: passports, using: Passport.citizen)
    ///     }
    ///
    ///     struct Passport: TableRecord {
    ///         static let citizen = belongsTo(Citizen.self)
    ///     }
    ///
    ///     struct Citizen: TableRecord { }
    ///
    /// The association will let you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all (country, citizen) pairs:
    ///     let request = Country.including(required: Coutry.citizens)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct Citizenship: FetchableRecord, Decodable {
    ///         var country: Country
    ///         var citizen: Citizen
    ///     }
    ///
    ///     let citizenships = try dbQueue.read { db in
    ///         return try Citizenship.fetchAll(db, request)
    ///     }
    ///     for citizenship in citizenships {
    ///         print("\(citizenship.citizen.name) is a citizen of \(citizenship.country.name)")
    ///     }
    ///
    /// It is recommended that you define, alongside the static association, a
    /// property with the same name:
    ///
    ///     struct Country: TableRecord, EncodableRecord {
    ///         static let passports = hasMany(Passport.self)
    ///         static let citizens = hasMany(Citizen.self, through: passports, using: Passport.citizen)
    ///         var citizens: QueryInterfaceRequest<Citizen> {
    ///             return request(for: Country.citizens)
    ///         }
    ///     }
    ///
    /// This property will let you navigate from the source type to the
    /// destination type:
    ///
    ///     try dbQueue.read { db in
    ///         let country: Country = ...
    ///         let citizens = try country.citizens.fetchAll(db) // [Country]
    ///     }
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - pivot: An association from Self to the intermediate type.
    ///     - target: A target association from the intermediate type to the
    ///       destination type.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is the same key as the target.
    public static func hasMany<Pivot, Target>(
        _ destination: Target.RowDecoder.Type,
        through pivot: Pivot,
        using target: Target,
        key: String? = nil)
        -> HasManyThroughAssociation<Self, Target.RowDecoder>
        where Pivot: Association,
        Target: Association,
        Pivot.OriginRowDecoder == Self,
        Pivot.RowDecoder == Target.OriginRowDecoder
    {
        let association = HasManyThroughAssociation<Self, Target.RowDecoder>(
            sqlAssociation: target.sqlAssociation.through(pivot.sqlAssociation))
        
        if let key = key {
            return association.forKey(key)
        } else {
            return association
        }
    }
    
    /// Creates a "Has one" association between Self and the
    /// destination type.
    ///
    ///     struct Demographics: TableRecord { ... }
    ///     struct Country: TableRecord {
    ///         static let demographics = hasOne(Demographics.self)
    ///     }
    ///
    /// The association will let you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all countries with their demographic profile:
    ///     let request = Country.including(optional: Country.demographics)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct CountryInfo: FetchableRecord, Decodable {
    ///         var country: Country
    ///         var demographics: Demographics?
    ///     }
    ///
    ///     let countryInfos = try dbQueue.read { db in
    ///         return try CountryInfo.fetchAll(db, request)
    ///     }
    ///     for countryInfo in countryInfos {
    ///         print("\(countryInfo.country.name) has \(countryInfo.demographics.population) citizens")
    ///     }
    ///
    /// It is recommended that you define, alongside the static association, a
    /// property with the same name:
    ///
    ///     struct Country: TableRecord, EncodableRecord {
    ///         static let demographics = hasOne(Demographics.self)
    ///         var demographics: QueryInterfaceRequest<Demographics> {
    ///             return request(for: Country.demographics)
    ///         }
    ///     }
    ///
    /// This property will let you navigate from the source type to the
    /// destination type:
    ///
    ///     try dbQueue.read { db in
    ///         let country: Country = ...
    ///         let demographics = try country.demographics.fetchOne(db) // Demographics?
    ///     }
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key from the destination table, or when the schema defines several
    ///       foreign keys from the destination table.
    public static func hasOne<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> HasOneAssociation<Self, Destination>
    {
        return HasOneAssociation(key: key, using: foreignKey)
    }
    
    /// Creates a "Has One Through" association between Self and the
    /// destination type.
    ///
    ///     struct Book: TableRecord {
    ///         static let library = belongsTo(Library.self)
    ///         static let returnAddress = hasOne(Address.self, through: library, using: Library.address)
    ///     }
    ///
    ///     struct Library: TableRecord {
    ///         static let address = hasOne(Address.self)
    ///     }
    ///
    ///     struct Address: TableRecord { ... }
    ///
    /// The association will let you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all (book, returnAddress) pairs:
    ///     let request = Book.including(required: Book.returnAddress)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct Todo: FetchableRecord, Decodable {
    ///         var book: Book
    ///         var address: Address
    ///     }
    ///
    ///     let todos = try dbQueue.read { db in
    ///         return try Todo.fetchAll(db, request)
    ///     }
    ///     for todo in todos {
    ///         print("Please return \(todo.book) to \(todo.address)")
    ///     }
    ///
    /// It is recommended that you define, alongside the static association, a
    /// property with the same name:
    ///
    ///     struct Book: TableRecord, EncodableRecord {
    ///         static let library = belongsTo(Library.self)
    ///         static let returnAddress = hasOne(Address.self, through: library, using: library.address)
    ///         var returnAddress: QueryInterfaceRequest<Address> {
    ///             return request(for: Book.returnAddress)
    ///         }
    ///     }
    ///
    /// This property will let you navigate from the source type to the
    /// destination type:
    ///
    ///     try dbQueue.read { db in
    ///         let book: Book = ...
    ///         let address = try book.returnAddress.fetchOne(db) // Address?
    ///     }
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - pivot: An association from Self to the intermediate type.
    ///     - target: A target association from the intermediate type to the
    ///       destination type.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is the same key as the target.
    public static func hasOne<Pivot, Target>(
        _ destination: Target.RowDecoder.Type,
        through pivot: Pivot,
        using target: Target,
        key: String? = nil)
        -> HasOneThroughAssociation<Self, Target.RowDecoder>
        where Pivot: AssociationToOne,
        Target: AssociationToOne,
        Pivot.OriginRowDecoder == Self,
        Pivot.RowDecoder == Target.OriginRowDecoder
    {
        let association = HasOneThroughAssociation<Self, Target.RowDecoder>(
            sqlAssociation: target.sqlAssociation.through(pivot.sqlAssociation))
        
        if let key = key {
            return association.forKey(key)
        } else {
            return association
        }
    }
}

/// A ForeignKey helps building associations when GRDB can't infer a foreign
/// key from the database schema.
///
/// Sometimes the database schema does not define any foreign key between two
/// tables. And sometimes, there are several foreign keys from a table
/// to another:
///
///     | Table book   |       | Table person |
///     | ------------ |       | ------------ |
///     | id           |   +-->• id           |
///     | authorId     •---+   | name         |
///     | translatorId •---+
///     | title        |
///
/// When this happens, associations can't be automatically inferred from the
/// database schema. GRDB will complain with a fatal error such as "Ambiguous
/// foreign key from book to person", or "Could not infer foreign key from book
/// to person".
///
/// Your help is needed. You have to instruct GRDB which foreign key to use:
///
///     struct Book: TableRecord {
///         // Define foreign keys
///         static let authorForeignKey = ForeignKey(["authorId"]))
///         static let translatorForeignKey = ForeignKey(["translatorId"]))
///
///         // Use foreign keys to define associations:
///         static let author = belongsTo(Person.self, using: authorForeignKey)
///         static let translator = belongsTo(Person.self, using: translatorForeignKey)
///     }
///
/// Foreign keys are always defined from the table that contains the columns at
/// the origin of the foreign key. Person's symmetric HasMany associations reuse
/// Book's foreign keys:
///
///     struct Person: TableRecord {
///         static let writtenBooks = hasMany(Book.self, using: Book.authorForeignKey)
///         static let translatedBooks = hasMany(Book.self, using: Book.translatorForeignKey)
///     }
///
/// Foreign keys can also be defined from query interface columns:
///
///     struct Book: TableRecord {
///         enum Columns: String, ColumnExpression {
///             case id, title, authorId, translatorId
///         }
///
///         static let authorForeignKey = ForeignKey([Columns.authorId]))
///         static let translatorForeignKey = ForeignKey([Columns.translatorId]))
///     }
///
/// When the destination table of a foreign key does not define any primary key,
/// you need to provide the full definition of a foreign key:
///
///     struct Book: TableRecord {
///         static let authorForeignKey = ForeignKey(["authorId"], to: ["id"]))
///         static let author = belongsTo(Person.self, using: authorForeignKey)
///     }
public struct ForeignKey {
    var originColumns: [String]
    var destinationColumns: [String]?
    
    /// Creates a ForeignKey intended to define a record association.
    ///
    ///     struct Book: TableRecord {
    ///         // Define foreign keys
    ///         static let authorForeignKey = ForeignKey(["authorId"]))
    ///         static let translatorForeignKey = ForeignKey(["translatorId"]))
    ///
    ///         // Use foreign keys to define associations:
    ///         static let author = belongsTo(Person.self, using: authorForeignKey)
    ///         static let translator = belongsTo(Person.self, using: translatorForeignKey)
    ///     }
    ///
    /// - parameter originColumns: The columns at the origin of the foreign key.
    /// - parameter destinationColumns: The columns at the destination of the
    /// foreign key. When nil (the default), GRDB automatically uses the
    /// primary key.
    public init(_ originColumns: [String], to destinationColumns: [String]? = nil) {
        self.originColumns = originColumns
        self.destinationColumns = destinationColumns
    }
    
    /// Creates a ForeignKey intended to define a record association.
    ///
    ///     struct Book: TableRecord {
    ///         // Define columns
    ///         enum Columns: String, ColumnExpression {
    ///             case id, title, authorId, translatorId
    ///         }
    ///
    ///         // Define foreign keys
    ///         static let authorForeignKey = ForeignKey([Columns.authorId]))
    ///         static let translatorForeignKey = ForeignKey([Columns.translatorId]))
    ///
    ///         // Use foreign keys to define associations:
    ///         static let author = belongsTo(Person.self, using: authorForeignKey)
    ///         static let translator = belongsTo(Person.self, using: translatorForeignKey)
    ///     }
    ///
    /// - parameter originColumns: The columns at the origin of the foreign key.
    /// - parameter destinationColumns: The columns at the destination of the
    /// foreign key. When nil (the default), GRDB automatically uses the
    /// primary key.
    public init(_ originColumns: [ColumnExpression], to destinationColumns: [ColumnExpression]? = nil) {
        self.init(originColumns.map { $0.name }, to: destinationColumns?.map { $0.name })
    }
}

extension TableRecord where Self: EncodableRecord {
    /// Creates a request that fetches the associated record(s).
    ///
    /// For example:
    ///
    ///     struct Team: TableRecord, EncodableRecord {
    ///         static let players = hasMany(Player.self)
    ///         var players: QueryInterfaceRequest<Player> {
    ///             return request(for: Team.players)
    ///         }
    ///     }
    ///
    ///     let team: Team = ...
    ///     let players = try team.players.fetchAll(db) // [Player]
    public func request<A: Association>(for association: A)
        -> QueryInterfaceRequest<A.RowDecoder>
        where A.OriginRowDecoder == Self
    {
        let destinationRelation = association.sqlAssociation.destinationRelation(fromOriginRows: { db in
            try [Row(PersistenceContainer(db, self))]
        })
        return QueryInterfaceRequest(relation: destinationRelation)
    }
}

extension TableRecord {
    
    // MARK: - Associations
    
    /// Creates a request that prefetches an association.
    public static func including<A: AssociationToMany>(all association: A)
        -> QueryInterfaceRequest<Self>
        where A.OriginRowDecoder == Self
    {
        return all().including(all: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public static func including<A: Association>(optional association: A)
        -> QueryInterfaceRequest<Self>
        where A.OriginRowDecoder == Self
    {
        return all().including(optional: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are selected. The returned association requires
    /// that the associated database table contains a matching row.
    public static func including<A: Association>(required association: A)
        -> QueryInterfaceRequest<Self>
        where A.OriginRowDecoder == Self
    {
        return all().including(required: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association does not
    /// require that the associated database table contains a matching row.
    public static func joining<A: Association>(optional association: A)
        -> QueryInterfaceRequest<Self>
        where A.OriginRowDecoder == Self
    {
        return all().joining(optional: association)
    }
    
    /// Creates a request that includes an association. The columns of the
    /// associated record are not selected. The returned association requires
    /// that the associated database table contains a matching row.
    public static func joining<A: Association>(required association: A)
        -> QueryInterfaceRequest<Self>
        where A.OriginRowDecoder == Self
    {
        return all().joining(required: association)
    }
    
    // MARK: - Association Aggregates
    
    /// Creates a request with *aggregates* appended to the selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.rowid) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.annotated(with: Player.books.count)
    public static func annotated(with aggregates: AssociationAggregate<Self>...) -> QueryInterfaceRequest<Self> {
        return all().annotated(with: aggregates)
    }
    
    /// Creates a request with *aggregates* appended to the selection.
    ///
    ///     // SELECT player.*, COUNT(DISTINCT book.rowid) AS bookCount
    ///     // FROM player LEFT JOIN book ...
    ///     var request = Player.annotated(with: [Player.books.count])
    public static func annotated(with aggregates: [AssociationAggregate<Self>]) -> QueryInterfaceRequest<Self> {
        return all().annotated(with: aggregates)
    }
    
    /// Creates a request with the provided aggregate *predicate*.
    ///
    ///     // SELECT player.*
    ///     // FROM player LEFT JOIN book ...
    ///     // HAVING COUNT(DISTINCT book.rowid) = 0
    ///     var request = Player.all()
    ///     request = request.having(Player.books.isEmpty)
    ///
    /// The selection defaults to all columns. This default can be changed for
    /// all requests by the `TableRecord.databaseSelection` property, or
    /// for individual requests with the `TableRecord.select` method.
    public static func having(_ predicate: AssociationAggregate<Self>) -> QueryInterfaceRequest<Self> {
        return all().having(predicate)
    }
}
