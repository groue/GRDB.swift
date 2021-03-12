/// An SQL function or aggregate.
public final class DatabaseFunction: Hashable {
    // SQLite identifies functions by (name + argument count)
    private struct Identity: Hashable {
        let name: String
        let nArg: Int32 // -1 for variadic functions
    }
    
    /// The name of the SQL function
    public var name: String { identity.name }
    private let identity: Identity
    let pure: Bool
    private let kind: Kind
    private var eTextRep: Int32 { (SQLITE_UTF8 | (pure ? SQLITE_DETERMINISTIC : 0)) }
    
    /// Creates an SQL function.
    ///
    /// For example:
    ///
    ///     let fn = DatabaseFunction("succ", argumentCount: 1) { dbValues in
    ///         guard let int = Int.fromDatabaseValue(dbValues[0]) else {
    ///             return nil
    ///         }
    ///         return int + 1
    ///     }
    ///     db.add(function: fn)
    ///     try Int.fetchOne(db, sql: "SELECT succ(1)")! // 2
    ///
    /// - parameters:
    ///     - name: The function name.
    ///     - argumentCount: The number of arguments of the function. If
    ///       omitted, or nil, the function accepts any number of arguments.
    ///     - pure: Whether the function is "pure", which means that its results
    ///       only depends on its inputs. When a function is pure, SQLite has
    ///       the opportunity to perform additional optimizations. Default value
    ///       is false.
    ///     - function: A function that takes an array of DatabaseValue
    ///       arguments, and returns an optional DatabaseValueConvertible such
    ///       as Int, String, NSDate, etc. The array is guaranteed to have
    ///       exactly *argumentCount* elements, provided *argumentCount* is
    ///       not nil.
    public init(
        _ name: String,
        argumentCount: Int32? = nil,
        pure: Bool = false,
        function: @escaping ([DatabaseValue]) throws -> DatabaseValueConvertible?)
    {
        self.identity = Identity(name: name, nArg: argumentCount ?? -1)
        self.pure = pure
        self.kind = .function{ (argc, argv) in
            let arguments = (0..<Int(argc)).map { index in
                DatabaseValue(sqliteValue: argv.unsafelyUnwrapped[index]!)
            }
            return try function(arguments)
        }
    }
    
    /// Creates an SQL aggregate function.
    ///
    /// For example:
    ///
    ///     struct MySum: DatabaseAggregate {
    ///         var sum: Int = 0
    ///
    ///         mutating func step(_ dbValues: [DatabaseValue]) {
    ///             if let int = Int.fromDatabaseValue(dbValues[0]) {
    ///                 sum += int
    ///             }
    ///         }
    ///
    ///         func finalize() -> DatabaseValueConvertible? {
    ///             return sum
    ///         }
    ///     }
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let fn = DatabaseFunction("mysum", argumentCount: 1, aggregate: MySum.self)
    ///     try dbQueue.write { db in
    ///         db.add(function: fn)
    ///         try db.execute(sql: "CREATE TABLE test(i)")
    ///         try db.execute(sql: "INSERT INTO test(i) VALUES (1)")
    ///         try db.execute(sql: "INSERT INTO test(i) VALUES (2)")
    ///         try Int.fetchOne(db, sql: "SELECT mysum(i) FROM test")! // 3
    ///     }
    ///
    /// - parameters:
    ///     - name: The function name.
    ///     - argumentCount: The number of arguments of the aggregate. If
    ///       omitted, or nil, the aggregate accepts any number of arguments.
    ///     - pure: Whether the aggregate is "pure", which means that its
    ///       results only depends on its inputs. When an aggregate is pure,
    ///       SQLite has the opportunity to perform additional optimizations.
    ///       Default value is false.
    ///     - aggregate: A type that implements the DatabaseAggregate protocol.
    ///       For each step of the aggregation, its `step` method is called with
    ///       an array of DatabaseValue arguments. The array is guaranteed to
    ///       have exactly *argumentCount* elements, provided *argumentCount* is
    ///       not nil.
    public init<Aggregate: DatabaseAggregate>(
        _ name: String,
        argumentCount: Int32? = nil,
        pure: Bool = false,
        aggregate: Aggregate.Type)
    {
        self.identity = Identity(name: name, nArg: argumentCount ?? -1)
        self.pure = pure
        self.kind = .aggregate { Aggregate() }
    }
    
    /// Returns an SQL expression that applies the function.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-functions
    public func callAsFunction(_ arguments: SQLExpressible...) -> SQLExpression {
        switch kind {
        case .aggregate:
            return .function(name, arguments.map(\.sqlExpression))
        case .function:
            return .aggregate(name, arguments.map(\.sqlExpression))
        }
    }

    /// Calls sqlite3_create_function_v2
    /// See https://sqlite.org/c3ref/create_function.html
    func install(in db: Database) {
        // Retain the function definition
        let definition = kind.definition
        let definitionP = Unmanaged.passRetained(definition).toOpaque()
        
        let code = sqlite3_create_function_v2(
            db.sqliteConnection,
            identity.name,
            identity.nArg,
            eTextRep,
            definitionP,
            kind.xFunc,
            kind.xStep,
            kind.xFinal,
            { definitionP in
                // Release the function definition
                Unmanaged<AnyObject>.fromOpaque(definitionP!).release()
            })
        
        guard code == SQLITE_OK else {
            // Assume a GRDB bug: there is no point throwing any error.
            fatalError(DatabaseError(resultCode: code, message: db.lastErrorMessage))
        }
    }
    
    /// Calls sqlite3_create_function_v2
    /// See https://sqlite.org/c3ref/create_function.html
    func uninstall(in db: Database) {
        let code = sqlite3_create_function_v2(
            db.sqliteConnection,
            identity.name,
            identity.nArg,
            eTextRep,
            nil, nil, nil, nil, nil)
        
        guard code == SQLITE_OK else {
            // Assume a GRDB bug: there is no point throwing any error.
            fatalError(DatabaseError(resultCode: code, message: db.lastErrorMessage))
        }
    }
    
    /// The way to compute the result of a function.
    /// Feeds the `pApp` parameter of sqlite3_create_function_v2
    /// http://sqlite.org/capi3ref.html#sqlite3_create_function
    private class FunctionDefinition {
        let compute: (Int32, UnsafeMutablePointer<OpaquePointer?>?) throws -> DatabaseValueConvertible?
        init(compute: @escaping (Int32, UnsafeMutablePointer<OpaquePointer?>?) throws -> DatabaseValueConvertible?) {
            self.compute = compute
        }
    }
    
    /// The way to start an aggregate.
    /// Feeds the `pApp` parameter of sqlite3_create_function_v2
    /// http://sqlite.org/capi3ref.html#sqlite3_create_function
    private class AggregateDefinition {
        let makeAggregate: () -> DatabaseAggregate
        init(makeAggregate: @escaping () -> DatabaseAggregate) {
            self.makeAggregate = makeAggregate
        }
    }
    
    /// The current state of an aggregate, storable in SQLite
    private class AggregateContext {
        var aggregate: DatabaseAggregate
        var hasErrored = false
        init(aggregate: DatabaseAggregate) {
            self.aggregate = aggregate
        }
    }
    
    /// A function kind: an "SQL function" or an "aggregate".
    /// See http://sqlite.org/capi3ref.html#sqlite3_create_function
    private enum Kind {
        /// A regular function: SELECT f(1)
        case function((Int32, UnsafeMutablePointer<OpaquePointer?>?) throws -> DatabaseValueConvertible?)
        
        /// An aggregate: SELECT f(foo) FROM bar GROUP BY baz
        case aggregate(() -> DatabaseAggregate)
        
        /// Feeds the `pApp` parameter of sqlite3_create_function_v2
        /// http://sqlite.org/capi3ref.html#sqlite3_create_function
        var definition: AnyObject {
            switch self {
            case .function(let compute):
                return FunctionDefinition(compute: compute)
            case .aggregate(let makeAggregate):
                return AggregateDefinition(makeAggregate: makeAggregate)
            }
        }
        
        /// Feeds the `xFunc` parameter of sqlite3_create_function_v2
        /// http://sqlite.org/capi3ref.html#sqlite3_create_function
        var xFunc: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)? {
            guard case .function = self else { return nil }
            return { (sqliteContext, argc, argv) in
                let definition = Unmanaged<FunctionDefinition>
                    .fromOpaque(sqlite3_user_data(sqliteContext))
                    .takeUnretainedValue()
                do {
                    try DatabaseFunction.report(
                        result: definition.compute(argc, argv),
                        in: sqliteContext)
                } catch {
                    DatabaseFunction.report(error: error, in: sqliteContext)
                }
            }
        }
        
        /// Feeds the `xStep` parameter of sqlite3_create_function_v2
        /// http://sqlite.org/capi3ref.html#sqlite3_create_function
        var xStep: (@convention(c) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void)? {
            guard case .aggregate = self else { return nil }
            return { (sqliteContext, argc, argv) in
                let aggregateContextU = DatabaseFunction.unmanagedAggregateContext(sqliteContext)
                let aggregateContext = aggregateContextU.takeUnretainedValue()
                assert(!aggregateContext.hasErrored) // assert SQLite behavior
                do {
                    let arguments = (0..<Int(argc)).map { index in
                        DatabaseValue(sqliteValue: argv.unsafelyUnwrapped[index]!)
                    }
                    try aggregateContext.aggregate.step(arguments)
                } catch {
                    aggregateContext.hasErrored = true
                    DatabaseFunction.report(error: error, in: sqliteContext)
                }
            }
        }
        
        /// Feeds the `xFinal` parameter of sqlite3_create_function_v2
        /// http://sqlite.org/capi3ref.html#sqlite3_create_function
        var xFinal: (@convention(c) (OpaquePointer?) -> Void)? {
            guard case .aggregate = self else { return nil }
            return { (sqliteContext) in
                let aggregateContextU = DatabaseFunction.unmanagedAggregateContext(sqliteContext)
                let aggregateContext = aggregateContextU.takeUnretainedValue()
                aggregateContextU.release()
                
                guard !aggregateContext.hasErrored else {
                    return
                }
                
                do {
                    try DatabaseFunction.report(
                        result: aggregateContext.aggregate.finalize(),
                        in: sqliteContext)
                } catch {
                    DatabaseFunction.report(error: error, in: sqliteContext)
                }
            }
        }
    }
    
    /// Helper function that extracts the current state of an aggregate from an
    /// sqlite function execution context.
    ///
    /// The result must be released when the aggregate concludes.
    ///
    /// See https://sqlite.org/c3ref/context.html
    /// See https://sqlite.org/c3ref/aggregate_context.html
    private static func unmanagedAggregateContext(_ sqliteContext: OpaquePointer?) -> Unmanaged<AggregateContext> {
        // > The first time the sqlite3_aggregate_context(C,N) routine is called
        // > for a particular aggregate function, SQLite allocates N of memory,
        // > zeroes out that memory, and returns a pointer to the new memory.
        // > On second and subsequent calls to sqlite3_aggregate_context() for
        // > the same aggregate function instance, the same buffer is returned.
        let stride = MemoryLayout<Unmanaged<AggregateContext>>.stride
        let aggregateContextBufferP = UnsafeMutableRawBufferPointer(
            start: sqlite3_aggregate_context(sqliteContext, Int32(stride))!,
            count: stride)
        
        if aggregateContextBufferP.contains(where: { $0 != 0 }) {
            // Buffer contains non-zero byte: load aggregate context
            let aggregateContextP = aggregateContextBufferP
                .baseAddress!
                .assumingMemoryBound(to: Unmanaged<AggregateContext>.self)
            return aggregateContextP.pointee
        } else {
            // Buffer contains null pointer: create aggregate context.
            let aggregate = Unmanaged<AggregateDefinition>.fromOpaque(sqlite3_user_data(sqliteContext))
                .takeUnretainedValue()
                .makeAggregate()
            let aggregateContext = AggregateContext(aggregate: aggregate)
            
            // retain and store in SQLite's buffer
            let aggregateContextU = Unmanaged.passRetained(aggregateContext)
            let aggregateContextP = aggregateContextU.toOpaque()
            withUnsafeBytes(of: aggregateContextP) {
                aggregateContextBufferP.copyMemory(from: $0)
            }
            return aggregateContextU
        }
    }
    
    private static func report(result: DatabaseValueConvertible?, in sqliteContext: OpaquePointer?) {
        switch result?.databaseValue.storage ?? .null {
        case .null:
            sqlite3_result_null(sqliteContext)
        case .int64(let int64):
            sqlite3_result_int64(sqliteContext, int64)
        case .double(let double):
            sqlite3_result_double(sqliteContext, double)
        case .string(let string):
            sqlite3_result_text(sqliteContext, string, -1, SQLITE_TRANSIENT)
        case .blob(let data):
            data.withUnsafeBytes {
                sqlite3_result_blob(sqliteContext, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
            }
        }
    }
    
    private static func report(error: Error, in sqliteContext: OpaquePointer?) {
        if let error = error as? DatabaseError {
            if let message = error.message {
                sqlite3_result_error(sqliteContext, message, -1)
            }
            sqlite3_result_error_code(sqliteContext, error.extendedResultCode.rawValue)
        } else {
            sqlite3_result_error(sqliteContext, "\(error)", -1)
        }
    }
}

extension DatabaseFunction {
    /// :nodoc:
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identity)
    }
    
    /// Two functions are equal if they share the same name and arity.
    /// :nodoc:
    public static func == (lhs: DatabaseFunction, rhs: DatabaseFunction) -> Bool {
        lhs.identity == rhs.identity
    }
}

/// The protocol for custom SQLite aggregates.
///
/// For example:
///
///     struct MySum : DatabaseAggregate {
///         var sum: Int = 0
///
///         mutating func step(_ dbValues: [DatabaseValue]) {
///             if let int = Int.fromDatabaseValue(dbValues[0]) {
///                 sum += int
///             }
///         }
///
///         func finalize() -> DatabaseValueConvertible? {
///             return sum
///         }
///     }
///
///     let dbQueue = DatabaseQueue()
///     let fn = DatabaseFunction("mysum", argumentCount: 1, aggregate: MySum.self)
///     try dbQueue.write { db in
///         db.add(function: fn)
///         try db.execute(sql: "CREATE TABLE test(i)")
///         try db.execute(sql: "INSERT INTO test(i) VALUES (1)")
///         try db.execute(sql: "INSERT INTO test(i) VALUES (2)")
///         try Int.fetchOne(db, sql: "SELECT mysum(i) FROM test")! // 3
///     }
public protocol DatabaseAggregate {
    /// Creates an aggregate.
    init()
    
    /// This method is called at each step of the aggregation.
    ///
    /// The dbValues argument contains as many values as given to the SQL
    /// aggregate function.
    ///
    ///    -- One value
    ///    SELECT maxLength(name) FROM player
    ///
    ///    -- Two values
    ///    SELECT maxFullNameLength(firstName, lastName) FROM player
    ///
    /// This method is never called after the finalize() method has been called.
    mutating func step(_ dbValues: [DatabaseValue]) throws
    
    /// Returns the final result
    func finalize() throws -> DatabaseValueConvertible?
}
