struct SQLJoin {
    let scope: Scope
    let joinKind: SQLJoinKind
    let selection: [SQLSelectable]
    let source: SQLSource
    let joinPredicate: _SQLExpression
    let rightJoins: [SQLJoin]
    
    var properlyNamedSources: [SQLSource] {
        return rightJoins.reduce(source.properlyNamedSources) {
            $0 + $1.properlyNamedSources
        }
    }
    
    var includedSelection: [SQLSelectable] {
        return rightJoins.reduce(selection) {
            $0 + $1.includedSelection
        }
    }
    
    func scopedSource(on scopes: [Scope]) -> SQLSource? {
        guard let scope = scopes.first else {
            return source
        }
        for rightJoin in rightJoins where rightJoin.scope == scope {
            return rightJoin.scopedSource(on: Array(scopes.suffixFrom(1)))
        }
        return nil
    }
    
    func sql(db: Database, inout _ arguments: StatementArguments?, innerJoinForbidden: Bool) throws -> String {
        GRDBPrecondition(!innerJoinForbidden || joinKind == .Left, "Invalid required relation from a non-required relation.")
        
        var sql = try joinKind.rawValue + " " + source.sourceSQL(db, &arguments) + " ON " + joinPredicate.sql(db, &arguments)
        
        if !rightJoins.isEmpty {
            let innerJoinForbidden = (joinKind == .Left)
            sql += " "
            sql += try rightJoins.map {
                try $0.sql(db, &arguments, innerJoinForbidden: innerJoinForbidden)
                }.joinWithSeparator(" ")
        }
        
        return sql
    }
    
    func adapter(inout selectionIndex selectionIndex: Int, columnIndexForSelectionIndex: [Int: Int]) -> RowAdapter? {
        let adapter: RowAdapter?
        
        if selection.isEmpty {
            adapter = nil
        } else {
            adapter = SuffixRowAdapter(
                fromIndex: columnIndexForSelectionIndex[selectionIndex]!,
                failureEndIndex: columnIndexForSelectionIndex[selectionIndex + 1])  // adapter fails if all selected columns are null (ignore columns before and columns after)
            selectionIndex += 1
        }
        
        var scopes: [Scope: RowAdapter] = [:]
        for rightJoin in rightJoins {
            if let adapter = rightJoin.adapter(selectionIndex: &selectionIndex, columnIndexForSelectionIndex: columnIndexForSelectionIndex) {
                scopes[rightJoin.scope] = adapter
            }
        }
        
        if adapter == nil && scopes.isEmpty {
            return nil
        }
        
        return (adapter ?? ColumnMapping([:])).addingScopes(scopes)
    }
}

class SQLJoinSource : SQLSource {
    let leftSource: SQLSource
    let rightJoins: [SQLJoin]
    
    init(leftSource: SQLSource, rightJoins: [SQLJoin]) {
        self.leftSource = leftSource
        self.rightJoins = rightJoins
    }
    
    var name: String {
        get { return leftSource.name }
        set { leftSource.name = newValue }
    }
    
    var includedSelection: [SQLSelectable] {
        return rightJoins.flatMap { $0.includedSelection }
    }
    
    var properlyNamedSources: [SQLSource] {
        return rightJoins.reduce(leftSource.properlyNamedSources) {
            $0 + $1.properlyNamedSources
        }
    }
    
    func sourceSQL(db: Database, inout _ arguments: StatementArguments?) throws -> String {
        return try rightJoins.reduce(leftSource.sourceSQL(db, &arguments)) {
            try $0 + " " + $1.sql(db, &arguments, innerJoinForbidden: false)
        }
    }
    
    func primaryKey(db: Database) throws -> PrimaryKeyInfo? {
        return try leftSource.primaryKey(db)
    }
    
    func numberOfColumns(db: Database) throws -> Int {
        fatalError("Not Implemented")
    }
    
    func adapter(columnIndexForSelectionIndex: [Int: Int]) -> RowAdapter? {
        var selectionIndex = 1
        var scopes: [Scope: RowAdapter] = [:]
        for rightJoin in rightJoins {
            if let adapter = rightJoin.adapter(selectionIndex: &selectionIndex, columnIndexForSelectionIndex: columnIndexForSelectionIndex) {
                scopes[rightJoin.scope] = adapter
            }
        }
        if scopes.isEmpty { return nil }
        return SuffixRowAdapter(fromIndex: 0).addingScopes(scopes)
    }
    
    func scoped(on scopes: [Scope]) -> SQLSource! {
        guard let scope = scopes.first else {
            return leftSource
        }
        for rightJoin in rightJoins where rightJoin.scope == scope {
            return rightJoin.scopedSource(on: Array(scopes.suffixFrom(1)))
        }
        return nil
    }
}
