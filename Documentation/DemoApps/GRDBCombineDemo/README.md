Combine + SwiftUI Demo Application
==================================

<img align="right" src="https://github.com/groue/GRDB.swift/raw/master/Documentation/DemoApps/GRDBCombineDemo/Screenshot.png" width="50%">

**This demo application is a Combine + SwiftUI application, based on the MVVM design pattern.** For a demo application that uses UIKit, see [GRDBDemoiOS](../GRDBDemoiOS/README.md).

> :point_up: **Note**: This demo app is not a project template. Do not copy it as a starting point for your application. Instead, create a new project, choose a GRDB [installation method](../../../README.md#installation), and use the demo as an inspiration.

The topics covered in this demo are:

- How to setup a database in an iOS app.
- How to define a simple [Codable Record](../../../README.md#codable-records).
- How to track database changes and animate a SwiftUI List with [ValueObservation](../../../README.md#valueobservation) Combine publishers.
- How to apply the recommendations of [Good Practices for Designing Record Types](../../GoodPracticesForDesigningRecordTypes.md).
- How to feed SwiftUI previews with a transient database.

**Files of interest:**

- [GRDBCombineDemoApp.swift](GRDBCombineDemo/GRDBCombineDemoApp.swift)
    
    `GRDBCombineDemoApp` feeds the app views with a database.

- [AppDatabase.swift](GRDBCombineDemo/AppDatabase.swift)
    
    `AppDatabase` is the type that grants database access. It uses [DatabaseMigrator](../../Migrations.md) in order to setup the database schema, and [ValueObservation](../../../README.md#valueobservation) in order to let the application observe database changes.

- [Persistence.swift](GRDBCombineDemo/Persistence.swift)
    
    This file instantiates various `AppDatabase` for the various projects needs: one database on disk for the application, and in-memory databases for SwiftUI previews.

- [Player.swift](GRDBCombineDemo/Player.swift)
    
    `Player` is a [Record](../../../README.md#records) type, able to read and write in the database. It conforms to the standard Codable protocol in order to gain all advantages of [Codable Records](../../../README.md#codable-records). It defines the database requests used by the application.

- [PlayerList.swift](GRDBCombineDemo/Views/PlayerList.swift) and [PlayerListViewModel.swift](GRDBCombineDemo/ViewModels/PlayerListViewModel.swift)
    
    `PlayerList` is the SwiftUI view that displays the list of players, fed by `PlayerListViewModel`.

- [PlayerForm.swift](GRDBCombineDemo/Views/PlayerForm.swift), [PlayerEditionView.swift](GRDBCombineDemo/Views/PlayerEditionView.swift), [PlayerCreationSheet.swift](GRDBCombineDemo/Views/PlayerCreationSheet.swift) and [PlayerFormViewModel.swift](GRDBCombineDemo/ViewModels/PlayerFormViewModel.swift).
    
    `PlayerForm` is the SwiftUI view that displays a Player editing form. It is embedded in `PlayerEditionView` and `PlayerCreationSheet`, two SwiftUI views that edit or create a player. All those views are fed by `PlayerFormViewModel`.

- [GRDBCombineDemoTests](GRDBCombineDemoTests)
    
    - Test the database schema
    - Test the `Player` record and its requests
    - Test the `AppDatabase` methods that let the app access the database.
