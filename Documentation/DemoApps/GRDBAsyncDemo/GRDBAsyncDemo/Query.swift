//
// Query.swift
//
// A property wrapper inspired from
// https://davedelong.com/blog/2021/04/03/core-data-and-swiftui/
//

import GRDB
import SwiftUI

/// The protocol that feeds the `@Query` property wrapper.
protocol Queryable: Equatable {
    /// The type of the sequence of database values
    associatedtype Sequence: AsyncSequence
    
    /// The type of the database values
    typealias Value = Sequence.Element
    
    /// The default value, used whenever the database is not available
    static var defaultValue: Value { get }
    
    /// Returns an asynchronous sequence of database values.
    func values(in appDatabase: AppDatabase) -> Sequence
}

/// The property wrapper that observes a database query
@propertyWrapper
struct Query<Query: Queryable>: DynamicProperty {
    /// The AppDatabase that grants access to the database
    @Environment(\.appDatabase) private var appDatabase: AppDatabase?
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
        guard let appDatabase = appDatabase else {
            fatalError("Attempting to use @Query without any database in the environment")
        }
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
                    task?.cancel()
                    task = nil
                }
            }
        }
        private var task: Task<Void, Error>?
        
        init() { }
        
        func startTrackingIfNecessary(in appDatabase: AppDatabase) {
            guard let query = query else {
                // No query set
                return
            }
            
            guard task == nil else {
                // Already tracking
                return
            }
            
            task = Task { @MainActor in
                for try await value in query.values(in: appDatabase) {
                    if Task.isCancelled { break }
                    self.objectWillChange.send()
                    self.value = value
                }
            }
        }
    }
}
