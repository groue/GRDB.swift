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
// You can copy this file into your project, source code and license.
//

import SwiftUI

/// The environment key that lets SwiftUI access the database.
private struct AppDatabaseKey: EnvironmentKey {
    /// The default appDatabase is an empty in-memory database
    static var defaultValue: AppDatabase { .empty() }
}

extension EnvironmentValues {
    /// The environment value that lets SwiftUI access the database.
    ///
    /// Usage:
    ///
    ///     struct MyView {
    ///         @Environment(\.appDatabase) private var appDatabase
    ///
    ///         var body: some View {
    ///             Button {
    ///                 try {
    ///                     try appDatabase.deleteAllPlayers()
    ///                 } catch { ... }
    ///             } label: { Image(systemName: "trash") }
    ///         }
    ///     }
    var appDatabase: AppDatabase {
        get { self[AppDatabaseKey.self] }
        set { self[AppDatabaseKey.self] = newValue }
    }
}

/// The protocol that feeds the `@Query` property wrapper.
///
/// For example:
///
///     // Tracks the number of players
///     struct PlayerCount: Queryable {
///         static var defaultValue: Int { 0 }
///
///         func values(in appDatabase: AppDatabase) -> AsyncValueObservation<Int> {
///             ValueObservation
///                 .trackingConstantRegion(Player.fetchCount)
///                 .values(in: appDatabase.databaseReader, scheduling: .immediate)
///         }
///     }
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

/// The property wrapper that tells SwiftUI about changes in the database.
/// See `Queryable`.
///
/// For example:
///
///     // Tracks the number of players
///     struct PlayerCount: Queryable {
///         static var defaultValue: Int { 0 }
///
///         func values(in appDatabase: AppDatabase) -> AsyncValueObservation<Int> {
///             ValueObservation
///                 .trackingConstantRegion(Player.fetchCount)
///                 .values(in: appDatabase.databaseReader, scheduling: .immediate)
///         }
///     }
///
///     struct MyView {
///         @Query(PlayerCount()) private var playerCount
///
///         var body: some View {
///             Text("\(playerCount) Players")
///         }
///     }
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
