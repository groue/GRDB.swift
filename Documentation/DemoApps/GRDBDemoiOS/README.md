UIKit Demo Application
======================

<img align="right" src="https://github.com/groue/GRDB.swift/raw/master/Documentation/DemoApps/GRDBDemoiOS/Screenshot.png" width="50%">

**This demo application is a storyboard-based UIKit application.** For a demo application that uses Combine and SwiftUI, see [GRDBCombineDemo](../GRDBCombineDemo/README.md).

> :point_up: **Note**: This demo app is not a project template. Do not copy it as a starting point for your application. Instead, create a new project, choose a GRDB [installation method](../../../README.md#installation), and use the demo as an inspiration.

The topics covered in this demo are:

- How to setup a database in an iOS app.
- How to define a simple [Codable Record](../../../README.md#codable-records).
- How to track database changes and animate a table view with [ValueObservation](../../../README.md#valueobservation).
- How to apply the recommendations of [Good Practices for Designing Record Types](../../GoodPracticesForDesigningRecordTypes.md).

**Files of interest:**

- [AppDatabase.swift](GRDBDemoiOS/AppDatabase.swift)
    
    `AppDatabase` is the type that grants database access. It uses [DatabaseMigrator](../../Migrations.md) in order to setup the database schema, and [ValueObservation](../../../README.md#valueobservation) in order to let the application observe database changes.

- [Persistence.swift](GRDBDemoiOS/Persistence.swift)
    
    This file defines the `AppDatabase` instance used by the application.

- [Player.swift](GRDBDemoiOS/Player.swift)
    
    `Player` is a [Record](../../../README.md#records) type, able to read and write in the database. It conforms to the standard Codable protocol in order to gain all advantages of [Codable Records](../../../README.md#codable-records). It defines the database requests used by the application.

- [PlayerListViewController.swift](GRDBDemoiOS/ViewControllers/PlayerListViewController.swift)
    
    `PlayerListViewController` displays the list of players.

- [PlayerEditionViewController.swift](GRDBDemoiOS/ViewControllers/PlayerEditionViewController.swift)
    
    `PlayerEditionViewController` can create or edit a player, and save it in the database.

- [GRDBDemoiOSTests](GRDBDemoiOSTests)
    
    - Test the database schema
    - Test the `Player` record and its requests
    - Test the `AppDatabase` methods that let the app access the database.
