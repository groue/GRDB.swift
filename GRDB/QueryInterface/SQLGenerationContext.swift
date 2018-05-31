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
        return resolvedNames[alias] ?? alias.identityName
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
///
/// A TableAlias identifies a table in a request.
public class TableAlias: Hashable {
    private var impl: Impl
    private enum Impl {
        /// A TableAlias is undefined when it is created by the GRDB user:
        ///
        ///     let alias = TableAlias()
        ///     let alias = TableAlias(name: "custom")
        case undefined(userName: String?)
        
        /// A TableAlias is a table when explicitly specified:
        ///
        ///     let alias = TableAlias(tableName: "player")
        ///
        /// Or when it qualifies a request that wasn't qualified yet (in which
        /// case it turns from undefined to a table):
        ///
        ///     // SELECT custom.* FROM player custom
        ///     let alias = TableAlias(name: "custom")
        ///     let request = Player.all().aliased(alias)
        case table(tableName: String, userName: String?)
        
        /// A TableAlias can be a proxy for another table alias. Two different
        /// instances for the same table identifier:
        ///
        ///     // Pointless example: make alias2 a proxy for alias1
        ///     let alias1 = TableAlias()
        ///     let alias2 = TableAlias()
        ///     Player.all()
        ///         .aliased(alias1)
        ///         .aliased(alias2)
        ///
        /// Proxies are useful because queries get implicit aliases as soon
        /// as they are joined with associations. In the example below,
        /// customAlias becomes a proxy for the request's implicit alias, which
        /// gets a custom name. This allows implicit and user aliases to merge
        /// into a single "table identifier" that matches the user's expectations:
        ///
        ///     // SELECT custom.*, team.*
        ///     // FROM player custom
        ///     // JOIN team ON taem.id = custom.teamId
        ///     // WHERE custom.name = 'Arthur'
        ///     let customAlias = TableAlias(name: "custom")
        ///     let request = Player
        ///         .including(required: Player.team)
        ///         .filter(sql: "custom.name = 'Arthur'")
        ///         .aliased(customAlias)
        case proxy(TableAlias)
    }
    
    /// Resolve all proxies
    private var root: TableAlias {
        if case .proxy(let base) = impl {
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
            // Likely a GRDB bug
            fatalError("Undefined alias has no table name")
        case .table(tableName: let tableName, userName: _):
            return tableName
        case .proxy(let base):
            return base.tableName
        }
    }
    
    private var userName: String? {
        switch impl {
        case .undefined(let userName):
            return userName
        case .table(tableName: _, userName: let userName):
            return userName
        case .proxy(let base):
            return base.userName
        }
    }
    
    public init(name: String? = nil) {
        self.impl = .undefined(userName: name)
    }
    
    init(tableName: String, userName: String? = nil) {
        self.impl = .table(tableName: tableName, userName: userName)
    }
    
    func becomeProxy(of base: TableAlias) {
        switch impl {
        case .undefined(let userName):
            if let userName = userName {
                // rename
                base.setUserName(userName)
            }
            self.impl = .proxy(base)
        default:
            // Likely a GRDB bug
            fatalError("Not implemented")
        }
    }
    
    private func setUserName(_ userName: String) {
        switch impl {
        case .undefined:
            self.impl = .undefined(userName: userName)
        case .table(tableName: let tableName, userName: _):
            self.impl = .table(tableName: tableName, userName: userName)
        case .proxy(let base):
            base.setUserName(userName)
        }
    }
    
    func setTableName(_ tableName: String) {
        switch impl {
        case .undefined(let userName):
            self.impl = .table(tableName: tableName, userName: userName)
        case .table(tableName: let initialTableName, userName: _):
            // It is a programmer error to reuse the same TableAlias for
            // multiple tables.
            //
            //      // Don't do that
            //      let alias = TableAlias()
            //      let books = Book.aliased(alias)...
            //      let authors = Author.aliased(alias)...
            GRDBPrecondition(
                tableName.lowercased() == initialTableName.lowercased(),
                "A TableAlias most not be used to refer to multiple tables")
        case .proxy(let base):
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
        return ObjectIdentifier(root).hashValue
    }
    
    /// :nodoc:
    public static func == (lhs: TableAlias, rhs: TableAlias) -> Bool {
        return ObjectIdentifier(lhs.root) == ObjectIdentifier(rhs.root)
    }
}

extension Array where Element == TableAlias {
    /// Resolve ambiguities in aliases' names.
    fileprivate var resolvedNames: [TableAlias: String] {
        // It is a programmer error to reuse the same TableAlias for
        // multiple tables.
        //
        //      // Don't do that
        //      let alias = TableAlias()
        //      let request = Book
        //          .including(required: Book.author.aliased(alias)...)
        //          .including(required: Book.author.aliased(alias)...)
        GRDBPrecondition(count == Set(self).count, "A TableAlias most not be used to refer to multiple tables")
        
        let groups = Dictionary(grouping: self) {
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
