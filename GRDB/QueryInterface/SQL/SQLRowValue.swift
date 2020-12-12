// Row values are available in SQLite 3.15+

/// A [row value](https://www.sqlite.org/rowvalue.html).
///
/// :nodoc:
public struct _SQLRowValue: SQLExpression {
    let expressions: [SQLExpression]
    
    /// SQLite row values were shipped in SQLite 3.15:
    /// https://www.sqlite.org/releaselog/3_15_0.html
    static let isAvailable = (sqlite3_libversion_number() >= 3015000)
    
    /// - precondition: `expressions` is not empty
    init(_ expressions: [SQLExpression]) {
        assert(!expressions.isEmpty)
        self.expressions = expressions
    }
    
    public func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        _SQLRowValue(expressions.map { $0._qualifiedExpression(with: alias) })
    }
    
    public func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws {
        if let expression = expressions.first, expressions.count == 1 {
            try expression._accept(&visitor)
        } else {
            try visitor.visit(self)
        }
    }
}

#if GRDBCUSTOMSQLITE || GRDBCIPHER
/// A [row value](https://www.sqlite.org/rowvalue.html) made of two expressions.
///
/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
public struct RowValue2<A: SQLExpressible, B: SQLExpressible>: SQLSpecificExpressible {
    private var a: A
    private var b: B
    
    public init(_ a: A, _ b: B) {
        self.a = a
        self.b = b
    }
    
    public var sqlExpression: SQLExpression {
        _SQLRowValue([a.sqlExpression, b.sqlExpression])
    }
}

extension RowValue2: SQLAssignable where A: ColumnExpression, B: ColumnExpression { }
#else
/// A [row value](https://www.sqlite.org/rowvalue.html) made of two expressions.
///
/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
@available(OSX 10.13, iOS 10.3.1, tvOS 10.3.1, watchOS 4, *)
public struct RowValue2<A: SQLExpressible, B: SQLExpressible>: SQLSpecificExpressible {
    private var a: A
    private var b: B
    
    public init(_ a: A, _ b: B) {
        self.a = a
        self.b = b
    }
    
    public var sqlExpression: SQLExpression {
        _SQLRowValue([a.sqlExpression, b.sqlExpression])
    }
}

@available(OSX 10.13, iOS 10.3.1, tvOS 10.3.1, watchOS 4, *)
extension RowValue2: SQLAssignable where A: ColumnExpression, B: ColumnExpression { }
#endif

#if GRDBCUSTOMSQLITE || GRDBCIPHER
/// A [row value](https://www.sqlite.org/rowvalue.html) made of three expressions.
///
/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
public struct RowValue3<A: SQLExpressible, B: SQLExpressible, C: SQLExpressible>: SQLSpecificExpressible {
    private var a: A
    private var b: B
    private var c: C
    
    public init(_ a: A, _ b: B, _ c: C) {
        self.a = a
        self.b = b
        self.c = c
    }
    
    public var sqlExpression: SQLExpression {
        _SQLRowValue([a.sqlExpression, b.sqlExpression, c.sqlExpression])
    }
}

extension RowValue3: SQLAssignable where A: ColumnExpression, B: ColumnExpression, C: ColumnExpression { }
#else
/// A [row value](https://www.sqlite.org/rowvalue.html) made of three expressions.
///
/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
@available(OSX 10.13, iOS 10.3.1, tvOS 10.3.1, watchOS 4, *)
public struct RowValue3<A: SQLExpressible, B: SQLExpressible, C: SQLExpressible>: SQLSpecificExpressible {
    private var a: A
    private var b: B
    private var c: C
    
    public init(_ a: A, _ b: B, _ c: C) {
        self.a = a
        self.b = b
        self.c = c
    }
    
    public var sqlExpression: SQLExpression {
        _SQLRowValue([a.sqlExpression, b.sqlExpression, c.sqlExpression])
    }
}

@available(OSX 10.13, iOS 10.3.1, tvOS 10.3.1, watchOS 4, *)
extension RowValue3: SQLAssignable where A: ColumnExpression, B: ColumnExpression, C: ColumnExpression { }
#endif
