// MARK: - Associations to TableRecord

extension TableRecord {
    /// Creates a ``BelongsToAssociation`` between `Self` and the
    /// destination `TableRecord` type.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord { }
    /// struct Book: TableRecord {
    ///     static let author = belongsTo(Author.self)
    /// }
    /// ```
    ///
    /// The association lets you define requests that involve both the source
    /// and the destination type.
    ///
    /// For example, we can fetch all books with their author:
    ///
    /// ```swift
    /// struct BookInfo: FetchableRecord, Decodable {
    ///     var book: Book
    ///     var author: Author
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let request = Book
    ///         .including(required: Book.author)
    ///         .asRequest(of: BookInfo.self)
    ///     let bookInfos = try request.fetchAll(db)
    ///     for bookInfo in bookInfos {
    ///         print("\(bookInfo.book.title) by \(bookInfo.author.name)")
    ///     }
    /// }
    /// ```
    ///
    /// The association can also help fetching associated records:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let book: Book = ...
    ///     let author: Author? = book
    ///         .request(for: Book.author)
    ///         .fetchOne(db)
    /// }
    /// ```
    ///
    /// For more information about this association,
    /// see ``BelongsToAssociation``.
    ///
    /// Methods that build requests involving associations are defined in the
    /// ``JoinableRequest`` protocol.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `Destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public static func belongsTo<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> BelongsToAssociation<Self, Destination>
    where Destination: TableRecord
    {
        BelongsToAssociation(
            to: Destination.relationForAll,
            key: key,
            using: foreignKey)
    }
    
    /// Creates a ``HasManyAssociation`` between `Self` and the
    /// destination `TableRecord` type.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Book: TableRecord { }
    /// struct Author: TableRecord {
    ///     static let books = hasMany(Book.self)
    /// }
    /// ```
    ///
    /// The association lets you define requests that involve both the source
    /// and the destination type.
    ///
    /// For example, we can fetch all authors with all their books:
    ///
    /// ```swift
    /// struct AuthorInfo: FetchableRecord, Decodable {
    ///     var author: Author
    ///     var books: [Book]
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let request = Author
    ///         .including(all: Author.books)
    ///         .asRequest(of: AuthorInfo.self)
    ///     let authorInfos = try request.fetchAll(db)
    ///     for authorInfo in authorInfos {
    ///         print("\(authorInfo.author.name) wrote \(authorInfo.books.count) books")
    ///     }
    /// }
    /// ```
    ///
    /// The association can also help fetching associated records:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let author: Author = ...
    ///     let books: [Book] = author
    ///         .request(for: Author.books)
    ///         .fetchAll(db)
    /// }
    /// ```
    ///
    /// For more information about this association,
    /// see ``HasManyAssociation``.
    ///
    /// Methods that build requests involving associations are defined in the
    /// ``JoinableRequest`` protocol.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `Destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public static func hasMany<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> HasManyAssociation<Self, Destination>
    where Destination: TableRecord
    {
        HasManyAssociation(
            to: Destination.relationForAll,
            key: key,
            using: foreignKey)
    }
    
    /// Creates a ``HasOneAssociation`` between `Self` and the
    /// destination `TableRecord` type.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Demographics: TableRecord { }
    /// struct Country: TableRecord {
    ///     static let demographics = hasOne(Demographics.self)
    /// }
    /// ```
    ///
    /// The association lets you define requests that involve both the source
    /// and the destination type.
    ///
    /// For example, we can fetch all countries with their eventual demographics:
    ///
    /// ```swift
    /// struct CountryInfo: FetchableRecord, Decodable {
    ///     var country: Country
    ///     var demographics: Demographics?
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let request = Country
    ///         .including(optional: Country.demographics)
    ///         .asRequest(of: CountryInfo.self)
    ///     let countryInfos = try request.fetchAll(db)
    ///     for countryInfo in countryInfos {
    ///         if let demographics = countryInfo.demographics {
    ///             print("""
    ///                 \(countryInfo.country.name) has \
    ///                 \(demographics.population) citizens.
    ///                 """)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// The association can also help fetching associated records:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let country: Country = ...
    ///     let demographics: Demographics? = country
    ///         .request(for: Country.demographics)
    ///         .fetchOne(db)
    /// }
    /// ```
    ///
    /// For more information about this association,
    /// see ``HasOneAssociation``.
    ///
    /// Methods that build requests involving associations are defined in the
    /// ``JoinableRequest`` protocol.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `Destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public static func hasOne<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> HasOneAssociation<Self, Destination>
    where Destination: TableRecord
    {
        HasOneAssociation(
            to: Destination.relationForAll,
            key: key,
            using: foreignKey)
    }
}

// MARK: - Associations to Table

extension TableRecord {
    /// Creates a ``BelongsToAssociation`` between `Self` and the
    /// destination `Table`.
    ///
    /// For more information, see ``TableRecord/belongsTo(_:key:using:)-13t5r``.
    ///
    /// - parameters:
    ///     - destination: The table at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `destination.tableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public static func belongsTo<Destination>(
        _ destination: Table<Destination>,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> BelongsToAssociation<Self, Destination>
    {
        BelongsToAssociation(
            to: destination.relationForAll,
            key: key,
            using: foreignKey)
    }
    
    /// Creates a ``HasManyAssociation`` between `Self` and the
    /// destination `Table`.
    ///
    /// For more information, see ``TableRecord/hasMany(_:key:using:)-45axo``.
    ///
    /// - parameters:
    ///     - destination: The table at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `destination.tableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public static func hasMany<Destination>(
        _ destination: Table<Destination>,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> HasManyAssociation<Self, Destination>
    {
        HasManyAssociation(
            to: destination.relationForAll,
            key: key,
            using: foreignKey)
    }
    
    /// Creates a ``HasOneAssociation`` between `Self` and the
    /// destination `Table`.
    ///
    /// For more information, see ``TableRecord/hasOne(_:key:using:)-4g9tm``.
    ///
    /// - parameters:
    ///     - destination: The table at the other side of the association.
    ///     - key: The association key. By default, it
    ///       is `destination.tableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide one when
    ///       no foreign key exists to the destination table, or several foreign
    ///       keys exist.
    public static func hasOne<Destination>(
        _ destination: Table<Destination>,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
    -> HasOneAssociation<Self, Destination>
    {
        HasOneAssociation(
            to: destination.relationForAll,
            key: key,
            using: foreignKey)
    }
}

// MARK: - Associations to CommonTableExpression

extension TableRecord {
    /// Creates an association to a common table expression.
    ///
    /// The key of the returned association is the table name of the common
    /// table expression.
    ///
    /// For example, you can build a request that fetches all chats with their
    /// latest message:
    ///
    /// ```swift
    /// let latestMessageRequest = Message
    ///     .annotated(with: max(Column("date")))
    ///     .group(Column("chatID"))
    ///
    /// let latestMessageCTE = CommonTableExpression(
    ///     named: "latestMessage",
    ///     request: latestMessageRequest)
    ///
    /// let latestMessageAssociation = Chat.association(
    ///     to: latestMessageCTE,
    ///     on: { chat, latestMessage in
    ///         chat[Column("id")] == latestMessage[Column("chatID")]
    ///     })
    ///
    /// // WITH latestMessage AS
    /// //   (SELECT *, MAX(date) FROM message GROUP BY chatID)
    /// // SELECT chat.*, latestMessage.*
    /// // FROM chat
    /// // LEFT JOIN latestMessage ON chat.id = latestMessage.chatID
    /// let request = Chat
    ///     .with(latestMessageCTE)
    ///     .including(optional: latestMessageAssociation)
    /// ```
    ///
    /// - parameter cte: A common table expression.
    /// - parameter condition: A function that returns the joining clause.
    /// - parameter left: A `TableAlias` for the left table.
    /// - parameter right: A `TableAlias` for the right table.
    /// - returns: An association to the common table expression.
    public static func association<Destination>(
        to cte: CommonTableExpression<Destination>,
        on condition: @escaping (_ left: TableAlias, _ right: TableAlias) -> any SQLExpressible)
    -> JoinAssociation<Self, Destination>
    {
        JoinAssociation(
            to: cte.relationForAll,
            condition: .expression { condition($0, $1).sqlExpression })
    }
    
    /// Creates an association to a common table expression.
    ///
    /// The key of the returned association is the table name of the common
    /// table expression.
    ///
    /// - parameter cte: A common table expression.
    /// - returns: An association to the common table expression.
    public static func association<Destination>(
        to cte: CommonTableExpression<Destination>)
    -> JoinAssociation<Self, Destination>
    {
        JoinAssociation(to: cte.relationForAll, condition: .none)
    }
}

// MARK: - "Through" Associations

extension TableRecord {
    /// Creates a ``HasManyThroughAssociation`` between `Self` and the
    /// destination `TableRecord` type.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Citizen: TableRecord { }
    ///
    /// struct Passport: TableRecord {
    ///     static let citizen = belongsTo(Citizen.self)
    /// }
    ///
    /// struct Country: TableRecord {
    ///     static let passports = hasMany(Passport.self)
    ///     static let citizens = hasMany(Citizen.self,
    ///                                   through: passports,
    ///                                   using: Passport.citizen)
    /// }
    /// ```
    ///
    /// The association lets you define requests that involve both the source
    /// and the destination type.
    ///
    /// For example, we can fetch all countries with all their citizens:
    ///
    /// ```swift
    /// struct CountryInfo: FetchableRecord, Decodable {
    ///     var country: Country
    ///     var citizens: [Citizen]
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let request = Country
    ///         .including(all: Country.citizens)
    ///         .asRequest(of: CountryInfo.self)
    ///     let countryInfos = try request.fetchAll(db)
    ///     for countryInfo in countryInfos {
    ///         print("\(countryInfo.country.name) has \(countryInfo.citizens.count) citizens")
    ///     }
    /// }
    /// ```
    ///
    /// The association can also help fetching associated records:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let country: Country = ...
    ///     let citizens: [Citizen] = country
    ///         .request(for: Country.citizens)
    ///         .fetchAll(db)
    /// }
    /// ```
    ///
    /// For more information about this association,
    /// see ``HasManyThroughAssociation``.
    ///
    /// Methods that build requests involving associations are defined in the
    /// ``JoinableRequest`` protocol.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - pivot: An association from `Self` to the intermediate type.
    ///     - target: A target association from the intermediate type to the
    ///       destination type.
    ///     - key: The association key. By default, it is the key of the target.
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
        let association = HasManyThroughAssociation(through: pivot, using: target)
        
        if let key {
            return association.forKey(key)
        } else {
            return association
        }
    }
    
    /// Creates a ``HasOneThroughAssociation`` between `Self` and the
    /// destination `TableRecord` type.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Address: TableRecord { }
    ///
    /// struct Library: TableRecord {
    ///     static let address = hasOne(Address.self)
    /// }
    ///
    /// struct Book: TableRecord {
    ///     static let library = belongsTo(Library.self)
    ///     static let returnAddress = hasOne(Address.self,
    ///                                       through: library,
    ///                                       using: Library.address,
    ///                                       key: "returnAddress")
    /// }
    /// ```
    ///
    /// The association lets you define requests that involve both the source
    /// and the destination type.
    ///
    /// For example, we can fetch all books with their return address:
    ///
    /// ```swift
    /// struct BookInfo: FetchableRecord, Decodable {
    ///     var book: Book
    ///     var returnAddress: Address
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let request = Book
    ///         .including(required: Book.returnAddress)
    ///         .asRequest(of: BookInfo.self)
    ///     let bookInfos = try request.fetchAll(db)
    ///     for bookInfo in bookInfos {
    ///         print("\(bookInfo.book.title) must return to \(bookInfo.returnAddress)")
    ///     }
    /// }
    /// ```
    ///
    /// The association can also help fetching associated records:
    ///
    /// ```swift
    /// try dbQueue.read { db in
    ///     let book: Book = ...
    ///     let returnAddress: Address? = book
    ///         .request(for: Book.returnAddress)
    ///         .fetchOne(db)
    /// }
    /// ```
    ///
    /// For more information about this association,
    /// see ``HasOneThroughAssociation``.
    ///
    /// Methods that build requests involving associations are defined in the
    /// ``JoinableRequest`` protocol.
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - pivot: An association from Self to the intermediate type.
    ///     - target: A target association from the intermediate type to the
    ///       destination type.
    ///     - key: The association key. By default, it is the key of the target.
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
        let association = HasOneThroughAssociation(through: pivot, using: target)
        
        if let key {
            return association.forKey(key)
        } else {
            return association
        }
    }
}

// MARK: - Request for associated records

extension TableRecord where Self: EncodableRecord {
    /// Returns a request for the associated record(s).
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord, FetchableRecord { }
    /// struct Team: TableRecord, EncodableRecord {
    ///     static let players = hasMany(Player.self)
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let team: Team = ...
    ///     let players: [Player] = try team
    ///         .request(for: Team.players)
    ///         .fetchAll(db)
    /// }
    /// ```
    public func request<A: Association>(for association: A)
    -> QueryInterfaceRequest<A.RowDecoder>
    where A.OriginRowDecoder == Self
    {
        switch association._sqlAssociation.pivot.condition {
        case .expression:
            // TODO: find a use case?
            fatalError("Not implemented: request association without any foreign key")
            
        case let .foreignKey(foreignKey):
            let destinationRelation = association
                ._sqlAssociation
                .with {
                    $0.pivot.relation = $0.pivot.relation.filterWhenConnected { db in
                        // Filter the pivot on self
                        try foreignKey
                            .joinMapping(db, from: Self.databaseTableName)
                            .joinExpression(leftRows: [PersistenceContainer(db, self)])
                    }
                }
                .destinationRelation()
            return QueryInterfaceRequest(relation: destinationRelation)
        }
    }
}

// MARK: - Joining Methods

extension TableRecord {
    /// Returns a request that fetches all records associated with each record
    /// in this request.
    ///
    /// For example, we can fetch authors along with their books:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable {
    ///     static let books = hasMany(Book.self)
    /// }
    /// struct Book: TableRecord, FetchableRecord, Decodable { }
    ///
    /// struct AuthorInfo: FetchableRecord, Decodable {
    ///     var author: Author
    ///     var books: [Book]
    /// }
    ///
    /// let authorInfos = try Author
    ///     .including(all: Author.books)
    ///     .asRequest(of: AuthorInfo.self)
    ///     .fetchAll(db)
    /// ```
    public static func including<A: AssociationToMany>(all association: A)
    -> QueryInterfaceRequest<Self>
    where A.OriginRowDecoder == Self
    {
        all().including(all: association)
    }
    
    /// Returns a request that fetches the eventual record associated with each
    /// record of this request.
    ///
    /// For example, we can fetch books along with their eventual author:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable { }
    /// struct Book: TableRecord, FetchableRecord, Decodable {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct BookInfo: FetchableRecord, Decodable {
    ///     var book: Book
    ///     var author: Author?
    /// }
    ///
    /// let bookInfos = try Book
    ///     .including(optional: Book.author)
    ///     .asRequest(of: BookInfo.self)
    ///     .fetchAll(db)
    /// ```
    public static func including<A: Association>(optional association: A)
    -> QueryInterfaceRequest<Self>
    where A.OriginRowDecoder == Self
    {
        all().including(optional: association)
    }
    
    /// Returns a request that fetches the record associated with each record in
    /// this request. Records that do not have an associated record
    /// are discarded.
    ///
    /// For example, we can fetch books along with their eventual author:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable { }
    /// struct Book: TableRecord, FetchableRecord, Decodable {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// struct BookInfo: FetchableRecord, Decodable {
    ///     var book: Book
    ///     var author: Author
    /// }
    ///
    /// let bookInfos = try Book
    ///     .including(required: Book.author)
    ///     .asRequest(of: BookInfo.self)
    ///     .fetchAll(db)
    /// ```
    public static func including<A: Association>(required association: A)
    -> QueryInterfaceRequest<Self>
    where A.OriginRowDecoder == Self
    {
        all().including(required: association)
    }
    
    /// Returns a request that joins each record of this request to its
    /// eventual associated record.
    public static func joining<A: Association>(optional association: A)
    -> QueryInterfaceRequest<Self>
    where A.OriginRowDecoder == Self
    {
        all().joining(optional: association)
    }
    
    /// Returns a request that joins each record of this request to its
    /// associated record. Records that do not have an associated record
    /// are discarded.
    ///
    /// For example, we can fetch only books whose author is French:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable { }
    /// struct Book: TableRecord, FetchableRecord, Decodable {
    ///     static let author = belongsTo(Author.self)
    /// }
    ///
    /// let frenchAuthors = Book.author.filter(Column("countryCode") == "FR")
    /// let bookInfos = try Book
    ///     .joining(required: frenchAuthors)
    ///     .fetchAll(db)
    /// ```
    public static func joining<A: Association>(required association: A)
    -> QueryInterfaceRequest<Self>
    where A.OriginRowDecoder == Self
    {
        all().joining(required: association)
    }
    
    /// Returns a request with the columns of the eventual associated record
    /// appended to the record selection.
    ///
    /// The record selection is determined by
    /// ``TableRecord/databaseSelection-7iphs``, which defaults to all columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT player.*, team.color
    /// // FROM player LEFT JOIN team ...
    /// let teamColor = Player.team.select(Column("color"))
    /// let request = Player.annotated(withOptional: teamColor)
    /// ```
    ///
    /// See ``JoinableRequest/annotated(withOptional:)`` for more information.
    public static func annotated<A: Association>(withOptional association: A)
    -> QueryInterfaceRequest<Self>
    where A.OriginRowDecoder == Self
    {
        all().annotated(withOptional: association)
    }
    
    /// Returns a request with the columns of the associated record appended to
    /// the record selection. Records that do not have an associated record
    /// are discarded.
    ///
    /// The record selection is determined by
    /// ``TableRecord/databaseSelection-7iphs``, which defaults to all columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// // SELECT player.*, team.color
    /// // FROM player JOIN team ...
    /// let teamColor = Player.team.select(Column("color"))
    /// let request = Player.annotated(withRequired: teamColor)
    /// ```
    ///
    /// See ``JoinableRequest/annotated(withRequired:)`` for more information.
    public static func annotated<A: Association>(withRequired association: A)
    -> QueryInterfaceRequest<Self>
    where A.OriginRowDecoder == Self
    {
        all().annotated(withRequired: association)
    }
}

// MARK: - Aggregates

extension TableRecord {
    /// Returns a request with the given association aggregates appended to
    /// the record selection.
    ///
    /// The record selection is determined by
    /// ``TableRecord/databaseSelection-7iphs``, which defaults to all columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable {
    ///     static let books = hasMany(Book.self)
    /// }
    /// struct Book: TableRecord, FetchableRecord, Decodable { }
    ///
    /// struct AuthorInfo: FetchableRecord, Decodable {
    ///     var author: Author
    ///     var bookCount: Int
    /// }
    ///
    /// // SELECT author.*, COUNT(DISTINCT book.id) AS bookCount
    /// // FROM author
    /// // LEFT JOIN book ON book.authorId = author.id
    /// // GROUP BY author.id
    /// let authorInfos = try Author
    ///     .annotated(with: Author.books.count)
    ///     .asRequest(of: AuthorInfo.self)
    ///     .fetchAll(db)
    /// ```
    public static func annotated(with aggregates: AssociationAggregate<Self>...) -> QueryInterfaceRequest<Self> {
        all().annotated(with: aggregates)
    }
    
    /// Returns a request with the given association aggregates appended to
    /// the record selection.
    ///
    /// The record selection is determined by
    /// ``TableRecord/databaseSelection-7iphs``, which defaults to all columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord, Decodable {
    ///     static let books = hasMany(Book.self)
    /// }
    /// struct Book: TableRecord, FetchableRecord, Decodable { }
    ///
    /// struct AuthorInfo: FetchableRecord, Decodable {
    ///     var author: Author
    ///     var bookCount: Int
    /// }
    ///
    /// // SELECT author.*, COUNT(DISTINCT book.id) AS bookCount
    /// // FROM author
    /// // LEFT JOIN book ON book.authorId = author.id
    /// // GROUP BY author.id
    /// let authorInfos = try Author
    ///     .annotated(with: [Author.books.count])
    ///     .asRequest(of: AuthorInfo.self)
    ///     .fetchAll(db)
    /// ```
    public static func annotated(with aggregates: [AssociationAggregate<Self>]) -> QueryInterfaceRequest<Self> {
        all().annotated(with: aggregates)
    }
    
    /// Returns a request filtered according to the provided
    /// association aggregate.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Author: TableRecord, FetchableRecord {
    ///     static let books = hasMany(Book.self)
    /// }
    /// struct Book: TableRecord, FetchableRecord { }
    ///
    /// // SELECT author.*
    /// // FROM author
    /// // LEFT JOIN book ON book.authorId = author.id
    /// // GROUP BY author.id
    /// // HAVING COUNT(DISTINCT book.id) > 5
    /// let authors = try Author
    ///     .having(Author.books.count > 5)
    ///     .fetchAll(db)
    /// ```
    public static func having(_ predicate: AssociationAggregate<Self>) -> QueryInterfaceRequest<Self> {
        all().having(predicate)
    }
}
