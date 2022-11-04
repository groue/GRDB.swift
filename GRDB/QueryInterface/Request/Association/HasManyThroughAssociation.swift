/// The `HasManyThroughAssociation` is often used to set up a many-to-many
/// connection with another record. This association indicates that the
/// declaring record can be matched with zero or more instances of another
/// record by proceeding through a third record.
///
/// For example, consider the practice of passport delivery. One country
/// "has many" citizens "through" its passports:
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
/// The `HasManyThroughAssociation` is also useful for setting up "shortcuts"
/// through nested associations. For example, if a document has many sections,
/// and a section has many paragraphs, you may sometimes want to get a simple
/// collection of all paragraphs in the document. You could set
/// that up this way:
///
/// ```swift
/// struct Paragraph: TableRecord { }
///
/// struct Section: TableRecord {
///     static let paragraphs = hasMany(Paragraph.self)
/// }
///
/// struct Document: TableRecord {
///     static let sections = hasMany(Section.self)
///     static let paragraphs = hasMany(Paragraph.self,
///                                     through: sections,
///                                     using: Section.paragraphs)
/// }
/// ```
///
/// As in the examples above, `HasManyThroughAssociation` is always built from
/// two other associations. Those associations can be any ``Association``.
public struct HasManyThroughAssociation<Origin, Destination> {
    public var _sqlAssociation: _SQLAssociation
    
    init<Pivot, Target>(
        through pivot: Pivot,
        using target: Target)
    where Pivot: Association,
          Target: Association,
          Pivot.OriginRowDecoder == Origin,
          Pivot.RowDecoder == Target.OriginRowDecoder,
          Target.RowDecoder == Destination
    {
        _sqlAssociation = target._sqlAssociation.through(pivot._sqlAssociation)
    }
}

extension HasManyThroughAssociation: AssociationToMany {
    public typealias OriginRowDecoder = Origin
    public typealias RowDecoder = Destination
}
