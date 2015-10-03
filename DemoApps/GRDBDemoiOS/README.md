GRDBDemoiOS
===========

This application runs an universal (iPhone + iPad) application that displays an editable list of persons.

To see usage of GRDB, check the following files:

- [AppDelegate.swift](GRDBDemoiOS/AppDelegate.swift)

    AppDelegate sets up a global dbQueue that is accessible in the whole application.
    
    It uses migrations to initialize the database.

- [MasterViewController.swift](GRDBDemoiOS/MasterViewController.swift)
    
    MasterViewController is responsible for displaying the list of persons in a table view, deleting persons, and present a person edition form.

- [Person.swift](GRDBDemoiOS/Person.swift)
    
    Person is a simple Record subclass.

- [DetailViewController.swift](GRDBDemoiOS/DetailViewController.swift) and [PersonEditionViewController.swift](GRDBDemoiOS/PersonEditionViewController.swift)
    
    Those two view controllers display and edit a Person, in total isolation from the database.
