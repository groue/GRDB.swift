Combine + SwiftUI Demo Application
==================================

<img align="right" src="https://github.com/groue/GRDB.swift/raw/master/Documentation/DemoApps/GRDBCombineDemo/Screenshot.png" width="50%">

**This demo application is a Combine + SwiftUI application.** For a demo application that uses UIKit, see [GRDBDemoiOS](../GRDBDemoiOS/README.md), and for Async/Await + SwiftUI, see [GRDBAsyncDemo](../GRDBAsyncDemo/README.md).

**Requirements**: iOS 15.0+ / Xcode 12+

> **Note**: This demo app is not a project template. Do not copy it as a starting point for your application. Instead, create a new project, choose a GRDB [installation method](../../../README.md#installation), and use the demo as an inspiration.

The topics covered in this demo are:

- How to setup a database in an iOS app.
- How to define a simple [Codable Record](../../../README.md#codable-records).
- How to track database changes and animate a SwiftUI List with [ValueObservation](../../../README.md#valueobservation) Combine publishers.
- How to apply the recommendations of [Good Practices for Designing Record Types](../../GoodPracticesForDesigningRecordTypes.md).
- How to feed SwiftUI previews with a transient database.

**Files of interest:**

- [GRDBCombineDemoApp.swift](GRDBCombineDemo/GRDBCombineDemoApp.swift)
    
    `GRDBCombineDemoApp` feeds the app views with a database, through the SwiftUI environment.

- [AppDatabase.swift](GRDBCombineDemo/AppDatabase.swift)
    
    `AppDatabase` is the type that grants database access. It uses [DatabaseMigrator](../../Migrations.md) in order to setup the database schema.

- [Persistence.swift](GRDBCombineDemo/Persistence.swift)
    
    This file instantiates various `AppDatabase` for the various projects needs: one database on disk for the application, and in-memory databases for SwiftUI previews.

- [Player.swift](GRDBCombineDemo/Player.swift)
    
    `Player` is a [Record](../../../README.md#records) type, able to read and write in the database. It conforms to the standard Codable protocol in order to gain all advantages of [Codable Records](../../../README.md#codable-records).

- [PlayerRequest.swift](GRDBCombineDemo/PlayerRequest.swift), [AppView.swift](GRDBCombineDemo/Views/AppView.swift)
    
    `PlayerRequest` defines the player requests used by the app (sorted by score, or by name).
    
    `PlayerRequest` feeds the `@Query` property wrapper (`@Query`, defined in [GRDBQuery](https://github.com/groue/GRDBQuery), allows SwiftUI views to display up-to-date database content).
    
    `AppView` is the SwiftUI view that uses `@Query` in order to feed its player list.

- [GRDBCombineDemoTests](GRDBCombineDemoTests)
    
    - Test the database schema
    - Test the `Player` record and its requests
    - Test the `PlayerRequest` methods that feed the list of players.
    - Test the `AppDatabase` methods that let the app access the database.
