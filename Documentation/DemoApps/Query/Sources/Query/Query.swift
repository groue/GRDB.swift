// Copyright (C) 2021 Gwendal Roué
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
// You can copy this file into your project, source code and license.
//

import Combine
import SwiftUI

/// The protocol for types that feed the `@Query` property wrapper.
public protocol Queryable: Equatable {
    /// The type of the Database
    associatedtype DatabaseType
    
    /// The type of the value publisher
    associatedtype PublisherType: Publisher
    
    /// The default value, used whenever the database is not available
    static var defaultValue: PublisherType.Output { get }
    
    /// Returns a publisher of database values
    func publisher(in database: DatabaseType) -> PublisherType
}

/// The property wrapper that tells SwiftUI about changes in the database.
/// See `Queryable`.
@propertyWrapper
public struct Query<QueryableType: Queryable>: DynamicProperty {
    /// The type of the observed value
    public typealias Value = QueryableType.PublisherType.Output
    
    /// Database access
    @Environment private var database: QueryableType.DatabaseType
    
    /// The object that keeps on observing the database as long as it is alive.
    @StateObject private var tracker = Tracker()
    
    private let initialQuery: QueryableType
    
    /// The observed value.
    public var wrappedValue: Value {
        tracker.value ?? QueryableType.defaultValue
    }
    
    /// A binding to the query, that lets your views modify it.
    public var projectedValue: Binding<QueryableType> {
        Binding(
            get: { tracker.query ?? initialQuery },
            set: { tracker.query = $0 })
    }
    
    /// Creates a `Query`, given a queryable value, and a key path to the
    /// database in the environment.
    public init(
        _ query: QueryableType,
        in keyPath: KeyPath<EnvironmentValues, QueryableType.DatabaseType>)
    {
        _database = Environment(keyPath)
        initialQuery = query
    }
    
    public func update() {
        // Feed tracker with necessary information,
        // and make sure tracking has started.
        if tracker.query == nil {
            tracker.query = initialQuery
        }
        tracker.startTrackingIfNecessary(in: database)
    }
    
    private class Tracker: ObservableObject {
        private(set) var value: Value?
        var query: QueryableType? {
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
        
        func startTrackingIfNecessary(in database: QueryableType.DatabaseType) {
            guard let query = query else {
                // No query set
                return
            }
            
            guard cancellable == nil else {
                // Already tracking
                return
            }
            
            cancellable = query.publisher(in: database).sink(
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
