GRDBDemo Application
====================

<img align="right" src="https://github.com/groue/GRDB.swift/raw/master/Documentation/DemoApps/GRDBDemo/Screenshot.png" width="50%">

**GRDBDemo demonstrates how GRDB can fuel a SwiftUI application.**

> **Note**: This demo app is not a project template. Do not copy it as a starting point for your application. Instead, create a new project, choose a GRDB [installation method](../../../README.md#installation), and use the demo as an inspiration.

The topics covered in this demo are:

- How to setup a database in an iOS app.
- How to define a simple [Codable Record](../../../README.md#codable-records).
- How to track database changes and animate a SwiftUI List with [ValueObservation](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/valueobservation).
- How to apply the recommendations of [Recommended Practices for Designing Record Types](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/recordrecommendedpractices).
- How to feed SwiftUI previews with a transient database.

**Files of interest:**

- [GRDBDemoApp.swift](GRDBDemo/GRDBDemoApp.swift)
    
    `GRDBDemoApp` feeds the SwiftUI app with a database, through the SwiftUI environment.

- [AppDatabase.swift](GRDBDemo/Database/AppDatabase.swift)
    
    `AppDatabase` is the type that grants database access. It uses [DatabaseMigrator](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasemigrator) in order to setup the database schema, and provides methods that read and write.
    
    `AppDatabase` is [tested](GRDBDemoTests/AppDatabaseTests.swift).

- [Persistence.swift](GRDBDemo/Database/Persistence.swift)
    
    This file instantiates various `AppDatabase` for the various projects needs: one database on disk for the application, and in-memory databases for SwiftUI previews.

- [Player.swift](GRDBDemo/Database/Models/Player.swift)
    
    `Player` is a [Record](../../../README.md#records) type, able to read and write in the database. It conforms to the standard Codable protocol in order to gain all advantages of [Codable Records](../../../README.md#codable-records).

- [PlayerListModel.swift](GRDBDemo/Views/PlayerListModel.swift)

    `PlayerListModel` is an `@Observable` object that observes the database, displays always fresh values on screen, and performs actions.
    
    `PlayerListModel` is [tested](GRDBDemoTests/PlayerListModelTests.swift).

- [PlayersNavigationView.swift](GRDBDemo/Views/PlayersNavigationView.swift)

    `PlayersNavigationView` is the main navigation view of the application. It instantiates a `PlayerListModel` from the `AppDatabase` stored in the SwiftUI environment.
