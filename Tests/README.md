Tests
=====

- [Carthage](Carthage)
    
    Projects that link against Carthage builds of GRDB.
    
    Before running them, build the GRDB frameworks:
    
    $ cd groue/GRDB.swift
    $ git submodule update --init
    $ carthage build --no-skip-current

- [Crash](Crash)

    Tests for crashs.

- [GRDBProfiling](GRDBProfiling)
    
    Performance tests embedded in an application, so that we can profile them with Instruments.

- [Performance](Performance)
    
    Performance tests for GRDB, raw SQLite, FMDB, SQLite.swift, Core Data, and Realm.

- [Private](Private)
    
    Tests for private APIs. There aren't many.

- [Public](Public)
    
    Tests for public APIs. Plenty, plenty of them.
