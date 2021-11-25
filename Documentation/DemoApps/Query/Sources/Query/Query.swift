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
    /// The type of the database found in the SwiftUI environment.
    associatedtype DatabaseContext
    
    /// The type of the value publisher
    associatedtype ValuePublisher: Publisher
    
    /// The default value, used until the publisher publishes its initial value.
    /// It is never used if the publisher publishes its initial value right
    /// on subscription.
    static var defaultValue: Value { get }
    
    /// Publishes database values
    func publisher(in database: DatabaseContext) -> ValuePublisher
}

extension Queryable {
    /// Convenience access to the type of the published values
    public typealias Value = ValuePublisher.Output
}

/// The property wrapper that tells SwiftUI about changes in the database.
/// See `Queryable`.
@propertyWrapper
public struct Query<Request: Queryable>: DynamicProperty {
    /// Database access
    @Environment private var database: Request.DatabaseContext
    
    /// The object that keeps on observing the database as long as it is alive.
    @StateObject private var tracker = Tracker()
    
    private let initialRequest: Request
    
    /// The observed value.
    public var wrappedValue: Request.Value {
        tracker.value ?? Request.defaultValue
    }
    
    /// A binding to the request, that lets your views modify it.
    public var projectedValue: Binding<Request> {
        Binding(
            get: { tracker.request ?? initialRequest },
            set: { tracker.request = $0 })
    }
    
    /// Creates a `Query`, given a queryable request, and a key path to the
    /// database in the environment.
    public init(
        _ request: Request,
        in keyPath: KeyPath<EnvironmentValues, Request.DatabaseContext>)
    {
        _database = Environment(keyPath)
        initialRequest = request
    }
    
    public func update() {
        // Feed tracker with necessary information,
        // and make sure tracking has started.
        if tracker.request == nil {
            tracker.request = initialRequest
        }
        tracker.startTrackingIfNecessary(in: database)
    }
    
    /// The object that keeps on observing the database as long as it is alive.
    private class Tracker: ObservableObject {
        private(set) var value: Request.Value?
        var request: Request? {
            willSet {
                if request != newValue {
                    // Stop tracking, and tell SwiftUI about the update
                    objectWillChange.send()
                    cancellable = nil
                }
            }
        }
        private var cancellable: AnyCancellable?
        
        init() { }
        
        func startTrackingIfNecessary(in database: Request.DatabaseContext) {
            guard let request = request else {
                // No request set
                return
            }
            
            guard cancellable == nil else {
                // Already tracking
                return
            }
            
            cancellable = request.publisher(in: database).sink(
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
