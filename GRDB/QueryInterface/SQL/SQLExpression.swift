/// SQLExpression is the type that represents an SQL expression, as
/// described at https://www.sqlite.org/lang_expr.html
public struct SQLExpression {
    private var impl: Impl
    
    private enum Impl {
        // MARK: Basic Expressions
        
        /// An unqualified database column.
        ///
        /// "score" is a valid unqualified name. "player.score" is not.
        case column(String)
        
        /// A qualified column in the database, as in
        ///
        ///     SELECT player.score FROM player
        case qualifiedColumn(String, TableAlias)
        
        /// A database value
        case databaseValue(DatabaseValue)
        
        /// A [row value](https://www.sqlite.org/rowvalue.html).
        ///
        /// - precondition: expressions.count > 0
        case rowValue([SQLExpression])
        
        /// A subquery expression
        case subquery(SQLSubquery)
        
        /// A literal SQL expression
        case literal(SQLLiteral)
        
        // MARK: Operators
        
        /// An expression that checks if a values is included in a range with the
        /// `BETWEEN` operator.
        ///
        ///     id BETWEEN 1 AND 3
        indirect case between(
                        expression: SQLExpression,
                        lowerBound: SQLExpression,
                        upperBound: SQLExpression,
                        isNegated: Bool)
        
        /// An expression made of two expressions joined with a
        /// binary operator.
        ///
        ///     length * width
        ///     score >= 1000
        indirect case binary(SQLBinaryOperator, SQLExpression, SQLExpression)
        
        /// An expression made of several expressions joined with an associative
        /// binary operator.
        ///
        ///     a AND b AND c
        ///     score + bonus
        ///
        /// - precondition: expressions.count > 1
        case associativeBinary(SQLAssociativeBinaryOperator, [SQLExpression])
        
        /// An expression that checks the inclusion of a value in a collection
        /// with the `IN` operator.
        ///
        ///     id IN (1,2,3)
        ///     score IN (SELECT ...)
        indirect case `in`(SQLExpression, SQLCollection, isNegated: Bool)
        
        /// An expression made of an unary operator and an operand expression.
        ///
        ///     -score
        indirect case unary(SQLUnaryOperator, SQLExpression)
        
        /// An equality comparison
        ///
        ///     a = b
        ///     a <> b
        ///     a IS b
        ///     a IS NOT b
        indirect case compare(SQLCompareOperator, SQLExpression, SQLExpression)
        
        /// A full-text table match
        ///
        ///     SELECT * FROM document WHERE document MATCH 'query'
        indirect case tableMatch(TableAlias, SQLExpression)
        
        /// The logical not
        ///
        ///     NOT selected
        indirect case not(SQLExpression)
        
        // MARK: Collations
        
        /// An expression tainted by an SQLite collation.
        ///
        ///     SELECT * FROM player WHERE email = 'arthur@example.com' COLLATE NOCASE
        indirect case collated(SQLExpression, Database.CollationName)
        
        // MARK: Functions
        
        /// A call to the SQL `COUNT(...)` function.
        ///
        ///     SELECT COUNT(name) FROM player
        ///     SELECT COUNT(*) FROM player
        indirect case count(SQLSelection)
        
        /// A call to the SQL `COUNT(DISTINCT ...)` function.
        ///
        ///     SELECT COUNT(DISTINCT name) FROM player
        indirect case countDistinct(SQLExpression)
        
        /// A function call
        ///
        ///     LENGTH(name)
        case function(String, [SQLExpression])
        
        /// This expression helps generating `COUNT(...) = 0` or
        /// `COUNT(...) > 0`.
        ///
        /// It has a specific behavior when negated with the `!` logical
        /// operator, or compared with booleans.
        ///
        ///     WHERE COUNT(DISTINCT player.id) == 0
        ///     WHERE COUNT(DISTINCT player.id) > 0
        indirect case isEmpty(SQLExpression, isNegated: Bool)
        
        // MARK: Deferred
        
        /// An expression that picks the fastest available primary key.
        ///
        /// It crashes for WITHOUT ROWID table with a multi-columns primary key.
        /// Future versions of GRDB may use [row values](https://www.sqlite.org/rowvalue.html).
        case fastPrimaryKey
        
        /// Qualified version of `.fastPrimaryKey`
        case qualifiedFastPrimaryKey(TableAlias)
    }
    
    /// SQLite row values were shipped in SQLite 3.15:
    /// https://www.sqlite.org/releaselog/3_15_0.html
    static let rowValuesAreAvailable = (sqlite3_libversion_number() >= 3015000)
    
    static func column(_ name: String) -> Self {
        self.init(impl: .column(name))
    }
    
    static func qualifiedColumn(_ name: String, _ alias: TableAlias) -> Self {
        self.init(impl: .qualifiedColumn(name, alias))
    }
    
    static func databaseValue(_ dbValue: DatabaseValue) -> Self {
        self.init(impl: .databaseValue(dbValue))
    }
    
    static let null = SQLExpression.databaseValue(.null)
    
    /// Returns nil if and only if expressions is empty
    static func rowValue(_ expressions: [SQLExpression]) -> Self? {
        guard let expression = expressions.first else {
            return nil
        }
        if expressions.count == 1 {
            return expression
        }
        return self.init(impl: .rowValue(expressions))
    }
    
    static func subquery(_ subquery: SQLSubquery) -> Self {
        self.init(impl: .subquery(subquery))
    }
    
    static func literal(_ sqlLiteral: SQLLiteral) -> Self {
        self.init(impl: .literal(sqlLiteral))
    }
    
    static func between(
        expression: SQLExpression,
        lowerBound: SQLExpression,
        upperBound: SQLExpression,
        isNegated: Bool = false) -> Self
    {
        self.init(impl: .between(
                    expression: expression,
                    lowerBound: lowerBound,
                    upperBound: upperBound,
                    isNegated: isNegated))
    }
    
    static func binary(_ op: SQLBinaryOperator, _ lhs: SQLExpression, _ rhs: SQLExpression) -> Self {
        self.init(impl: .binary(op, lhs, rhs))
    }
    
    static func associativeBinary(_ op: SQLAssociativeBinaryOperator, _ expressions: [SQLExpression]) -> Self {
        // flatten when possible: a • (b • c) = a • b • c
        var expressions = expressions
        if op.isStrictlyAssociative {
            expressions = expressions.flatMap { expression -> [SQLExpression] in
                if case .associativeBinary(op, let expressions) = expression.impl {
                    return expressions
                } else {
                    return [expression]
                }
            }
        }
        
        guard let expression = expressions.first else {
            return op.neutralValue.sqlExpression
        }
        if expressions.count == 1 {
            return expression
        }
        return self.init(impl: .associativeBinary(op, expressions))
    }
    
    static func `in`(_ expression: SQLExpression, _ collection: SQLCollection, isNegated: Bool = false) -> Self {
        self.init(impl: .in(expression, collection, isNegated: isNegated))
    }
    
    static func unary(_ op: SQLUnaryOperator, _ expression: SQLExpression) -> Self {
        self.init(impl: .unary(op, expression))
    }
    
    static func compare(_ op: SQLCompareOperator, _ lhs: SQLExpression, _ rhs: SQLExpression) -> Self {
        self.init(impl: .compare(op, lhs, rhs))
    }
    
    /// "x = y" or "x IS NULL"
    static func equal(_ lhs: SQLExpression, _ rhs: SQLExpression) -> Self {
        switch (lhs.impl, rhs.impl) {
        case let (impl, .databaseValue(.null)),
             let (.databaseValue(.null), impl):
            // ... IS NULL
            return .compare(.is, SQLExpression(impl: impl), .null)
        default:
            // lhs = rhs
            return .compare(.equal, lhs, rhs)
        }
    }
    
    static func tableMatch(_ alias: TableAlias, _ expression: SQLExpression) -> Self {
        self.init(impl: .tableMatch(alias, expression))
    }
    
    static func not(_ expression: SQLExpression) -> Self {
        self.init(impl: .not(expression))
    }
    
    static func collated(_ expression: SQLExpression, _ collationName: Database.CollationName) -> Self {
        self.init(impl: .collated(expression, collationName))
    }
    
    static func count(_ selection: SQLSelection) -> Self {
        self.init(impl: .count(selection))
    }
    
    static func countDistinct(_ expression: SQLExpression) -> Self {
        self.init(impl: .countDistinct(expression))
    }
    
    static func function(_ name: String, _ expressions: [SQLExpression]) -> Self {
        self.init(impl: .function(name, expressions))
    }
    
    static func isEmpty(_ expression: SQLExpression, isNegated: Bool = false) -> Self {
        self.init(impl: .isEmpty(expression, isNegated: isNegated))
    }
    
    static let fastPrimaryKey = SQLExpression(impl: .fastPrimaryKey)
    
    static func qualifiedFastPrimaryKey(_ alias: TableAlias) -> Self {
        self.init(impl: .qualifiedFastPrimaryKey(alias))
    }
}

extension SQLExpression {
    /// The expression as a quoted SQL literal (not public in order to avoid abuses)
    ///
    ///     try "foo'bar".databaseValue.quotedSQL(db) // "'foo''bar'""
    func quotedSQL(_ db: Database) throws -> String {
        let context = SQLGenerationContext(db, argumentsSink: .forRawSQL)
        return try sql(context)
    }
}

extension SQLExpression {
    /// If this expression is a table colum, returns the name of this column.
    ///
    /// When in doubt, returns nil.
    ///
    /// This method makes it possible to avoid inserting `LIMIT 1` to the SQL
    /// of some requests:
    ///
    ///     // SELECT * FROM "player" WHERE "id" = 1
    ///     try Player.fetchOne(db, key: 1)
    ///     try Player.filter(Column("id") == 1).fetchOne(db)
    ///
    ///     // SELECT * FROM "player" WHERE "name" = 'Arthur' LIMIT 1
    ///     try Player.filter(Column("name") == "Arthur").fetchOne(db)
    ///
    /// This method makes it possible to track individual rows identified by
    /// their row ids, and ignore modifications to other rows:
    ///
    ///     // Track rows 1, 2, 3 only
    ///     let request = Player.filter(keys: [1, 2, 3])
    ///     let regionObservation = DatabaseRegionObservation(tracking: request)
    ///     let valueObservation = ValueObservation.tracking(request.fetchAll)
    ///
    /// - parameter acceptsBijection: If true, expressions that define a
    ///   bijection on a column return this column. For example: `-score`
    ///   returns `score`.
    func column(_ db: Database, for alias: TableAlias, acceptsBijection: Bool = false) throws -> String? {
        switch impl {
        case let .qualifiedColumn(name, a):
            if alias == a {
                return name
            } else {
                return nil
            }
            
        case let .binary(op, lhs, rhs):
            guard acceptsBijection && op == .subtract else {
                return nil
            }
            
            if lhs.isConstantInRequest {
                return try rhs.column(db, for: alias, acceptsBijection: acceptsBijection)
            } else if rhs.isConstantInRequest {
                return try lhs.column(db, for: alias, acceptsBijection: acceptsBijection)
            } else {
                return nil
            }
            
        case let .associativeBinary(op, expressions):
            assert(expressions.count > 1)
            guard acceptsBijection && op.isBijective else {
                return nil
            }
            let nonConstants = expressions.filter { $0.isConstantInRequest == false }
            if nonConstants.count == 1 {
                return try nonConstants[0].column(db, for: alias, acceptsBijection: acceptsBijection)
            }
            return nil
            
        case let .unary(op, expression):
            if acceptsBijection && op == .minus {
                return try expression.column(db, for: alias, acceptsBijection: acceptsBijection)
            }
            return nil
            
        case let .collated(expression, _):
            return try expression.column(db, for: alias, acceptsBijection: acceptsBijection)
            
        case let .function(name, expressions):
            guard acceptsBijection else {
                return nil
            }
            let name = name.uppercased()
            if ["HEX", "QUOTE"].contains(name) && expressions.count == 1 {
                return try expressions[0].column(db, for: alias, acceptsBijection: acceptsBijection)
            } else if name == "IFNULL" && expressions.count == 2 && expressions[1].isConstantInRequest {
                return try expressions[0].column(db, for: alias, acceptsBijection: acceptsBijection)
            } else {
                return nil
            }
            
        case let .qualifiedFastPrimaryKey(a):
            if alias == a {
                return try db.primaryKey(alias.tableName).fastPrimaryKeyColumn
            }
            return nil
            
        default:
            return nil
        }
    }
}

extension SQLExpression {
    /// Returns an SQL string that represents the expression.
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    /// - parameter wrappedInParenthesis: If true, the returned SQL should be
    ///   wrapped inside parenthesis.
    func sql(_ context: SQLGenerationContext, wrappedInParenthesis: Bool = false) throws -> String {
        switch impl {
        case let .column(name):
            return name.quotedDatabaseIdentifier
            
        case let .qualifiedColumn(name, alias):
            if let qualifier = context.qualifier(for: alias) {
                return qualifier.quotedDatabaseIdentifier
                    + "."
                    + name.quotedDatabaseIdentifier
            }
            return name.quotedDatabaseIdentifier
            
        case let .databaseValue(dbValue):
            if dbValue.isNull {
                // fast path for NULL
                return "NULL"
            } else if context.append(arguments: [dbValue]) {
                // Use statement arguments
                return "?"
            } else {
                // Quoting needed: just use SQLite, which knows better.
                return try String.fetchOne(context.db, sql: "SELECT QUOTE(?)", arguments: [dbValue])!
            }
            
        case let .rowValue(expressions):
            assert(!expressions.isEmpty)
            let values = try expressions.map { try $0.sql(context) }
            return "("
                + values.joined(separator: ", ")
                + ")"
            
        case let .subquery(subquery):
            return try "("
                + subquery.sql(context)
                + ")"
            
        case let .literal(sqlLiteral):
            var resultSQL = try sqlLiteral.sql(context)
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            return resultSQL
            
        case let .between(expression: expression, lowerBound: lowerBound, upperBound: upperBound, isNegated: isNegated):
            var resultSQL = try """
                \(expression.sql(context, wrappedInParenthesis: true)) \
                \(isNegated ? "NOT BETWEEN" : "BETWEEN") \
                \(lowerBound.sql(context, wrappedInParenthesis: true)) \
                AND \
                \(upperBound.sql(context, wrappedInParenthesis: true))
                """
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            return resultSQL
            
        case let .binary(op, lhs, rhs):
            var resultSQL = try """
                \(lhs.sql(context, wrappedInParenthesis: true)) \
                \(op.sql) \
                \(rhs.sql(context, wrappedInParenthesis: true))
                """
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            return resultSQL
            
        case let .associativeBinary(op, expressions):
            assert(expressions.count > 1)
            let expressionSQLs = try expressions.map {
                try $0.sql(context, wrappedInParenthesis: true)
            }
            let joiner = " \(op.sql) "
            var resultSQL = expressionSQLs.joined(separator: joiner)
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            return resultSQL
            
        case let .in(expression, collection, isNegated: isNegated):
            var resultSQL = try """
                \(expression.sql(context, wrappedInParenthesis: true)) \
                \(isNegated ? "NOT IN" : "IN") \
                \(collection.sql(context))
                """
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            return resultSQL
            
        case let .unary(op, expression):
            var resultSQL = try op.sql
                + (op.needsRightSpace ? " " : "")
                + expression.sql(context, wrappedInParenthesis: true)
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            return resultSQL
            
        case let .compare(op, lhs, rhs):
            var resultSQL = try """
                \(lhs.sql(context, wrappedInParenthesis: true)) \
                \(op.rawValue) \
                \(rhs.sql(context, wrappedInParenthesis: true))
                """
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            return resultSQL
            
        case let .tableMatch(alias, expression):
            var resultSQL = try """
                \(context.resolvedName(for: alias).quotedDatabaseIdentifier) \
                MATCH \
                \(expression.sql(context, wrappedInParenthesis: true))
                """
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            return resultSQL
            
        case let .not(expression):
            var resultSQL = try "NOT \(expression.sql(context, wrappedInParenthesis: true))"
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            return resultSQL
            
        case let .collated(expression, collationName):
            var resultSQL = try """
                \(expression.sql(context)) \
                COLLATE \
                \(collationName.rawValue)
                """
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            return resultSQL
            
        case let .count(selection):
            return try "COUNT(\(selection.countedSQL(context)))"
            
        case let .countDistinct(expression):
            return try "COUNT(DISTINCT \(expression.sql(context)))"
            
        case let .function(name, expressions):
            return try name
                + "("
                + expressions.map { try $0.sql(context) }.joined(separator: ", ")
                + ")"
            
        case let .isEmpty(expression, isNegated: isNegated):
            var resultSQL = try """
                \(expression.sql(context, wrappedInParenthesis: true)) \
                \(isNegated ? "> 0" : "= 0")
                """
            if wrappedInParenthesis {
                resultSQL = "(\(resultSQL))"
            }
            return resultSQL
            
        case .fastPrimaryKey:
            // Likely a GRDB bug: how comes this expression is used before it
            // has been qualified?
            fatalError("SQLExpression.fastPrimaryKey is not qualified.")
            
        case let .qualifiedFastPrimaryKey(alias):
            let primaryKey = try context.db.primaryKey(alias.tableName)
            guard let column = primaryKey.fastPrimaryKeyColumn else {
                fatalError("Not implemented for WITHOUT ROWID table with a multi-columns primary key")
            }
            return try SQLExpression
                .qualifiedColumn(column, alias)
                .sql(context, wrappedInParenthesis: wrappedInParenthesis)
        }
    }
}

extension SQLExpression {
    /// Returns the columns that identify a unique row in the request
    ///
    /// When in doubt, returns an empty set.
    ///
    ///     WHERE 0                         -- []
    ///     WHERE a                         -- []
    ///     WHERE a = b                     -- []
    ///     WHERE a = 1                     -- ["a"]
    ///     WHERE a = 1 AND b = 2           -- ["a", "b"]
    ///     WHERE a = 1 AND b = 2 AND c > 0 -- ["a", "b"]
    ///     WHERE a = 1 OR a = 2            -- []
    ///     WHERE a > 1                     -- []
    ///
    /// This method makes it possible to avoid inserting `LIMIT 1` to the SQL
    /// of some requests:
    ///
    ///     // SELECT * FROM "player" WHERE "id" = 1
    ///     try Player.fetchOne(db, key: 1)
    ///     try Player.filter(Column("id") == 1).fetchOne(db)
    ///
    ///     // SELECT * FROM "player" WHERE "name" = 'Arthur' LIMIT 1
    ///     try Player.filter(Column("name") == "Arthur").fetchOne(db)
    func identifyingColums(_ db: Database, for alias: TableAlias) throws -> Set<String> {
        switch impl {
        case let .rowValue(expressions):
            assert(!expressions.isEmpty)
            return try expressions.reduce(into: []) { try $0.formUnion($1.identifyingColums(db, for: alias)) }
            
        case let .associativeBinary(op, expressions):
            assert(expressions.count > 1)
            if op == .and {
                return try expressions.reduce(into: []) { try $0.formUnion($1.identifyingColums(db, for: alias)) }
            } else if op == .or {
                return []
            } else {
                return []
            }
            
        case let .compare(op, lhs, rhs):
            switch op {
            case .equal, .is:
                if let column = try lhs.column(db, for: alias, acceptsBijection: true),
                   rhs.isConstantInRequest
                {
                    return [column]
                }
                
                if let column = try rhs.column(db, for: alias, acceptsBijection: true),
                   lhs.isConstantInRequest
                {
                    return [column]
                }
                
                return []
                
            case .notEqual, .isNot:
                return []
            }
            
        case let .collated(expression, _):
            return try expression.identifyingColums(db, for: alias)
            
        default:
            return []
        }
    }
}

extension SQLExpression {
    /// Returns the rowIds that identify rows in the request. A nil result means
    /// an unbounded list.
    ///
    /// When in doubt, returns nil.
    ///
    ///     WHERE 1                               -- nil
    ///     WHERE 0                               -- []
    ///     WHERE NULL                            -- []
    ///     WHERE id IS NULL                      -- []
    ///     WHERE id = 1                          -- [1]
    ///     WHERE id = 1 AND b = 2                -- [1]
    ///     WHERE id = 1 OR id = 2                -- [1, 2]
    ///     WHERE id IN (1, 2, 3)                 -- [1, 2, 3]
    ///     WHERE id IN (1, 2) OR rowid IN (2, 3) -- [1, 2, 3]
    ///     WHERE id > 1                          -- nil
    ///
    /// This method makes it possible to track individual rows identified by
    /// their row ids, and ignore modifications to other rows:
    ///
    ///     // Track rows 1, 2, 3 only
    ///     let request = Player.filter(keys: [1, 2, 3])
    ///     let regionObservation = DatabaseRegionObservation(tracking: request)
    ///     let valueObservation = ValueObservation.tracking(request.fetchAll)
    func identifyingRowIDs(_ db: Database, for alias: TableAlias) throws -> Set<Int64>? {
        switch impl {
        case let .databaseValue(dbValue):
            if dbValue.isNull || dbValue == false.databaseValue {
                // Those requests select no row:
                // - WHERE NULL
                // - WHERE 0
                return []
            }
            return nil
            
        case let .associativeBinary(op, expressions):
            assert(expressions.count > 1)
            if op == .and {
                var result: Set<Int64>? = nil
                for expression in expressions {
                    if let expressionRowIDs = try expression.identifyingRowIDs(db, for: alias) {
                        if var rowIDs = result {
                            rowIDs.formIntersection(expressionRowIDs)
                            result = rowIDs
                            if rowIDs.isEmpty {
                                break
                            }
                        } else {
                            result = expressionRowIDs
                        }
                    }
                }
                return result
            } else if op == .or {
                var result: Set<Int64> = []
                for expression in expressions {
                    if let expressionRowIDs = try expression.identifyingRowIDs(db, for: alias) {
                        result.formUnion(expressionRowIDs)
                    } else {
                        return nil
                    }
                }
                return result
            } else {
                return nil
            }
            
        case let .in(expression, collection, isNegated: false):
            if let expressions = collection.collectionExpressions,
               let column = try expression.column(db, for: alias),
               try db.columnIsRowID(column, of: alias.tableName)
            {
                return Set(expressions.compactMap { expression in
                    if case let .databaseValue(dbValue) = expression.impl {
                        return Int64.fromDatabaseValue(dbValue)
                    } else {
                        return nil
                    }
                })
            } else {
                return nil
            }
            
        case let .compare(op, lhs, rhs):
            switch op {
            case .equal, .is:
                if let column = try lhs.column(db, for: alias),
                   try db.columnIsRowID(column, of: alias.tableName),
                   case .databaseValue(let dbValue) = rhs.impl
                {
                    if let rowID = Int64.fromDatabaseValue(dbValue) {
                        return [rowID]
                    } else {
                        // We miss `rowid = '1'` here, because SQLite would interpret the '1' string as a number
                        return []
                    }
                }
                
                if let column = try rhs.column(db, for: alias),
                   try db.columnIsRowID(column, of: alias.tableName),
                   case .databaseValue(let dbValue) = lhs.impl
                {
                    if let rowID = Int64.fromDatabaseValue(dbValue) {
                        return [rowID]
                    } else {
                        // We miss `rowid = '1'` here, because SQLite would interpret the '1' string as a number
                        return []
                    }
                }
                
                return nil
                
            case .notEqual, .isNot:
                return nil
            }
            
        case let .collated(expression, _):
            return try expression.identifyingRowIDs(db, for: alias)
            
        default:
            return nil
        }
    }
}

extension SQLExpression {
    /// Performs a boolean test.
    ///
    /// We generally distinguish four boolean values:
    ///
    /// 1. truthy: `filter(expression)`
    /// 2. falsey: `filter(!expression)`
    /// 3. true: `filter(expression == true)`
    /// 4. false: `filter(expression == false)`
    ///
    /// They generally produce the following SQL:
    ///
    /// 1. truthy: `WHERE expression`
    /// 2. falsey: `WHERE NOT expression`
    /// 3. true: `WHERE expression = 1`
    /// 4. false: `WHERE expression = 0`
    ///
    /// The `= 1` and `= 0` tests allow the SQLite query planner to
    /// optimize queries with indices on boolean columns and expressions.
    /// See https://github.com/groue/GRDB.swift/issues/816
    ///
    /// This method is a customization point, so that some specific expressions
    /// can produce idiomatic SQL.
    ///
    /// For example, the `like(_)` expression:
    ///
    /// - `column.like(pattern)` -> `column LIKE pattern`
    /// - `!(column.like(pattern))` -> `column NOT LIKE pattern`
    /// - `column.like(pattern) == true` -> `(column LIKE pattern) = 1`
    /// - `column.like(pattern) == false` -> `(column LIKE pattern) = 0`
    ///
    /// Another example, the `isEmpty` association aggregate:
    ///
    /// - `association.isEmpty` -> `COUNT(child.id) = 0`
    /// - `!association.isEmpty` -> `COUNT(child.id) > 0`
    /// - `association.isEmpty == true` -> `COUNT(child.id) = 0`
    /// - `association.isEmpty == false` -> `COUNT(child.id) > 0`
    func `is`(_ test: SQLBooleanTest) -> SQLExpression {
        switch impl {
        case let .databaseValue(dbValue):
            switch dbValue.storage {
            case .null:
                return .null
                
            case .int64(let int64) where int64 == 0 || int64 == 1:
                switch test {
                case .true:
                    return (int64 == 1).sqlExpression
                case .false, .falsey:
                    return (int64 == 0).sqlExpression
                }
                
            default:
                switch test {
                case .true:
                    return .compare(.equal, self, true.sqlExpression)
                case .false:
                    return .compare(.equal, self, false.sqlExpression)
                case .falsey:
                    return .not(self)
                }
            }
            
        case let .between(expression: expression, lowerBound: lowerBound, upperBound: upperBound, isNegated: isNegated):
            switch test {
            case .true:
                return .compare(.equal, self, true.sqlExpression)
                
            case .false:
                return .compare(.equal, self, false.sqlExpression)
                
            case .falsey:
                return .between(
                    expression: expression,
                    lowerBound: lowerBound,
                    upperBound: upperBound,
                    isNegated: !isNegated)
            }
            
        case let .binary(op, lhs, rhs):
            switch test {
            case .true:
                return .compare(.equal, self, true.sqlExpression)
                
            case .false:
                return .compare(.equal, self, false.sqlExpression)
                
            case .falsey:
                if let negatedOp = op.negated {
                    return .binary(negatedOp, lhs, rhs)
                } else {
                    return .not(self)
                }
            }
            
        case let .in(expression, collection, isNegated: isNegated):
            switch test {
            case .true:
                return .compare(.equal, self, true.sqlExpression)
                
            case .false:
                return .compare(.equal, self, false.sqlExpression)
                
            case .falsey:
                return .in(expression, collection, isNegated: !isNegated)
            }
            
        case let .compare(op, lhs, rhs):
            switch test {
            case .true:
                return .compare(.equal, self, true.sqlExpression)
                
            case .false:
                return .compare(.equal, self, false.sqlExpression)
                
            case .falsey:
                return .compare(op.negated, lhs, rhs)
            }
            
        case .not:
            switch test {
            case .true:
                return .compare(.equal, self, true.sqlExpression)
                
            case .false:
                return .compare(.equal, self, false.sqlExpression)
                
            case .falsey:
                // Support `NOT (NOT expression)` as a technique to build 0 or 1
                return .not(self)
            }
            
        case let .collated(expression, collationName):
            return .collated(expression.is(test), collationName)
            
        case let .isEmpty(expression, isNegated: isNegated):
            switch test {
            case .true:
                return self
            case .false, .falsey:
                return .isEmpty(expression, isNegated: !isNegated)
            }
            
        default:
            switch test {
            case .true:
                return .compare(.equal, self, true.sqlExpression)
                
            case .false:
                return .compare(.equal, self, false.sqlExpression)
                
            case .falsey:
                return .not(self)
            }
        }
    }
}

extension SQLExpression {
    private static let knownPureFunctions = [
        "ABS", "CHAR", "COALESCE", "GLOB", "HEX", "IFNULL",
        "IIF", "INSTR", "LENGTH", "LIKE", "LIKELIHOOD",
        "LIKELY", "LOAD_EXTENSION", "LOWER", "LTRIM",
        "NULLIF", "PRINTF", "QUOTE", "REPLACE", "ROUND",
        "RTRIM", "SOUNDEX", "SQLITE_COMPILEOPTION_GET",
        "SQLITE_COMPILEOPTION_USED", "SQLITE_SOURCE_ID",
        "SQLITE_VERSION", "SUBSTR", "TRIM", "TRIM",
        "TYPEOF", "UNICODE", "UNLIKELY", "UPPER", "ZEROBLOB",
    ]
    
    /// Returns true if the expression has a unique value when SQLite runs
    /// a request.
    ///
    /// When in doubt, returns false.
    ///
    ///     1          -- true
    ///     1 + 2      -- true
    ///     score      -- false
    ///
    /// This property supports `identifyingColums(_:for:)`
    var isConstantInRequest: Bool {
        switch impl {
        case .databaseValue:
            return true
            
        case let .rowValue(expressions),
             let .associativeBinary(_, expressions):
            return expressions.allSatisfy(\.isConstantInRequest)
            
        case let .between(expression: expression, lowerBound: lowerBound, upperBound: upperBound, isNegated: _):
            return expression.isConstantInRequest
                && lowerBound.isConstantInRequest
                && upperBound.isConstantInRequest
            
        case let .binary(_, lhs, rhs),
             let .compare(_, lhs, rhs):
            return lhs.isConstantInRequest && rhs.isConstantInRequest
            
        case let .in(expression, collection, isNegated: _):
            guard let expressions = collection.collectionExpressions else {
                return false
            }
            return expression.isConstantInRequest && expressions.allSatisfy(\.isConstantInRequest)
            
        case let .unary(_, expression),
             let .not(expression),
             let .isEmpty(expression, isNegated: _),
             let .collated(expression, _):
            return expression.isConstantInRequest
            
        case let .function(name, expressions):
            let name = name.uppercased()
            guard ((name == "MAX" || name == "MIN") && expressions.count > 1)
                    || Self.knownPureFunctions.contains(name)
            else {
                return false // Don't know - assume not constant
            }
            
            return expressions.allSatisfy(\.isConstantInRequest)
            
        default:
            return false
        }
    }
}

extension SQLExpression {
    /// Returns true iff the expression is trivially true.
    ///
    /// When in doubt, returns false.
    ///
    /// This property helps clearing up the JOIN clauses.
    var isTrue: Bool {
        switch impl {
        case .databaseValue(true.databaseValue):
            return true
            
        case let .collated(expression, _):
            return expression.isTrue
            
        default:
            return false
        }
    }
}

extension SQLExpression {
    /// Returns a qualified expression
    func qualified(with alias: TableAlias) -> SQLExpression {
        switch impl {
        case .databaseValue,
             .qualifiedColumn,
             .qualifiedFastPrimaryKey,
             .subquery:
            return self
            
        case let .column(name):
            return .qualifiedColumn(name, alias)
            
        case let .rowValue(expressions):
            assert(!expressions.isEmpty)
            return .rowValue(expressions.map { $0.qualified(with: alias) })!
            
        case let .literal(sqlLiteral):
            return .literal(sqlLiteral.qualified(with: alias))
            
        case let .between(expression: expression, lowerBound: lowerBound, upperBound: upperBound, isNegated: isNegated):
            return .between(
                expression: expression.qualified(with: alias),
                lowerBound: lowerBound.qualified(with: alias),
                upperBound: upperBound.qualified(with: alias),
                isNegated: isNegated)
            
        case let .binary(op, lhs, rhs):
            return .binary(op, lhs.qualified(with: alias), rhs.qualified(with: alias))
            
        case let .associativeBinary(op, expressions):
            return .associativeBinary(op, expressions.map { $0.qualified(with: alias) })
            
        case let .in(expression, collection, isNegated: isNegated):
            return .in(
                expression.qualified(with: alias),
                collection.qualified(with: alias),
                isNegated: isNegated
            )
            
        case let .unary(op, expression):
            return .unary(op, expression.qualified(with: alias))
            
        case let .compare(op, lhs, rhs):
            return .compare(op, lhs.qualified(with: alias), rhs.qualified(with: alias))
            
        case let .tableMatch(a, expression):
            return .tableMatch(a, expression.qualified(with: alias))
            
        case let .not(expression):
            return .not(expression.qualified(with: alias))
            
        case let .collated(expression, collationName):
            return .collated(expression.qualified(with: alias), collationName)
            
        case let .count(selection):
            return .count(selection.qualified(with: alias))
            
        case let .countDistinct(expression):
            return .countDistinct(expression.qualified(with: alias))
            
        case let .function(name, expressions):
            return .function(name, expressions.map { $0.qualified(with: alias) })
            
        case let .isEmpty(expression, isNegated: isNegated):
            return .isEmpty(expression.qualified(with: alias), isNegated: isNegated)
            
        case .fastPrimaryKey:
            return .qualifiedFastPrimaryKey(alias)
        }
    }
}

extension SQLExpression {
    /// Returns true if the expression is an aggregate.
    ///
    /// When in doubt, returns false.
    ///
    ///     SELECT score          -- false
    ///     SELECT COUNT(*)       -- true
    ///     SELECT MAX(score)     -- true
    ///     SELECT MAX(score) + 1 -- true
    ///
    /// This method makes it possible to avoid inserting `LIMIT 1` to the SQL
    /// of some requests:
    ///
    ///     // SELECT MAX("score") FROM "player"
    ///     try Player.select(max(Column("score")), as: Int.self).fetchOne(db)
    ///
    ///     // SELECT "score" FROM "player" LIMIT 1
    ///     try Player.select(Column("score"), as: Int.self).fetchOne(db)
    var isAggregate: Bool {
        switch impl {
        case let .rowValue(expressions),
             let .associativeBinary(_, expressions):
            return expressions.contains(where: \.isAggregate)
            
        case let .between(expression: expression, lowerBound: _, upperBound: _, isNegated: _),
             let .unary(_, expression),
             let .not(expression),
             let .collated(expression, _),
             let .isEmpty(expression, isNegated: _):
            return expression.isAggregate
            
        case let .binary(_, lhs, rhs),
             let .compare(_, lhs, rhs):
            return lhs.isAggregate || rhs.isAggregate
            
        case let .in(expression, collection, isNegated: _):
            if expression.isAggregate {
                // SELECT aggregate IN (...)
                return true
            }
            
            if let expressions = collection.collectionExpressions,
               expressions.contains(where: \.isAggregate)
            {
                // SELECT expr IN (aggregate, ...)
                return true
            }
            
            return false
            
        case .count,
             .countDistinct:
            return true
            
        case let .function(name, expressions):
            let name = name.uppercased()
            if ["MIN", "MAX"].contains(name) && expressions.count == 1 {
                return true
            } else if ["AVG", "COUNT", "SUM", "TOTAL"].contains(name) && expressions.count == 1 {
                return true
            } else if name == "GROUP_CONCAT" && (expressions.count == 1 || expressions.count == 2) {
                return true
            } else {
                // TODO: return true if all arguments are aggregates?
                return false
            }
            
        default:
            return false
        }
    }
}

extension Sequence where Element: SQLSpecificExpressible {
    /// Returns an expression by joining all elements with an associative SQL
    /// binary operator.
    ///
    /// For example:
    ///
    ///     // SELECT * FROM player
    ///     // WHERE (registered
    ///     //        AND (score >= 1000)
    ///     //        AND (name IS NOT NULL))
    ///     let conditions = [
    ///         Column("registered"),
    ///         Column("score") >= 1000,
    ///         Column("name") != nil]
    ///     Player.filter(conditions.joined(operator: .and))
    ///
    /// When the sequence is empty, `joined(operator:)` returns the neutral
    /// value of the operator. It is 0 (zero) for `.add`, 1 for ‘.multiply`,
    /// false for `.or`, and true for `.and`.
    public func joined(operator: SQLAssociativeBinaryOperator) -> SQLExpression {
        .associativeBinary(`operator`, map(\.sqlExpression))
    }
}

extension Sequence where Element == SQLSpecificExpressible {
    /// Returns an expression by joining all elements with an associative SQL
    /// binary operator.
    ///
    /// For example:
    ///
    ///     // SELECT * FROM player
    ///     // WHERE (registered
    ///     //        AND (score >= 1000)
    ///     //        AND (name IS NOT NULL))
    ///     let conditions = [
    ///         Column("registered"),
    ///         Column("score") >= 1000,
    ///         Column("name") != nil]
    ///     Player.filter(conditions.joined(operator: .and))
    ///
    /// When the sequence is empty, `joined(operator:)` returns the neutral
    /// value of the operator. It is 0 (zero) for `.add`, 1 for ‘.multiply`,
    /// false for `.or`, and true for `.and`.
    public func joined(operator: SQLAssociativeBinaryOperator) -> SQLExpression {
        .associativeBinary(`operator`, map(\.sqlExpression))
    }
}

// MARK: - SQLBooleanTest

/// `SQLBooleanTest` supports boolean tests.
///
/// See `SQLExpression.is(_:)`
enum SQLBooleanTest {
    /// Fuels `expression == true`
    case `true`
    
    /// Fuels `expression == false`
    case `false`
    
    /// Fuels `!expression`
    case falsey
}

// MARK: - SQLAssociativeBinaryOperator

/// SQLAssociativeBinaryOperator is an SQLite associative binary operator, such
/// as `+`, `*`, `AND`, etc.
///
/// Use it with the `joined(operator:)` method. For example:
///
///     // SELECT score + bonus + 1000 FROM player
///     let values = [
///         scoreColumn,
///         bonusColumn,
///         1000.databaseValue]
///     Player.select(values.joined(operator: .add))
public struct SQLAssociativeBinaryOperator: Hashable {
    /// The SQL operator
    let sql: String
    
    /// The neutral value
    let neutralValue: DatabaseValue
    
    /// If true, (a • b) • c is strictly equal to a • (b • c).
    ///
    /// `AND`, `OR`, `||` (concat) are stricly associative.
    ///
    /// `+` and `*` are not stricly associative when applied to floating
    /// point values.
    let isStrictlyAssociative: Bool
    
    /// If true, (a • b) is a bijective function of a, and a bijective
    /// function of b.
    ///
    /// `+` and `||` (concat) are bijective.
    ///
    /// `AND`, `OR` and `*` are not.
    let isBijective: Bool
    
    /// Creates a binary operator
    init(sql: String, neutralValue: DatabaseValue, strictlyAssociative: Bool, bijective: Bool) {
        self.sql = sql
        self.neutralValue = neutralValue
        self.isStrictlyAssociative = strictlyAssociative
        self.isBijective = bijective
    }
    
    /// The `+` binary operator
    ///
    /// For example:
    ///
    ///     // score + bonus
    ///     [Column("score"), Column("bonus")].joined(operator: .add)
    public static let add = SQLAssociativeBinaryOperator(
        sql: "+",
        neutralValue: 0.databaseValue,
        strictlyAssociative: false,
        bijective: true)
    
    /// The `*` binary operator
    ///
    /// For example:
    ///
    ///     // score * factor
    ///     [Column("score"), Column("factor")].joined(operator: .multiply)
    public static let multiply = SQLAssociativeBinaryOperator(
        sql: "*",
        neutralValue: 1.databaseValue,
        strictlyAssociative: false,
        bijective: false)
    
    /// The `AND` binary operator
    ///
    /// For example:
    ///
    ///     // isBlue AND isTall
    ///     [Column("isBlue"), Column("isTall")].joined(operator: .and)
    public static let and = SQLAssociativeBinaryOperator(
        sql: "AND",
        neutralValue: true.databaseValue,
        strictlyAssociative: true,
        bijective: false)
    
    /// The `OR` binary operator
    ///
    /// For example:
    ///
    ///     // isBlue OR isTall
    ///     [Column("isBlue"), Column("isTall")].joined(operator: .or)
    public static let or = SQLAssociativeBinaryOperator(
        sql: "OR",
        neutralValue: false.databaseValue,
        strictlyAssociative: true,
        bijective: false)
    
    /// The `||` string concatenation operator
    ///
    /// For example:
    ///
    ///     // firstName || ' ' || lastName
    ///     [Column("firstName"), " ", Column("lastName")].joined(operator: .concat)
    public static let concat = SQLAssociativeBinaryOperator(
        sql: "||",
        neutralValue: "".databaseValue,
        strictlyAssociative: true,
        bijective: true)
}

// MARK: - SQLBinaryOperator

/// SQLBinaryOperator is an SQLite binary operator, such as >, =, etc.
struct SQLBinaryOperator: Hashable {
    /// The SQL operator
    let sql: String
    
    /// The SQL for the negated operator, if any
    let negatedSQL: String?
    
    /// Creates a binary operator
    ///
    ///     SQLBinaryOperator("-")
    ///     SQLBinaryOperator("LIKE", negated: "NOT LIKE")
    init(_ sql: String, negated: String? = nil) {
        self.sql = sql
        self.negatedSQL = negated
    }
    
    /// Returns the negated binary operator, if any
    ///
    ///     let operator = SQLBinaryOperator("IS", negated: "IS NOT")
    ///     operator.negated!.sql  // IS NOT
    var negated: SQLBinaryOperator? {
        guard let negatedSQL = negatedSQL else {
            return nil
        }
        return SQLBinaryOperator(negatedSQL, negated: sql)
    }
    
    /// The `<` binary operator
    static let lessThan = SQLBinaryOperator("<")
    
    /// The `<=` binary operator
    static let lessThanOrEqual = SQLBinaryOperator("<=")
    
    /// The `>` binary operator
    static let greaterThan = SQLBinaryOperator(">")
    
    /// The `>=` binary operator
    static let greaterThanOrEqual = SQLBinaryOperator(">=")
    
    /// The `-` binary operator
    static let subtract = SQLBinaryOperator("-")
    
    /// The `/` binary operator
    static let divide = SQLBinaryOperator("/")
    
    /// The `LIKE` binary operator
    static let like = SQLBinaryOperator("LIKE", negated: "NOT LIKE")
    
    /// The `MATCH` binary operator
    static let match = SQLBinaryOperator("MATCH")
}

// MARK: - SQLCompareOperator

enum SQLCompareOperator: String {
    case equal = "="
    case notEqual = "<>"
    case `is` = "IS"
    case isNot = "IS NOT"
    
    var negated: SQLCompareOperator {
        switch self {
        case .equal: return .notEqual
        case .notEqual: return .equal
        case .is: return .isNot
        case .isNot: return .is
        }
    }
}

// MARK: - SQLUnaryOperator

/// SQLUnaryOperator is a SQLite unary operator.
struct SQLUnaryOperator: Hashable {
    /// The SQL operator
    let sql: String
    
    /// If true GRDB puts a white space between the operator and the operand.
    let needsRightSpace: Bool
    
    /// Creates an unary operator
    ///
    ///     SQLUnaryOperator("~", needsRightSpace: false)
    init(_ sql: String, needsRightSpace: Bool) {
        self.sql = sql
        self.needsRightSpace = needsRightSpace
    }
    
    /// The `-` unary operator
    static let minus = SQLUnaryOperator("-", needsRightSpace: false)
}

// MARK: - SQLExpressible

/// `SQLExpressible` is the protocol for all types that can be used as an
/// SQL expression.
///
/// It is adopted by protocols like `DatabaseValueConvertible`, and types
/// like `Column`.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public protocol SQLExpressible {
    /// Returns an SQL expression.
    var sqlExpression: SQLExpression { get }
}

/// `SQLSpecificExpressible` is a protocol for all database-specific types that
/// can be turned into an SQL expression. Types whose existence is not purely
/// dedicated to the database should adopt the `SQLExpressible`
/// protocol instead.
///
/// For example, `Column` is a type that only exists to help you build requests,
/// and it adopts `SQLSpecificExpressible`.
///
/// On the other side, `Int` adopts `SQLExpressible`.
public protocol SQLSpecificExpressible: SQLExpressible, SQLSelectable, SQLOrderingTerm {
    // SQLExpressible can be adopted by Swift standard types, and user
    // types, through the DatabaseValueConvertible protocol which inherits
    // from SQLExpressible.
    //
    // For example, Int adopts SQLExpressible through
    // DatabaseValueConvertible.
    //
    // SQLSpecificExpressible, on the other side, is not adopted by any
    // Swift standard type or any user type. It is only adopted by GRDB types,
    // such as Column and SQLExpression.
    //
    // This separation lets us define functions and operators that do not
    // spill out. The three declarations below have no chance overloading a
    // Swift-defined operator, or a user-defined operator:
    //
    // - ==(SQLExpressible, SQLSpecificExpressible)
    // - ==(SQLSpecificExpressible, SQLExpressible)
    // - ==(SQLSpecificExpressible, SQLSpecificExpressible)
}

extension SQLSpecificExpressible {
    public var sqlSelection: SQLSelection {
        .expression(sqlExpression)
    }
    
    public var sqlOrdering: SQLOrdering {
        .expression(sqlExpression)
    }
}

extension SQLExpression: SQLSpecificExpressible {
    // Not a real deprecation, just a usage warning
    @available(*, deprecated, message: "Already SQLExpression")
    public var sqlExpression: SQLExpression { self }
}

// MARK: - SQL Ordering Support

/// :nodoc:
extension SQLSpecificExpressible {
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: SQLOrdering {
        .asc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: SQLOrdering {
        .desc(sqlExpression)
    }
    
    #if GRDBCUSTOMSQLITE
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var ascNullsLast: SQLOrdering {
        .ascNullsLast(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var descNullsFirst: SQLOrdering {
        .descNullsFirst(sqlExpression)
    }
    #elseif !GRDBCIPHER
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    @available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *)
    public var ascNullsLast: SQLOrdering {
        .ascNullsLast(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to QueryInterfaceRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    @available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *)
    public var descNullsFirst: SQLOrdering {
        .descNullsFirst(sqlExpression)
    }
    #endif
}


// MARK: - SQL Selection Support

/// :nodoc:
extension SQLSpecificExpressible {
    /// Give the expression the given SQL name.
    ///
    /// For example:
    ///
    ///     // SELECT (width * height) AS area FROM shape
    ///     let area = (Column("width") * Column("height")).forKey("area")
    ///     let request = Shape.select(area)
    ///     if let row = try Row.fetchOne(db, request) {
    ///         let area: Int = row["area"]
    ///     }
    public func forKey(_ key: String) -> SQLSelection {
        .aliasedExpression(sqlExpression, key)
    }
    
    /// Give the expression the same SQL name as the coding key.
    ///
    /// For example:
    ///
    ///     struct Shape: Decodable, FetchableRecord, TableRecord {
    ///         let width: Int
    ///         let height: Int
    ///         let area: Int
    ///
    ///         static let databaseSelection: [SQLSelectable] = [
    ///             Column(CodingKeys.width),
    ///             Column(CodingKeys.height),
    ///             (Column(CodingKeys.width) * Column(CodingKeys.height)).forKey(CodingKeys.area),
    ///         ]
    ///     }
    ///
    ///     // SELECT width, height, (width * height) AS area FROM shape
    ///     let shapes: [Shape] = try Shape.fetchAll(db)
    public func forKey(_ key: CodingKey) -> SQLSelection {
        forKey(key.stringValue)
    }
}


// MARK: - SQL Collations Support

/// :nodoc:
extension SQLSpecificExpressible {
    
    /// Returns a collated expression.
    ///
    /// For example:
    ///
    ///     Player.filter(Column("email").collating(.nocase) == "contact@example.com")
    public func collating(_ collation: Database.CollationName) -> SQLCollatedExpression {
        SQLCollatedExpression(sqlExpression, collationName: collation)
    }
    
    /// Returns a collated expression.
    ///
    /// For example:
    ///
    ///     Player.filter(Column("name").collating(.localizedStandardCompare) == "Hervé")
    public func collating(_ collation: DatabaseCollation) -> SQLCollatedExpression {
        SQLCollatedExpression(sqlExpression, collationName: Database.CollationName(rawValue: collation.name))
    }
}
