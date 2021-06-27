/// The **HasManyThrough** association is often used to set up a many-to-many
/// connection with another record. This association indicates that the
/// declaring record can be matched with zero or more instances of another
/// record by proceeding through a third record.
///
/// For example, consider the practice of passport delivery. One coutry
/// "has many" citizens "through" its passports:
///
///     struct Country: TableRecord {
///         static let passports = hasMany(Passport.self)
///         static let citizens = hasMany(Citizen.self, through: passports, using: Passport.citizen)
///         ...
///     }
///
///     struct Passport: TableRecord {
///         static let citizen = belongsTo(Citizen.self)
///         ...
///     }
///
///     struct Citizen: TableRecord { ... }
///
/// The **HasManyThrough** association is also useful for setting up
/// "shortcuts" through nested HasMany associations. For example, if a document
/// has many sections, and a section has many paragraphs, you may sometimes want
/// to get a simple collection of all paragraphs in the document. You could set
/// that up this way:
///
///     struct Document: TableRecord {
///         static let sections = hasMany(Section.self)
///         static let paragraphs = hasMany(Paragraph.self, through: sections, using: Section.paragraphs)
///     }
///
///     struct Section: TableRecord {
///         static let paragraphs = hasMany(Paragraph.self)
///     }
///
///     struct Paragraph: TableRecord {
///     }
///
/// As in the examples above, **HasManyThrough** association is always built from
/// two other associations: the `through:` and `using:` arguments. Those
/// associations can be any other association (BelongsTo, HasMany,
/// HasManyThrough, etc).
public struct HasManyThroughAssociation<Origin, Destination>: AssociationToMany {
    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination
    
    /// :nodoc:
    public var _sqlAssociation: _SQLAssociation
}
