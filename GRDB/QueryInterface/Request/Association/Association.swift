import Foundation

/// A type that defines a connection between two tables.
///
/// ``Association`` feeds methods of the ``JoinableRequest`` protocol. They are
/// built from a ``TableRecord`` type, or a ``Table`` instance.
///
/// ## Topics
///
/// ### Instance Methods
///
/// - ``forKey(_:)-247af``
/// - ``forKey(_:)-54yh6``
///
/// ### Associations To One
///
/// - ``BelongsToAssociation``
/// - ``HasOneAssociation``
/// - ``HasOneThroughAssociation``
/// - ``AssociationToOne``
///
/// ### Associations To Many
///
/// - ``HasManyAssociation``
/// - ``HasManyThroughAssociation``
/// - ``AssociationToMany``
///
/// ### Associations to Common Table Expressions
///
/// - ``JoinAssociation``
///
/// ### Supporting Types
///
/// - ``ForeignKey``
/// - ``Inflections``
public protocol Association: DerivableRequest {
    // OriginRowDecoder and RowDecoder inherited from DerivableRequest provide
    // type safety:
    //
    //      Book.including(required: Book.author)  // compiles
    //      Fruit.including(required: Book.author) // does not compile
    
    /// The record type at the origin of the association.
    ///
    /// In the ``BelongsToAssociation`` association below, it is `Book`:
    ///
    /// ```swift
    /// struct Book: TableRecord {
    ///     // BelongsToAssociation<Book, Author>
    ///     static let author = belongsTo(Author.self)
    /// }
    /// ```
    associatedtype OriginRowDecoder
    
    var _sqlAssociation: _SQLAssociation { get set }
    
    /// Returns an association with the given key.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Employee: FetchableRecord, TableRecord {
    ///     static let manager = belongsTo(Employee.self).forKey("manager")
    ///     static let subordinates = hasMany(Employee.self).forKey("subordinates")
    /// }
    ///
    /// struct EmployeeInfo: FetchableRecord, Decodable {
    ///     var employee: Employee
    ///     var manager: Employee?       // property name matches the association key
    ///     var subordinates: [Employee] // property name matches the association key
    /// }
    ///
    /// try dbQueue.read { db in
    ///     let employeeInfos: [EmployeeInfo] = try Employee
    ///         .including(optional: Employee.manager)
    ///         .including(all: Employee.subordinates)
    ///         .asRequest(of: EmployeeInfo.self)
    ///         .fetchAll(db)
    /// }
    /// ```
    func forKey(_ key: String) -> Self
}

extension Association {
    /// Returns self modified with the *update* function.
    func with(_ update: (inout Self) throws -> Void) rethrows -> Self {
        var result = self
        try update(&result)
        return result
    }
    
    /// Returns self with destination relation modified with the *update* function.
    fileprivate func withDestinationRelation(_ update: (inout SQLRelation) throws -> Void) rethrows -> Self {
        var result = self
        try update(&result._sqlAssociation.destination.relation)
        return result
    }
}

extension Association {
    public func _including(all association: _SQLAssociation) -> Self {
        withDestinationRelation { relation in
            relation = relation._including(all: association)
        }
    }
    
    public func _including(optional association: _SQLAssociation) -> Self {
        withDestinationRelation { relation in
            relation = relation._including(optional: association)
        }
    }
    
    public func _including(required association: _SQLAssociation) -> Self {
        withDestinationRelation { relation in
            relation = relation._including(required: association)
        }
    }
    
    public func _joining(optional association: _SQLAssociation) -> Self {
        withDestinationRelation { relation in
            relation = relation._joining(optional: association)
        }
    }
    
    public func _joining(required association: _SQLAssociation) -> Self {
        withDestinationRelation { relation in
            relation = relation._joining(required: association)
        }
    }
}

extension Association {
    /// The association key defines how rows fetched from this association
    /// should be consumed.
    ///
    /// For example:
    ///
    ///     struct Player: TableRecord {
    ///         // The default key of this association is the name of the
    ///         // database table for teams, let's say "team":
    ///         static let team = belongsTo(Team.self)
    ///     }
    ///     print(Player.team.key) // Prints "team"
    ///
    ///     // Consume rows:
    ///     let request = Player.including(required: Player.team)
    ///     for row in Row.fetchAll(db, request) {
    ///         let team: Team = row["team"] // the association key
    ///     }
    ///
    /// The key can be redefined with the `forKey` method:
    ///
    ///     let request = Player.including(required: Player.team.forKey("custom"))
    ///     for row in Row.fetchAll(db, request) {
    ///         let team: Team = row["custom"]
    ///     }
    var key: SQLAssociationKey { _sqlAssociation.destination.key }
    
    /// Returns an association with the given key.
    public func forKey(_ codingKey: some CodingKey) -> Self {
        forKey(codingKey.stringValue)
    }
}

// TableRequest conformance
extension Association {
    public func aliased(_ alias: TableAlias) -> Self {
        withDestinationRelation { relation in
            relation = relation.aliased(alias)
        }
    }
}

// SelectionRequest conformance
extension Association {
    public func selectWhenConnected(_ selection: @escaping (Database) throws -> [any SQLSelectable]) -> Self {
        withDestinationRelation { relation in
            relation = relation.selectWhenConnected { db in
                try selection(db).map(\.sqlSelection)
            }
        }
    }
    
    public func annotatedWhenConnected(with selection: @escaping (Database) throws -> [any SQLSelectable]) -> Self {
        withDestinationRelation { relation in
            relation = relation.annotatedWhenConnected { db in
                try selection(db).map(\.sqlSelection)
            }
        }
    }
}

// FilteredRequest conformance
extension Association {
    public func filterWhenConnected(_ predicate: @escaping (Database) throws -> any SQLExpressible) -> Self {
        withDestinationRelation { relation in
            relation = relation.filterWhenConnected { db in
                try predicate(db).sqlExpression
            }
        }
    }
}

// OrderedRequest conformance
extension Association {
    public func orderWhenConnected(_ orderings: @escaping (Database) throws -> [any SQLOrderingTerm]) -> Self {
        withDestinationRelation { relation in
            relation = relation.orderWhenConnected { db in
                try orderings(db).map(\.sqlOrdering)
            }
        }
    }
    
    public func reversed() -> Self {
        withDestinationRelation { relation in
            relation = relation.reversed()
        }
    }
    
    public func unordered() -> Self {
        withDestinationRelation { relation in
            relation = relation.unordered()
        }
    }
}

// TableRequest conformance
extension Association {
    public var databaseTableName: String {
        _sqlAssociation.destination.relation.source.tableName
    }
}

// AggregatingRequest conformance
extension Association {
    public func groupWhenConnected(_ expressions: @escaping (Database) throws -> [any SQLExpressible]) -> Self {
        withDestinationRelation { relation in
            relation = relation.groupWhenConnected { db in
                try expressions(db).map(\.sqlExpression)
            }
        }
    }
    
    public func havingWhenConnected(_ predicate: @escaping (Database) throws -> any SQLExpressible) -> Self {
        withDestinationRelation { relation in
            relation = relation.havingWhenConnected { db in
                try predicate(db).sqlExpression
            }
        }
    }
}

// DerivableRequest conformance
extension Association {
    public func distinct() -> Self {
        withDestinationRelation { relation in
            relation.isDistinct = true
        }
    }
    
    public func with<RowDecoder>(_ cte: CommonTableExpression<RowDecoder>) -> Self {
        withDestinationRelation { relation in
            relation.ctes[cte.tableName] = cte.cte
        }
    }
}

// MARK: - AssociationToOne

/// An association that defines a to-one connection.
public protocol AssociationToOne: Association { }

extension AssociationToOne {
    public func forKey(_ key: String) -> Self {
        let associationKey = SQLAssociationKey.fixedSingular(key)
        return with {
            $0._sqlAssociation = $0._sqlAssociation.forDestinationKey(associationKey)
        }
    }
}

// MARK: - AssociationToMany

/// An association that defines a to-many connection.
///
/// ## Topics
///
/// ### Building Association Aggregates
///
/// - ``average(_:)``
/// - ``count``
/// - ``isEmpty``
/// - ``max(_:)``
/// - ``min(_:)``
/// - ``sum(_:)``
/// - ``total(_:)``
///
/// - ``AssociationAggregate``
public protocol AssociationToMany: Association { }

extension AssociationToMany {
    public func forKey(_ key: String) -> Self {
        let associationKey = SQLAssociationKey.fixedPlural(key)
        return with {
            $0._sqlAssociation = $0._sqlAssociation.forDestinationKey(associationKey)
        }
    }
}
