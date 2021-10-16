Async/Await + SwiftUI Demo Application
======================================

<img align="right" src="https://github.com/groue/GRDB.swift/raw/master/Documentation/DemoApps/GRDBAsyncDemo/Screenshot.png" width="50%">

**This demo application is an Async/Await + SwiftUI application.** For a demo application that uses UIKit, see [GRDBDemoiOS](../GRDBDemoiOS/README.md), and for Combine + SwiftUI, see [GRDBCombineDemo](../GRDBCombineDemo/README.md).

> :point_up: **Note**: This demo app is not a project template. Do not copy it as a starting point for your application. Instead, create a new project, choose a GRDB [installation method](../../../README.md#installation), and use the demo as an inspiration.

The topics covered in this demo are:

- How to setup a database in an iOS app.
- How to define a simple [Codable Record](../../../README.md#codable-records).
- How to track database changes and animate a SwiftUI List with an async sequence built from [ValueObservation](../../../README.md#valueobservation).
- How to apply the recommendations of [Good Practices for Designing Record Types](../../GoodPracticesForDesigningRecordTypes.md).
- How to feed SwiftUI previews with a transient database.

**Files of interest:**

- [GRDBAsyncDemoApp.swift](GRDBAsyncDemo/GRDBAsyncDemoApp.swift)
    
    `GRDBAsyncDemoApp` feeds the app views with a database, through the SwiftUI environment.

- [AppDatabase.swift](GRDBAsyncDemo/AppDatabase.swift)
    
    `AppDatabase` is the type that grants database access. It uses [DatabaseMigrator](../../Migrations.md) in order to setup the database schema.

- [Persistence.swift](GRDBAsyncDemo/Persistence.swift)
    
    This file instantiates various `AppDatabase` for the various projects needs: one database on disk for the application, and in-memory databases for SwiftUI previews.

- [Player.swift](GRDBAsyncDemo/Player.swift)
    
    `Player` is a [Record](../../../README.md#records) type, able to read and write in the database. It conforms to the standard Codable protocol in order to gain all advantages of [Codable Records](../../../README.md#codable-records).

- [PlayerRequest.swift](GRDBAsyncDemo/PlayerRequest.swift), [Query.swift](GRDBAsyncDemo/Query.swift), [AppView.swift](GRDBAsyncDemo/Views/AppView.swift)
    
    `PlayerRequest` defines the player requests used by the app (sorted by score, or by name).
    
    `PlayerRequest` feeds the `@Query` property wrapper. `@Query`, inspired by [this article](https://davedelong.com/blog/2021/04/03/core-data-and-swiftui/), allows SwiftUI views to display up-to-date database content thanks to GRDB's [ValueObservation](../../../README.md#valueobservation).
    
    `AppView` is the SwiftUI view that uses `@Query` in order to feed its player list.

- [GRDBAsyncDemoTests](GRDBAsyncDemoTests)
    
    - Test the database schema
    - Test the `Player` record and its requests
    - Test the `PlayerRequest` methods that feed the list of players.
    - Test the `AppDatabase` methods that let the app access the database.
