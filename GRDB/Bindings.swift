//
//  Bindings.swift
//  GRDB
//
//  Created by Gwendal Roué on 02/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

protocol BindingsImpl {
    func bindInStatement(statement: Statement)
    func dictionary(defaultColumnNames defaultColumnNames: [String]?) -> [String: DatabaseValue?]
}

public struct Bindings {
    let impl: BindingsImpl
    
    public init<Sequence: SequenceType where Sequence.Generator.Element == Optional<DatabaseValue>>(_ array: Sequence) {
        impl = BindingsArrayImpl(array: Array(array))
    }
    
    public init<Sequence: SequenceType where Sequence.Generator.Element == DatabaseValue>(_ array: Sequence) {
        impl = BindingsArrayImpl(array: array.map { $0 })
    }
    
    public init(_ dictionary: [String: DatabaseValue?]) {
        impl = BindingsDictionaryImpl(dictionary: dictionary)
    }
    
    func bindInStatement(statement: Statement) {
        impl.bindInStatement(statement)
    }
    
    func dictionary(defaultColumnNames defaultColumnNames: [String]?) -> [String: DatabaseValue?] {
        return impl.dictionary(defaultColumnNames: defaultColumnNames)
    }
    
    private struct BindingsArrayImpl : BindingsImpl {
        let array: [DatabaseValue?]
        init(array: [DatabaseValue?]) {
            self.array = array
        }
        func bindInStatement(statement: Statement) {
            for (index, value) in array.enumerate() {
                statement.bind(value, atIndex: index + 1)
            }
        }
        func dictionary(defaultColumnNames defaultColumnNames: [String]?) -> [String : DatabaseValue?] {
            guard let defaultColumnNames = defaultColumnNames else {
                fatalError("Missing column names")
            }
            guard defaultColumnNames.count == array.count else {
                fatalError("Columns count mismatch.")
            }
            var dictionary = [String : DatabaseValue?]()
            for (column, value) in zip(defaultColumnNames, array) {
                dictionary[column] = value
            }
            return dictionary
        }
    }
    
    private struct BindingsDictionaryImpl : BindingsImpl {
        let dictionary: [String: DatabaseValue?]
        init(dictionary: [String: DatabaseValue?]) {
            self.dictionary = dictionary
        }
        func bindInStatement(statement: Statement) {
            for (key, value) in dictionary {
                statement.bind(value, forKey: key)
            }
        }
        func dictionary( defaultColumnNames defaultColumnNames: [String]?) -> [String : DatabaseValue?] {
            return dictionary
        }
    }
}

extension Bindings : ArrayLiteralConvertible {
    public init(arrayLiteral elements: DatabaseValue?...) {
        self.init(elements)
    }
}

extension Bindings : DictionaryLiteralConvertible {
    public init(dictionaryLiteral elements: (String, DatabaseValue?)...) {
        var dictionary = [String: DatabaseValue?]()
        for (key, value) in elements {
            dictionary[key] = value
        }
        self.init(dictionary)
    }
}
