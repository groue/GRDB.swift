/// SQLGenerationContext is responsible for preventing SQL injection and
/// disambiguating table names when GRDB generates SQL queries.
public struct SQLGenerationContext {
    private(set) var arguments: StatementArguments?
    private var resolvedNames: [TableAlias: String]
    private var qualifierNeeded: Bool
    
    /// Used for SQLExpression -> SQLExpressionLiteral conversion
    static func literalGenerationContext(withArguments: Bool) -> SQLGenerationContext {
        return SQLGenerationContext(
            arguments: withArguments ? [] : nil,
            resolvedNames: [:],
            qualifierNeeded: false)
    }
    
    /// Used for QueryInterfaceQuery.makeSelectStatement() and QueryInterfaceQuery.makeDeleteStatement()
    static func queryGenerationContext(aliases: [TableAlias]) -> SQLGenerationContext {
        return SQLGenerationContext(
            arguments: [],
            resolvedNames: aliases.resolvedNames,
            qualifierNeeded: aliases.count > 1)
    }
    
    /// Used for TableRecord.selectionSQL
    static func recordSelectionGenerationContext(alias: TableAlias) -> SQLGenerationContext {
        return SQLGenerationContext(
            arguments: nil,
            resolvedNames: [:],
            qualifierNeeded: true)
    }
    
    /// Returns whether arguments could be appended
    mutating func appendArguments(_ newArguments: StatementArguments) -> Bool {
        guard let arguments = arguments else {
            return false
        }
        self.arguments = arguments + newArguments
        return true
    }
    
    /// May be nil, when a qualifier is not needed:
    ///
    /// WHERE <qualifier>.column == 1
    /// SELECT <qualifier>.*
    ///
    /// WHERE column == 1
    /// SELECT *
    func qualifier(for alias: TableAlias) -> String? {
        if alias.hasUserName {
            return alias.identityName
        }
        if qualifierNeeded == false {
            return nil
        }
        return resolvedName(for: alias)
    }
    
    /// WHERE <resolvedName> MATCH pattern
    func resolvedName(for alias: TableAlias) -> String {
        return resolvedNames[alias.root] ?? alias.identityName
    }
    
    /// FROM tableName <alias>
    func aliasName(for alias: TableAlias) -> String? {
        let resolvedName = self.resolvedName(for: alias)
        if resolvedName != alias.tableName {
            return resolvedName
        }
        return nil
    }
}

// MARK: - TableAlias

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
public class TableAlias: Hashable {
    private enum Impl {
        /// A TableAlias is undefined when it is created by the GRDB user:
        ///
        ///     let alias = TableAlias()
        ///     let alias = TableAlias(name: "player")
        case undefined(userName: String?)
        
        /// A TableAlias is a table when explicitly specified:
        ///
        ///     let alias = TableAlias(tableName: "player")
        ///
        /// Or when it has been qualified by a request:
        ///
        ///     let alias = TableAlias()
        ///     let request = Player.all().aliased(alias)
        case table(tableName: String, userName: String?)
        case derived(TableAlias)
    }
    private var impl: Impl
    
    // exposed for SQLGenerationContext and expression.resolvedExpression
    var root: TableAlias {
        if case .derived(let base) = impl {
            return base.root
        } else {
            return self
        }
    }
    
    // exposed to SQLGenerationContext
    fileprivate var identityName: String {
        return userName ?? tableName
    }
    
    // exposed to SQLGenerationContext
    fileprivate var hasUserName: Bool {
        return userName != nil
    }
    
    var tableName: String {
        switch impl {
        case .undefined:
            fatalError("Undefined alias has no table name")
        case .table(tableName: let tableName, userName: _):
            return tableName
        case .derived(let base):
            return base.tableName
        }
    }
    
    private var userName: String? {
        switch impl {
        case .undefined(let userName):
            return userName
        case .table(tableName: _, userName: let userName):
            return userName
        case .derived(let base):
            return base.userName
        }
    }
    
    public init(name: String? = nil) {
        self.impl = .undefined(userName: name)
    }
    
    init(tableName: String, userName: String? = nil) {
        self.impl = .table(tableName: tableName, userName: userName)
    }
    
    func rebase(on base: TableAlias) {
        switch impl {
        case .undefined(let userName):
            if let userName = userName {
                // rename
                base.setUserName(userName)
            }
            self.impl = .derived(base)
        default:
            fatalError("Not implemented")
        }
    }
    
    func setUserName(_ userName: String) {
        switch impl {
        case .undefined:
            self.impl = .undefined(userName: userName)
        case .table(tableName: let tableName, userName: _):
            self.impl = .table(tableName: tableName, userName: userName)
        case .derived(let base):
            base.setUserName(userName)
        }
    }
    
    func setTableName(_ tableName: String) {
        switch impl {
        case .undefined(let userName):
            self.impl = .table(tableName: tableName, userName: userName)
        case .table(tableName: let initialTableName, userName: _):
            GRDBPrecondition(tableName.lowercased() == initialTableName.lowercased(), "Can't change table name of a table alias")
        case .derived(let base):
            base.setTableName(tableName)
        }
    }
    
    /// Returns a qualified value that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ selectable: SQLSelectable) -> SQLSelectable {
        return selectable.qualifiedSelectable(with: self)
    }
    
    /// Returns a qualified expression that is able to resolve ambiguities in
    /// joined queries.
    public subscript(_ expression: SQLExpression) -> SQLExpression {
        return expression.qualifiedExpression(with: self)
    }
    
    /// :nodoc:
    public var hashValue: Int {
        if case .derived(let base) = impl {
            return base.hashValue
        } else {
            return ObjectIdentifier(self).hashValue
        }
    }
    
    /// :nodoc:
    public static func == (lhs: TableAlias, rhs: TableAlias) -> Bool {
        return ObjectIdentifier(lhs.root) == ObjectIdentifier(rhs.root)
    }
}

extension Array where Element == TableAlias {
    /// Resolve ambiguities in aliases' names.
    fileprivate var resolvedNames: [TableAlias: String] {
        let aliases = map { $0.root }
        
        // It is a programmer error to reuse the same (===) TableAlias for
        // multiple tables.
        GRDBPrecondition(aliases.count == Set(aliases).count, "A TableAlias most not be used to refer to multiple tables")
        
        let groups = Dictionary.init(grouping: aliases) {
            $0.identityName.lowercased()
        }
        
        var uniqueLowercaseNames: Set<String> = []
        var ambiguousGroups: [[TableAlias]] = []
        
        for (lowercaseName, group) in groups {
            if group.count > 1 {
                // It is a programmer error to reuse the same alias for multiple tables
                GRDBPrecondition(group.filter({ $0.hasUserName }).count < 2, "ambiguous alias: \(group[0].identityName)")
                ambiguousGroups.append(group)
            } else {
                uniqueLowercaseNames.insert(lowercaseName)
            }
        }
        
        var resolvedNames: [TableAlias: String] = [:]
        for group in ambiguousGroups {
            var index = 1
            for alias in group {
                if alias.hasUserName { continue }
                let radical = alias.identityName.databaseQualifierRadical
                var resolvedName: String
                repeat {
                    resolvedName = "\(radical)\(index)"
                    index += 1
                } while uniqueLowercaseNames.contains(resolvedName.lowercased())
                uniqueLowercaseNames.insert(resolvedName.lowercased())
                resolvedNames[alias] = resolvedName
            }
        }
        return resolvedNames
    }
}

extension String {
    /// "bar" => "bar"
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
