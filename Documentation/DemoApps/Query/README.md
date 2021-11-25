# @Query

This package provides the `@Query` property wrapper, that lets your SwiftUI views automatically update their content when the database changes.

```swift
import Query
import SwiftUI

/// A view that displays an always up-to-date list of players in the database.
struct PlayerList: View {
    @Query(AllPlayers()) var players: [Player]
    
    var body: some View {
        List(players) { player in
            Text(player.name)
        }
    }
}
```

`@Query` is for GRDB what [`@FetchRequest`](https://developer.apple.com/documentation/swiftui/fetchrequest) is for Core Data. 

`@Query` is more a sample code than a standalone package. To use it, copy and embed this package in your application, or just the [Query.swift](Sources/Query/Query.swift) file.

## Why @Query?

**`@Query` solves a tricky problem.** It makes sure SwiftUI views are *immediately* rendered with the database content you expect.

For example, when you display a `List` that animates it changes, you usually do not want to see an animation for the *initial* state of the list.

All techniques based on `onAppear` suffer from this "double-rendering" problem and its side effects. By contrast, `@Query` has you covered.

## Usage

**To use `@Query`, first define a new environment key that grants access to the database.**

In the example below, we define a new `dbQueue` environment key whose value is a GRDB [DatabaseQueue]. Some other apps, like the GRDB [demo applications], can choose another name and another type, such as a "database manager" that encapsulates database accesses.

The [EnvironmentKey](https://developer.apple.com/documentation/swiftui/environmentkey) documentation describes the procedure:

```swift
import GRDB
import SwiftUI

private struct DatabaseQueueKey: EnvironmentKey {
    /// The default dbQueue is an empty in-memory database
    static var defaultValue: DatabaseQueue { DatabaseQueue() }
}

extension EnvironmentValues {
    var dbQueue: DatabaseQueue {
        get { self[DatabaseQueueKey.self] }
        set { self[DatabaseQueueKey.self] = newValue }
    }
}
```

You will substitute the default empty database with an actual database on disk for your main application:

```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            MyView().environment(\.dbQueue, /* some DatabaseQueue on disk */)
        }
    }
}
```

You will feed SwiftUI previews with databases that you want to preview:

```swift
struct PlayerList_Previews_Empty: PreviewProvider {
    static var previews: some View {
        PlayerList()
            .environment(\.dbQueue, /* some database with an empty table of players */)
    }
}

struct PlayerList_Previews_Populated: PreviewProvider {
    static var previews: some View {
        PlayerList()
            .environment(\.dbQueue, /* some database with an non-empty table of players */)
    }
}
```

See the GRDB [demo applications] for examples of such setups.

**Next, define a `Queryable` type for each database request you want to observe.**

For example:

```swift
import Combine
import GRDB
import Query

/// Tracks the full list of players
struct AllPlayers: Queryable {
    static var defaultValue: [Player] { [] }
    
    func publisher(in dbQueue: DatabaseQueue) -> AnyPublisher<[Player], Error> {
        ValueObservation
            .tracking { db in try Player.fetchAll(db) }
            // The `.immediate` scheduling feeds the view right on subscription,
            // and avoids an initial rendering with an empty list:
            .publisher(in: dbQueue, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}
```

**Finally**, you can define a SwiftUI view that automatically updates its content when the database changes:

```swift
import Query
import SwiftUI

struct PlayerList: View {
    @Query(AllPlayers(), in: \.dbQueue) var players
    
    var body: some View {
        List(players) { player in
            HStack {
                Text(player.name)
                Spacer()
                Text("\(player.score) points")
            }
        }
    }
}
```

`@Query` exposes a binding to the request, so that views can change the request when they need. The GRDB [demo applications], for example, use a [Queryable type](../GRDBCombineDemo/GRDBCombineDemo/PlayerRequest.swift) that can change the player ordering:

```swift
struct PlayerList: View {
    // Ordering can change through the $players.ordering binding.
    @Query(AllPlayers(ordering: .byScore)) var players
    ...
}
```

**As a convenience**, you can also define a dedicated `Query` initializer to use the `dbQueue` environment key automatically:

```swift
extension Query where Request.DatabaseContext == DatabaseQueue {
    init(_ request: Request) {
        self.init(request, in: \.dbQueue)
    }
}
```

This improves clarity at the call site:

```swift
struct MyPlayerList: View {
    @Query(AllPlayers()) var players
    ...
}
```

---

🙌 `@Query` was vastly inspired from [Core Data and SwiftUI](https://davedelong.com/blog/2021/04/03/core-data-and-swiftui/) by [@davedelong](https://github.com/davedelong), with critical improvements contributed by [@steipete](https://github.com/steipete). Many thanks to both of you!


[DatabaseQueue]: https://github.com/groue/GRDB.swift/blob/master/README.md#database-queues
[demo applications]: https://github.com/groue/GRDB.swift/tree/master/Documentation/DemoApps
