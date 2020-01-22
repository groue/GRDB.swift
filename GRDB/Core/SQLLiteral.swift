/// SQLLiteral is a type which support [SQL
/// Interpolation](https://github.com/groue/GRDB.swift/blob/master/Documentation/SQLInterpolation.md).
///
/// For example:
///
///     try dbQueue.write { db in
///         let name: String = ...
///         let id: Int64 = ...
///         let query: SQLLiteral = "UPDATE player SET name = \(name) WHERE id = \(id)"
///         try db.execute(literal: query)
///     }
public struct SQLLiteral {
    public var sql: String {
        return resolveWithDefaultContext().sql
    }
    
    public var arguments: StatementArguments {
        return resolveWithDefaultContext().arguments
    }
    
    let resolve: (inout SQLGenerationContext) -> String
    
    func resolveWithDefaultContext() -> (sql: String, arguments: StatementArguments) {
        var context = SQLGenerationContext.literalGenerationContext(withArguments: true)
        let sql = resolve(&context)
        return (sql: sql, arguments: context.arguments!)
    }
    
    init(_ resolve: @escaping (inout SQLGenerationContext) -> String) {
        self.resolve = resolve
    }
    
    /// Creates an SQLLiteral from a plain SQL string, and eventual arguments.
    ///
    /// For example:
    ///
    ///     let query = SQLLiteral(
    ///         sql: "UPDATE player SET name = ? WHERE id = ?",
    ///         arguments: [name, id])
    public init(sql: String, arguments: StatementArguments = StatementArguments()) {
        self.init({ context in
            if context.append(arguments: arguments) == false {
                // GRDB limitation: we don't know how to look for `?` in sql and
                // replace them with literals.
                fatalError("Not implemented")
            }
            return sql
        })
    }
    
    /// Returns a literal whose SQL is transformed by the given closure.
    public func mapSQL(_ transform: @escaping (String) -> String) -> SQLLiteral {
        flatMap { sql in
            SQLLiteral { _ in transform(sql) }
        }
    }
    
    func flatMap(_ transform: @escaping (_ sql: String) -> SQLLiteral) -> SQLLiteral {
        return SQLLiteral { context in
            transform(self.resolve(&context)).resolve(&context)
        }
    }
}

extension SQLLiteral: KeyPathRefining { }

extension SQLLiteral {
    /// Returns the SQLLiteral produced by the concatenation of two literals.
    ///
    ///     let name = "O'Brien"
    ///     let selection: SQLLiteral = "SELECT * FROM player "
    ///     let condition: SQLLiteral = "WHERE name = \(name)"
    ///     let query = selection + condition
    public static func + (lhs: SQLLiteral, rhs: SQLLiteral) -> SQLLiteral {
        var result = lhs
        result += rhs
        return result
    }
    
    /// Appends an SQLLiteral to the receiver.
    ///
    ///     let name = "O'Brien"
    ///     var query: SQLLiteral = "SELECT * FROM player "
    ///     query += "WHERE name = \(name)"
    public static func += (lhs: inout SQLLiteral, rhs: SQLLiteral) {
        lhs = lhs.flatMap { lSQL in
            SQLLiteral { context in
                lSQL + rhs.resolve(&context)
            }
        }
    }
    
    /// Appends an SQLLiteral to the receiver.
    ///
    ///     let name = "O'Brien"
    ///     var query: SQLLiteral = "SELECT * FROM player "
    ///     query.append(literal: "WHERE name = \(name)")
    public mutating func append(literal sqlLiteral: SQLLiteral) {
        self += sqlLiteral
    }
    
    /// Appends a plain SQL string to the receiver, and eventual arguments.
    ///
    ///     let name = "O'Brien"
    ///     var query: SQLLiteral = "SELECT * FROM player "
    ///     query.append(sql: "WHERE name = ?", arguments: [name])
    public mutating func append(sql: String, arguments: StatementArguments = StatementArguments()) {
        self += SQLLiteral(sql: sql, arguments: arguments)
    }
}

extension Sequence where Element == SQLLiteral {
    /// Returns the concatenated SQLLiteral of this sequence of literals,
    /// inserting the given separator between each element.
    ///
    ///     let components: [SQLLiteral] = [
    ///         "UPDATE player",
    ///         "SET name = \(name)",
    ///         "WHERE id = \(id)"
    ///     ]
    ///     let query = components.joined(separator: " ")
    public func joined(separator: String = "") -> SQLLiteral {
        // Calling the two properties `sql` and `arguments` must not consume the
        // sequence twice, or we would get inconsistent values if the sequence
        // does not yield the same elements on the two distinct iterations.
        // So let's turn the sequence into a collection first.
        //
        // TODO: consider deprecating the two `sql` and `arguments` properties,
        // and provide a more efficient implementation of this method.
        return Array(self).joined(separator: separator)
    }
}

extension Collection where Element == SQLLiteral {
    /// Returns the concatenated SQLLiteral of this collection of literals,
    /// inserting the given separator between each element.
    ///
    ///     let components: [SQLLiteral] = [
    ///         "UPDATE player",
    ///         "SET name = \(name)",
    ///         "WHERE id = \(id)"
    ///     ]
    ///     let query = components.joined(separator: " ")
    public func joined(separator: String = "") -> SQLLiteral {
        return SQLLiteral { context in
            self.map { $0.resolve(&context) }.joined(separator: separator)
        }
    }
}

// MARK: - ExpressibleByStringInterpolation

#if swift(>=5.0)
extension SQLLiteral: ExpressibleByStringInterpolation {
    /// :nodoc
    public init(unicodeScalarLiteral: String) {
        self.init(sql: unicodeScalarLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(extendedGraphemeClusterLiteral: String) {
        self.init(sql: extendedGraphemeClusterLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(stringLiteral: String) {
        self.init(sql: stringLiteral, arguments: [])
    }
    
    /// :nodoc:
    public init(stringInterpolation sqlInterpolation: SQLInterpolation) {
        self.init(sql: sqlInterpolation.sql, arguments: sqlInterpolation.arguments)
    }
}
#endif
