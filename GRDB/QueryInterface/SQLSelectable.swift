// MARK: - SQLSelectable

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLSelectable is the protocol for types that can be selected, as
/// described at https://www.sqlite.org/syntax/result-column.html
///
/// :nodoc:
public protocol SQLSelectable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func countedSQL(_ arguments: inout StatementArguments?) -> String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func count(distinct: Bool) -> SQLCount?
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func columnCount(_ db: Database) throws -> Int
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func qualifiedSelectable(with qualifier: SQLTableQualifier) -> SQLSelectable
}

// MARK: - SQLSelectionLiteral

struct SQLSelectionLiteral : SQLSelectable {
    let sql: String
    let arguments: StatementArguments?
    
    init(_ sql: String, arguments: StatementArguments? = nil) {
        self.sql = sql
        self.arguments = arguments
    }
    
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        if let literalArguments = self.arguments {
            guard arguments != nil else {
                // GRDB limitation: we don't know how to look for `?` in sql and
                // replace them with with literals.
                fatalError("Not implemented")
            }
            arguments! += literalArguments
        }
        return sql
    }
    
    func countedSQL(_ arguments: inout StatementArguments?) -> String {
        fatalError("Selection literals can't be counted. To resolve this error, select one or several SQLExpressionLiteral instead.")
    }
    
    func count(distinct: Bool) -> SQLCount? {
        fatalError("Selection literals can't be counted. To resolve this error, select one or several SQLExpressionLiteral instead.")
    }
    
    func columnCount(_ db: Database) throws -> Int {
        fatalError("Selection literals don't known how many columns they contain. To resolve this error, select one or several SQLExpressionLiteral instead.")
    }
    
    func qualifiedSelectable(with qualifier: SQLTableQualifier) -> SQLSelectable {
        return self
    }
}

// MARK: - TableAlias

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
public final class TableAlias {
    var qualifier: SQLTableQualifier
    
    public init(name: String? = nil) {
        self.qualifier = SQLTableQualifier(tableName: nil, userProvidedAlias: name)
    }
    
    var userProvidedAlias: String? {
        get { return qualifier.userProvidedAlias }
        set {
            // TODO: test
            if let value = newValue {
                qualifier.alias = value
                qualifier.isUserProvided = true
            } else {
                qualifier.isUserProvided = false
            }
        }
    }
    
    /// Returns a qualified value that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ selectable: SQLSelectable) -> SQLSelectable {
        return selectable.qualifiedSelectable(with: qualifier)
    }

    /// Returns a qualified expression that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ expression: SQLExpression) -> SQLExpression {
        return expression.qualifiedExpression(with: qualifier)
    }
}

// MARK: - SQLTableQualifier

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// :nodoc:
public class SQLTableQualifier: Hashable {
    var tableName: String?
    var alias: String?
    var isUserProvided: Bool

    init(tableName: String? = nil, userProvidedAlias: String? = nil) {
        self.tableName = tableName
        self.alias = userProvidedAlias
        self.isUserProvided = (userProvidedAlias != nil)
    }
    
    var qualifiedName: String? {
        return alias ?? tableName
    }
    
    var userProvidedAlias: String? {
        return isUserProvided ? alias : nil
    }
    
    /// :nodoc:
    public var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
    
    /// :nodoc:
    public static func == (lhs: SQLTableQualifier, rhs: SQLTableQualifier) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension Array where Element == SQLTableQualifier {
    /// Resolve ambiguities in qualifiers' names.
    ///
    /// Precondition: all qualifiers have a non-nil qualifiedName:
    ///
    ///     var qualifier = SQLTableQualifier() // nil qualifiedName
    ///     let query = query.qualified(by: &leftQualifier)
    ///     // Now qualifier is guaranteed to have a non-nil qualifiedName.
    func resolveAmbiguities() {
        // Special case
        guard let first = first else {
            return
        }
        
        // Special case for single qualifier: don't output any column name
        if count == 1 {
            if !first.isUserProvided {
                first.alias = nil
                first.tableName = nil
            }
            return
        }
        
        // It is a programmer error to reuse the same (===) TableAlias for
        // multiple tables.
        GRDBPrecondition(count == Set(self).count, "A TableAlias most not be used to refer to multiple tables")
        
        // Group qualifiers by lowercase name
        let groups = Dictionary.init(grouping: self) { $0.qualifiedName!.lowercased() }
        
        var uniqueLowercaseNames: Set<String> = []
        var ambiguousGroups: [[SQLTableQualifier]] = []
        
        for (lowercaseName, group) in groups {
            if group.count > 1 {
                // It is a programmer error to reuse the same alias for multiple tables
                GRDBPrecondition(group.filter({ $0.isUserProvided }).count < 2, "ambiguous alias: \(group[0].qualifiedName!)")
                ambiguousGroups.append(group)
            } else {
                uniqueLowercaseNames.insert(lowercaseName)
            }
        }
        
        for group in ambiguousGroups {
            var index = 1
            for qualifier in group {
                if qualifier.isUserProvided { continue }
                let radical = qualifier.qualifiedName!.databaseQualifierRadical
                var alias: String
                repeat {
                    alias = "\(radical)\(index)"
                    index += 1
                } while uniqueLowercaseNames.contains(alias.lowercased())
                uniqueLowercaseNames.insert(alias.lowercased())
                qualifier.alias = alias
            }
        }
    }
}

extension String {
    /// "foo12" => "foo"
    var databaseQualifierRadical: String {
        let digits: ClosedRange<Character> = "0"..."9"
        let radicalEndIndex = self                  // "foo12"
            .reversed()                             // "21oof"
            .prefix(while: { digits.contains($0) }) // "21"
            .endIndex                               // reversed(foo^12)
            .base                                   // foo^12
        return String(prefix(upTo: radicalEndIndex))
    }
}

// MARK: - Counting

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// :nodoc:
public enum SQLCount {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Represents COUNT(*)
    case all
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Represents COUNT(DISTINCT expression)
    case distinct(SQLExpression)
}
