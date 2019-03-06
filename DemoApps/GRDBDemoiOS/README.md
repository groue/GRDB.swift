Demo Application
================

<img align="right" src="https://github.com/groue/GRDB.swift/raw/master/Documentation/Images/GRDBDemoScreenshot.png" width="50%">

**This demo application shows you:**

- how to setup a database in an iOS app
- how to define a simple [Codable Record](../../README.md#codable-records)
- how to track database changes and animate a table view with [FetchedRecordsController](../../README.md#fetchedrecordscontroller).

**Files of interest:**

- [AppDelegate.swift](GRDBDemoiOS/AppDelegate.swift)
    
    `AppDelegate` creates, on application startup, a unique instance of [DatabaseQueue](../../README.md#database-queues) available for the whole application.

- [AppDatabase.swift](GRDBDemoiOS/AppDatabase.swift)
    
    `AppDatabase` defines the database for the whole application. It uses [DatabaseMigrator](../../README.md#migrations) in order to setup the database schema.

- [Player.swift](GRDBDemoiOS/Player.swift)
    
    `Player` is a [Record](../../README.md#records) type, able to read and write in the database. It conforms to the standard Codable protocol in order to gain all advantages of [Codable Records](../../README.md#codable-records).

- [PlayersViewController.swift](GRDBDemoiOS/PlayersViewController.swift)
    
    `PlayersViewController` displays a list of players. It keeps its title up-to-date with [ValueObservation](../../README.md#valueobservation), and animates its table view according to database changes with [FetchedRecordsController](../../README.md#fetchedrecordscontroller).

- [PlayerEditionViewController.swift](GRDBDemoiOS/PlayerEditionViewController.swift)
    
    `PlayerEditionViewController` can create or edit a player, and save it in the database.
