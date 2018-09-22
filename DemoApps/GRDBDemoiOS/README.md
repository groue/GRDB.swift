Demo Application
================

<p align="center">
    <img src="https://github.com/groue/GRDB.swift/raw/development/Documentation/Images/GRDBDemoScreenshot.png" width="50%">
</p>

Files of interest are:

- [AppDelegate.swift](GRDBDemoiOS/AppDelegate.swift)
    
    `AppDelegate` initializes, on application startup, a unique instance of [DatabaseQueue](../../README.md#database-queues) available for the whole application.

- [AppDatabase.swift](GRDBDemoiOS/AppDatabase.swift)
    
    `AppDatabase` is responsible for the format of the application database. It uses [DatabaseMigrator](../../README.md#migrations) in order to setup the database schema.

- [Player.swift](GRDBDemoiOS/Player.swift)
    
    `Player` is a [Record](../../README.md#records) type, able to read and write in the database. It conforms to the standard Codable protocol in order to gain all advantages of [Codable Records](../../README.md#codable-records).