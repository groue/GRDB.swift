//
//  Bindings.swift
//  GRDB
//
//  Created by Gwendal Roué on 02/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

protocol BindingsImpl {
    func bindInStatement(statement: Statement)
}

public struct Bindings {
    let impl: BindingsImpl
    
    public init<C: CollectionType where C.Generator.Element == Optional<DatabaseValue>>(_ array: C) {
        impl = BindingsArrayImpl(array: array.map { $0 })
    }
    
    public init<C: CollectionType where C.Generator.Element == DatabaseValue>(_ array: C) {
        impl = BindingsArrayImpl(array: array.map { $0 })
    }
    
    public init(_ dictionary: [String: DatabaseValue?]) {
        impl = BindingsDictionaryImpl(dictionary: dictionary)
    }
    
    func bindInStatement(statement: Statement) {
        impl.bindInStatement(statement)
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
