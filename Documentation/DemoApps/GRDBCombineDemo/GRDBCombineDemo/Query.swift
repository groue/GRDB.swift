// Copyright (C) 2015-2021 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//
// Query.swift
//
// A property wrapper inspired from
// https://davedelong.com/blog/2021/04/03/core-data-and-swiftui/
//

import Combine
import GRDB
import SwiftUI

/// The protocol that feeds the `@Query` property wrapper.
protocol Queryable: Equatable {
    /// The type of the fetched value
    associatedtype Value
    
    /// The default value, used whenever the database is not available
    static var defaultValue: Value { get }
    
    /// Returns a publisher of database values
    func valuePublisher(in appDatabase: AppDatabase) -> AnyPublisher<Value, Error>
}

/// The property wrapper that observes a database query
@propertyWrapper
struct Query<Query: Queryable>: DynamicProperty {
    /// Database access
    @Environment(\.appDatabase) private var appDatabase
    @StateObject private var core = Core()
    private var baseQuery: Query
    
    /// The fetched value
    var wrappedValue: Query.Value {
        core.value ?? Query.defaultValue
    }
    
    /// A binding to the query, that lets your views modify it.
    ///
    /// This is how the demo app changes the player ordering.
    var projectedValue: Binding<Query> {
        Binding(
            get: { core.query ?? baseQuery },
            set: {
                core.usesBaseQuery = false
                core.query = $0
            })
    }
    
    init(_ query: Query) {
        baseQuery = query
    }
    
    func update() {
        // Feed core with necessary information, and make sure tracking has started
        if core.usesBaseQuery { core.query = baseQuery }
        core.startTrackingIfNecessary(in: appDatabase)
    }
    
    private class Core: ObservableObject {
        private(set) var value: Query.Value?
        var appDatabase: AppDatabase?
        var usesBaseQuery = true
        var query: Query? {
            willSet {
                if query != newValue {
                    // Stop tracking, and tell SwiftUI about the update
                    objectWillChange.send()
                    cancellable = nil
                }
            }
        }
        private var cancellable: AnyCancellable?
        
        init() { }
        
        func startTrackingIfNecessary(in appDatabase: AppDatabase) {
            guard let query = query else {
                // No query set
                return
            }
            
            guard cancellable == nil else {
                // Already tracking
                return
            }
            
            cancellable = query
                .valuePublisher(in: appDatabase)
                .sink(
                    receiveCompletion: { _ in
                        // Ignore errors
                    },
                    receiveValue: { [weak self] value in
                        guard let self = self else { return }
                        // Tell SwiftUI about the new value
                        self.objectWillChange.send()
                        self.value = value
                    })
        }
    }
}
