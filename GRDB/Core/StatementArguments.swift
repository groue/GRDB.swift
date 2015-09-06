/**
SQL statements can have arguments:

    INSERT INTO persons (name, age) VALUES (?, ?)
    INSERT INTO persons (name, age) VALUES (:name, :age)

To fill question mark arguments, feed StatementArguments with an array:

    db.execute("INSERT ... (?, ?)", arguments: StatementArguments(["Arthur", 41]))

Array literals are automatically converted to StatementArguments:

    db.execute("INSERT ... (?, ?)", arguments: ["Arthur", 41])

To fill named arguments, feed StatementArguments with a dictionary:

    db.execute("INSERT ... (:name, :age)", arguments: StatementArguments(["name": "Arthur", "age": 41]))

Dictionary literals are automatically converted to StatementArguments:

    db.execute("INSERT ... (:name, :age)", arguments: ["name": "Arthur", "age": 41])

GRDB.swift only supports colon-prefixed named arguments, even though SQLite
supports other syntaxes. See https://www.sqlite.org/lang_expr.html#varparam for
more information.
*/
public struct StatementArguments {
    
    // MARK: - Positional Arguments
    
    /**
    Initializes arguments from a sequence of optional values.
    
        let values: [String?] = ["foo", "bar", nil]
        db.execute("INSERT ... (?,?,?)", arguments: StatementArguments(values))
    
    - parameter sequence: A sequence of optional values that adopt the
                          DatabaseValueConvertible protocol.
    - returns: A StatementArguments.
    */
    public init<Sequence: SequenceType where Sequence.Generator.Element == Optional<DatabaseValueConvertible>>(_ sequence: Sequence) {
        impl = StatementArgumentsArrayImpl(values: Array(sequence))
    }
    
    
    // MARK: - Named Arguments
    
    /**
    Initializes arguments from a dictionary of optional values.
    
        let values: [String: String?] = ["firstName": nil, "lastName": "Miller"]
        db.execute("INSERT ... (:firstName, :lastName)", arguments: StatementArguments(values))
    
    GRDB.swift only supports colon-prefixed named arguments, even though SQLite
    supports other syntaxes. See https://www.sqlite.org/lang_expr.html#varparam
    for more information.
    
    - parameter dictionary: A dictionary of optional values that adopt the
                            DatabaseValueConvertible protocol.
    - returns: A StatementArguments.
    */
    public init(_ dictionary: [String: DatabaseValueConvertible?]) {
        impl = StatementArgumentsDictionaryImpl(dictionary: dictionary)
    }
    
    
    // MARK: - Not Public
    
    let impl: StatementArgumentsImpl
    
    // Supported usage: Statement.arguments property
    //
    //     let statement = db.UpdateStatement("INSERT INTO persons (name, age) VALUES (?,?)"
    //     statement.execute(arguments: ["Arthur", 41])
    func bindInStatement(statement: Statement) {
        impl.bindInStatement(statement)
    }
    
    
    // MARK: - StatementArgumentsArrayImpl
    
    /// Support for positional arguments
    private struct StatementArgumentsArrayImpl : StatementArgumentsImpl {
        let values: [DatabaseValueConvertible?]
        
        init(values: [DatabaseValueConvertible?]) {
            self.values = values
        }
        
        func bindInStatement(statement: Statement) {
            for (index, value) in values.enumerate() {
                statement.bind(value, atIndex: index + 1)
            }
        }
        
        var description: String {
            return "["
                + values
                    .map { value in
                        if let value = value {
                            return String(reflecting: value)
                        } else {
                            return "nil"
                        }
                    }
                    .joinWithSeparator(", ")
                + "]"
        }
    }
    
    
    // MARK: - StatementArgumentsDictionaryImpl
    
    /// Support for named arguments
    private struct StatementArgumentsDictionaryImpl : StatementArgumentsImpl {
        let dictionary: [String: DatabaseValueConvertible?]
        
        init(dictionary: [String: DatabaseValueConvertible?]) {
            self.dictionary = dictionary
        }
        
        func bindInStatement(statement: Statement) {
            for (key, value) in dictionary {
                statement.bind(value, forKey: key)
            }
        }
        
        var description: String {
            return "["
                + dictionary.map { (key, value) in
                    if let value = value {
                        return "\(key):\(String(reflecting: value))"
                    } else {
                        return "\(key):nil"
                    }
                    }
                    .joinWithSeparator(", ")
                + "]"
        }
    }
}


// The protocol for StatementArguments underlying implementation
protocol StatementArgumentsImpl : CustomStringConvertible {
    func bindInStatement(statement: Statement)
}


// MARK: - ArrayLiteralConvertible

extension StatementArguments : ArrayLiteralConvertible {
    /**
    Returns a StatementArguments from an array literal:

        db.selectRows("SELECT ...", arguments: ["Arthur", 41])
    */
    public init(arrayLiteral elements: DatabaseValueConvertible?...) {
        self.init(elements)
    }
}


// MARK: - DictionaryLiteralConvertible

extension StatementArguments : DictionaryLiteralConvertible {
    /**
    Returns a StatementArguments from a dictionary literal:
    
        db.selectRows("SELECT ...", arguments: ["name": "Arthur", "age": 41])
    */
    public init(dictionaryLiteral elements: (String, DatabaseValueConvertible?)...) {
        var dictionary = [String: DatabaseValueConvertible?]()
        for (key, value) in elements {
            dictionary[key] = value
        }
        self.init(dictionary)
    }
}


// MARK: - CustomStringConvertible

extension StatementArguments : CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        return impl.description
    }
}