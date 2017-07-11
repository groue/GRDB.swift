import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class Observer : TransactionObserver {
    var lastCommittedEvents: [DatabaseEvent] = []
    var events: [DatabaseEvent] = []
    var commitError: Error?
    var deinitBlock: (() -> ())?
    var didCommitBlock: ((Database) -> ())?
    var observesBlock: (DatabaseEventKind) -> Bool
    
    init(observes observesBlock: @escaping (DatabaseEventKind) -> Bool = { _ in true }, didCommitBlock: ((Database) -> ())? = nil, deinitBlock: (() -> ())? = nil) {
        self.observesBlock = observesBlock
        self.didCommitBlock = didCommitBlock
        self.deinitBlock = deinitBlock
    }
    
    deinit {
        if let deinitBlock = deinitBlock {
            deinitBlock()
        }
    }
    
    var didChangeCount: Int = 0
    var willCommitCount: Int = 0
    var didCommitCount: Int = 0
    var didRollbackCount: Int = 0
    
    func resetCounts() {
        didChangeCount = 0
        willCommitCount = 0
        didCommitCount = 0
        didRollbackCount = 0
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            willChangeCount = 0
        #endif
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    var willChangeCount: Int = 0
    var lastCommittedPreUpdateEvents: [DatabasePreUpdateEvent] = []
    var preUpdateEvents: [DatabasePreUpdateEvent] = []
    func databaseWillChange(with event: DatabasePreUpdateEvent) {
        willChangeCount += 1
        preUpdateEvents.append(event.copy())
    }
    #endif
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return observesBlock(eventKind)
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        didChangeCount += 1
        events.append(event.copy())
    }
    
    func databaseWillCommit() throws {
        willCommitCount += 1
        if let commitError = commitError {
            throw commitError
        }
    }
    
    func databaseDidCommit(_ db: Database) {
        didCommitCount += 1
        lastCommittedEvents = events
        events = []
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            lastCommittedPreUpdateEvents = preUpdateEvents
            preUpdateEvents = []
        #endif
        didCommitBlock?(db)
    }
    
    func databaseDidRollback(_ db: Database) {
        didRollbackCount += 1
        lastCommittedEvents = []
        events = []
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            lastCommittedPreUpdateEvents = []
            preUpdateEvents = []
        #endif
    }
}

private class Artist : Record {
    var id: Int64?
    var name: String?
    
    init(id: Int64? = nil, name: String?) {
        self.id = id
        self.name = name
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(
            "CREATE TABLE artists (" +
                "id INTEGER PRIMARY KEY, " +
                "name TEXT" +
            ")")
    }
    
    // Record
    
    override class var databaseTableName: String {
        return "artists"
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
}

private class Artwork : Record {
    var id: Int64?
    var artistId: Int64?
    var title: String?
    
    init(id: Int64? = nil, title: String?, artistId: Int64? = nil) {
        self.id = id
        self.title = title
        self.artistId = artistId
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(
            "CREATE TABLE artworks (" +
                "id INTEGER PRIMARY KEY, " +
                "artistId INTEGER NOT NULL REFERENCES artists(id) ON DELETE CASCADE ON UPDATE CASCADE, " +
                "title TEXT" +
            ")")
    }
    
    // Record
    
    override class var databaseTableName: String {
        return "artworks"
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        title = row.value(named: "title")
        artistId = row.value(named: "artistId")
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["artistId"] = artistId
        container["title"] = title
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
}

class TransactionObserverTests: GRDBTestCase {
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try Artist.setup(inDatabase: db)
            try Artwork.setup(inDatabase: db)
        }
    }
    
    private func match(event: DatabaseEvent, kind: DatabaseEvent.Kind, tableName: String, rowId: Int64) -> Bool {
        return (event.tableName == tableName) && (event.rowID == rowId) && (event.kind == kind)
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    
    private func match(preUpdateEvent event: DatabasePreUpdateEvent, kind: DatabasePreUpdateEvent.Kind, tableName: String, initialRowID: Int64?, finalRowID: Int64?, initialValues: [DatabaseValue]?, finalValues: [DatabaseValue]?, depth: CInt = 0) -> Bool {
    
        func check(_ dbValues: [DatabaseValue]?, expected: [DatabaseValue]?) -> Bool {
            if let dbValues = dbValues {
                guard let expected = expected else { return false }
                return dbValues == expected
            }
            else { return expected == nil }
        }
        
        var count : Int = 0
        if let initialValues = initialValues { count = initialValues.count }
        if let finalValues = finalValues { count = max(count, finalValues.count) }
        
        guard (event.kind == kind) else { return false }
        guard (event.tableName == tableName) else { return false }
        guard (event.count == count) else { return false }
        guard (event.depth == depth) else { return false }
        guard (event.initialRowID == initialRowID) else { return false }
        guard (event.finalRowID == finalRowID) else { return false }
        guard check(event.initialDatabaseValues, expected: initialValues) else { return false }
        guard check(event.finalDatabaseValues, expected: finalValues) else { return false }
        
        return true
    }
    
    #endif
    
    // MARK: - Events
    
    func testInsertEvent() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.inDatabase { db in
            let artist = Artist(name: "Gerhard Richter")
            
            //
            try artist.save(db)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
            let event = observer.lastCommittedEvents.filter { event in
                self.match(event: event, kind: .insert, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
                               finalValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                        ])
                    }.first
                XCTAssertTrue(preUpdateEvent != nil)
            #endif
        }
    }

    func testUpdateEvent() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.inDatabase { db in
            let artist = Artist(name: "Gerhard Richter")
            try artist.save(db)
            artist.name = "Vincent Fournier"
            
            //
            try artist.save(db)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
            let event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .update, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .update, tableName: "artists", initialRowID: artist.id!, finalRowID: artist.id!,
                               initialValues: [
                                artist.id!.databaseValue,
                                "Gerhard Richter".databaseValue
                        ], finalValues: [
                            artist.id!.databaseValue,
                            "Vincent Fournier".databaseValue
                        ])
                    }.first
                XCTAssertTrue(preUpdateEvent != nil)
            #endif
        }
    }

    func testDeleteEvent() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.inDatabase { db in
            let artist = Artist(name: "Gerhard Richter")
            try artist.save(db)
            
            //
            try artist.delete(db)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
            let event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                               initialValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                        ], finalValues: nil)
                    }.first
                XCTAssertTrue(preUpdateEvent != nil)
            #endif
        }
    }

    func testTruncateOptimization() throws {
        // https://www.sqlite.org/c3ref/update_hook.html
        //
        // > In the current implementation, the update hook is not invoked [...]
        // > when rows are deleted using the truncate optimization.
        //
        // https://www.sqlite.org/lang_delete.html#truncateopt
        //
        // > When the WHERE is omitted from a DELETE statement and the table
        // > being deleted has no triggers, SQLite uses an optimization to erase
        // > the entire table content without having to visit each row of the
        // > table individually.
        //
        // Here we test that the truncate optimization does not prevent
        // transaction observers from observing individual deletions.
        
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.inDatabase { db in
            let artist1 = Artist(name: "Gerhard Richter")
            let artist2 = Artist(name: "Vincent Fournier")
            try artist1.insert(db)
            try artist2.insert(db)
            
            try db.execute("DELETE FROM artists")
            
            XCTAssertEqual(observer.lastCommittedEvents.count, 2)
            let artist1DeleteEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artists", rowId: artist1.id!)
                }.first
            XCTAssertTrue(artist1DeleteEvent != nil)
            let artist2DeleteEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artists", rowId: artist1.id!)
                }.first
            XCTAssertTrue(artist2DeleteEvent != nil)
        }
    }

    func testCascadingDeleteEvents() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.inDatabase { db in
            let artist = Artist(name: "Gerhard Richter")
            try artist.save(db)
            let artwork1 = Artwork(title: "Cloud", artistId: artist.id)
            try artwork1.save(db)
            let artwork2 = Artwork(title: "Ema (Nude on a Staircase)", artistId: artist.id)
            try artwork2.save(db)
            
            //
            try artist.delete(db)
            XCTAssertEqual(observer.lastCommittedEvents.count, 3)
            let artistEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(artistEvent != nil)
            let artwork1Event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork1.id!)
                }.first
            XCTAssertTrue(artwork1Event != nil)
            let artwork2Event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork2.id!)
                }.first
            XCTAssertTrue(artwork2Event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 3)
                let artistPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                               initialValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                        ], finalValues: nil)
                    }.first
                XCTAssertTrue(artistPreUpdateEvent != nil)
                let artwork1PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork1.id!, finalRowID: nil,
                               initialValues: [
                                artwork1.id!.databaseValue,
                                artwork1.artistId!.databaseValue,
                                artwork1.title!.databaseValue
                        ], finalValues: nil, depth: 1)
                    }.first
                XCTAssertTrue(artwork1PreUpdateEvent != nil)
                let artwork2PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork2.id!, finalRowID: nil,
                               initialValues: [
                                artwork2.id!.databaseValue,
                                artwork2.artistId!.databaseValue,
                                artwork2.title!.databaseValue
                        ], finalValues: nil, depth: 1)
                    }.first
                XCTAssertTrue(artwork2PreUpdateEvent != nil)
            #endif
        }
    }


    // MARK: - Commits & Rollback

    func testImplicitTransactionCommit() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        let artist = Artist(name: "Gerhard Richter")
        
        try dbQueue.inDatabase { db in
            observer.resetCounts()
            try artist.save(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
        }
    }

    func testCascadeWithImplicitTransactionCommit() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        let artist = Artist(name: "Gerhard Richter")
        let artwork1 = Artwork(title: "Cloud")
        let artwork2 = Artwork(title: "Ema (Nude on a Staircase)")
        
        try dbQueue.inDatabase { db in
            try artist.save(db)
            artwork1.artistId = artist.id
            artwork2.artistId = artist.id
            try artwork1.save(db)
            try artwork2.save(db)
            
            //
            observer.resetCounts()
            try artist.delete(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 3) // 3 deletes
            #endif
            XCTAssertEqual(observer.didChangeCount, 3) // 3 deletes
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            
            let artistDeleteEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(artistDeleteEvent != nil)
            
            let artwork1DeleteEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork1.id!)
                }.first
            XCTAssertTrue(artwork1DeleteEvent != nil)
            
            let artwork2DeleteEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork2.id!)
                }.first
            XCTAssertTrue(artwork2DeleteEvent != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 3)
                let artistPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                               initialValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                        ], finalValues: nil)
                    }.first
                XCTAssertTrue(artistPreUpdateEvent != nil)
                let artwork1PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork1.id!, finalRowID: nil,
                               initialValues: [
                                artwork1.id!.databaseValue,
                                artwork1.artistId!.databaseValue,
                                artwork1.title!.databaseValue
                        ], finalValues: nil, depth: 1)
                    }.first
                XCTAssertTrue(artwork1PreUpdateEvent != nil)
                let artwork2PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork2.id!, finalRowID: nil,
                               initialValues: [
                                artwork2.id!.databaseValue,
                                artwork2.artistId!.databaseValue,
                                artwork2.title!.databaseValue
                        ], finalValues: nil, depth: 1)
                    }.first
                XCTAssertTrue(artwork2PreUpdateEvent != nil)
            #endif
        }
    }

    func testExplicitTransactionCommit() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        let artist = Artist(name: "Gerhard Richter")
        let artwork1 = Artwork(title: "Cloud")
        let artwork2 = Artwork(title: "Ema (Nude on a Staircase)")
        
        try dbQueue.inTransaction { db in
            observer.resetCounts()
            try artist.save(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
            
            artwork1.artistId = artist.id
            artwork2.artistId = artist.id
            
            observer.resetCounts()
            try artwork1.save(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
            
            observer.resetCounts()
            try artwork2.save(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
            
            observer.resetCounts()
            return .commit
        }
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.willChangeCount, 0)
        #endif
        XCTAssertEqual(observer.didChangeCount, 0)
        XCTAssertEqual(observer.willCommitCount, 1)
        XCTAssertEqual(observer.didCommitCount, 1)
        XCTAssertEqual(observer.didRollbackCount, 0)
        XCTAssertEqual(observer.lastCommittedEvents.count, 3)
        
        let artistEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artists", rowId: artist.id!)
            }.first
        XCTAssertTrue(artistEvent != nil)
        
        let artwork1Event = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artworks", rowId: artwork1.id!)
            }.first
        XCTAssertTrue(artwork1Event != nil)
        
        let artwork2Event = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artworks", rowId: artwork2.id!)
            }.first
        XCTAssertTrue(artwork2Event != nil)
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 3)
            let artistPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!,
                           initialValues: nil, finalValues: [
                            artist.id!.databaseValue,
                            artist.name!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artistPreUpdateEvent != nil)
            let artwork1PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork1.id!,
                           initialValues: nil, finalValues: [
                            artwork1.id!.databaseValue,
                            artwork1.artistId!.databaseValue,
                            artwork1.title!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artwork1PreUpdateEvent != nil)
            let artwork2PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork2.id!,
                           initialValues: nil, finalValues: [
                            artwork2.id!.databaseValue,
                            artwork2.artistId!.databaseValue,
                            artwork2.title!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artwork2PreUpdateEvent != nil)
        #endif
    }

    func testCascadeWithExplicitTransactionCommit() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        let artist = Artist(name: "Gerhard Richter")
        let artwork1 = Artwork(title: "Cloud")
        let artwork2 = Artwork(title: "Ema (Nude on a Staircase)")
        
        try dbQueue.inTransaction { db in
            try artist.save(db)
            artwork1.artistId = artist.id
            artwork2.artistId = artist.id
            try artwork1.save(db)
            try artwork2.save(db)
            
            //
            observer.resetCounts()
            try artist.delete(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 3) // 3 deletes
            #endif
            XCTAssertEqual(observer.didChangeCount, 3) // 3 deletes
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
            
            observer.resetCounts()
            return .commit
        }
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.willChangeCount, 0)
        #endif
        XCTAssertEqual(observer.didChangeCount, 0)
        XCTAssertEqual(observer.willCommitCount, 1)
        XCTAssertEqual(observer.didCommitCount, 1)
        XCTAssertEqual(observer.didRollbackCount, 0)
        XCTAssertEqual(observer.lastCommittedEvents.count, 6)  // 3 inserts, and 3 deletes
        
        let artistInsertEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artists", rowId: artist.id!)
            }.first
        XCTAssertTrue(artistInsertEvent != nil)
        
        let artwork1InsertEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artworks", rowId: artwork1.id!)
            }.first
        XCTAssertTrue(artwork1InsertEvent != nil)
        
        let artwork2InsertEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .insert, tableName: "artworks", rowId: artwork2.id!)
            }.first
        XCTAssertTrue(artwork2InsertEvent != nil)
        
        let artistDeleteEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .delete, tableName: "artists", rowId: artist.id!)
            }.first
        XCTAssertTrue(artistDeleteEvent != nil)
        
        let artwork1DeleteEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork1.id!)
            }.first
        XCTAssertTrue(artwork1DeleteEvent != nil)
        
        let artwork2DeleteEvent = observer.lastCommittedEvents.filter {
            self.match(event: $0, kind: .delete, tableName: "artworks", rowId: artwork2.id!)
            }.first
        XCTAssertTrue(artwork2DeleteEvent != nil)
        
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 6)  // 3 inserts, and 3 deletes
            let artistInsertPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!,
                           initialValues: nil, finalValues: [
                            artist.id!.databaseValue,
                            artist.name!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artistInsertPreUpdateEvent != nil)
            let artwork1InsertPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork1.id!,
                           initialValues: nil, finalValues: [
                            artwork1.id!.databaseValue,
                            artwork1.artistId!.databaseValue,
                            artwork1.title!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artwork1InsertPreUpdateEvent != nil)
            let artwork2InsertPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork2.id!,
                           initialValues: nil, finalValues: [
                            artwork2.id!.databaseValue,
                            artwork2.artistId!.databaseValue,
                            artwork2.title!.databaseValue
                    ])
                }.first
            XCTAssertTrue(artwork2InsertPreUpdateEvent != nil)
            
            let artistDeletePreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                           initialValues: [
                            artist.id!.databaseValue,
                            artist.name!.databaseValue
                    ], finalValues: nil)
                }.first
            XCTAssertTrue(artistDeletePreUpdateEvent != nil)
            let artwork1DeletePreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork1.id!, finalRowID: nil,
                           initialValues: [
                            artwork1.id!.databaseValue,
                            artwork1.artistId!.databaseValue,
                            artwork1.title!.databaseValue
                    ], finalValues: nil, depth: 1)
                }.first
            XCTAssertTrue(artwork1DeletePreUpdateEvent != nil)
            let artwork2DeletePreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                self.match(preUpdateEvent: event, kind: .delete, tableName: "artworks", initialRowID: artwork2.id!, finalRowID: nil,
                           initialValues: [
                            artwork2.id!.databaseValue,
                            artwork2.artistId!.databaseValue,
                            artwork2.title!.databaseValue
                    ], finalValues: nil, depth: 1)
                }.first
            XCTAssertTrue(artwork2DeletePreUpdateEvent != nil)
        #endif
    }

    func testExplicitTransactionRollback() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        let artist = Artist(name: "Gerhard Richter")
        let artwork1 = Artwork(title: "Cloud")
        let artwork2 = Artwork(title: "Ema (Nude on a Staircase)")
        
        try dbQueue.inTransaction { db in
            try artist.save(db)
            artwork1.artistId = artist.id
            artwork2.artistId = artist.id
            try artwork1.save(db)
            try artwork2.save(db)
            
            observer.resetCounts()
            return .rollback
        }
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.willChangeCount, 0)
        #endif
        XCTAssertEqual(observer.didChangeCount, 0)
        XCTAssertEqual(observer.willCommitCount, 0)
        XCTAssertEqual(observer.didCommitCount, 0)
        XCTAssertEqual(observer.didRollbackCount, 1)
    }

    func testImplicitTransactionRollbackCausedByDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        do {
            try dbQueue.inDatabase { db in
                do {
                    try Artwork(title: "meh").save(db)
                    XCTFail("Expected Error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                        XCTAssertEqual(observer.willChangeCount, 0)
                    #endif
                    XCTAssertEqual(observer.didChangeCount, 0)
                    XCTAssertEqual(observer.willCommitCount, 0)
                    XCTAssertEqual(observer.didCommitCount, 0)
                    XCTAssertEqual(observer.didRollbackCount, 0)
                    throw error
                }
            }
            XCTFail("Expected Error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
            #endif
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
        }
    }

    func testExplicitTransactionRollbackCausedByDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        do {
            try dbQueue.inTransaction { db in
                do {
                    try Artwork(title: "meh").save(db)
                    XCTFail("Expected Error")
                } catch let error as DatabaseError {
                    // Immediate constraint check has failed.
                    XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                        XCTAssertEqual(observer.willChangeCount, 0)
                    #endif
                    XCTAssertEqual(observer.didChangeCount, 0)
                    XCTAssertEqual(observer.willCommitCount, 0)
                    XCTAssertEqual(observer.didCommitCount, 0)
                    XCTAssertEqual(observer.didRollbackCount, 0)
                    throw error
                }
                return .commit
            }
            XCTFail("Expected Error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
            #endif
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 1)
        }
    }

    func testImplicitTransactionRollbackCausedByTransactionObserver() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
        dbQueue.inDatabase { db in
            do {
                try Artist(name: "Gerhard Richter").save(db)
                XCTFail("Expected Error")
            } catch let error as NSError {
                XCTAssertEqual(error.domain, "foo")
                XCTAssertEqual(error.code, 0)
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 1)
                #endif
                XCTAssertEqual(observer.didChangeCount, 1)
                XCTAssertEqual(observer.willCommitCount, 1)
                XCTAssertEqual(observer.didCommitCount, 0)
                XCTAssertEqual(observer.didRollbackCount, 1)
            }
        }
    }

    func testExplicitTransactionRollbackCausedByTransactionObserver() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
        dbQueue.add(transactionObserver: observer)
        
        do {
            try dbQueue.inTransaction { db in
                do {
                    try Artist(name: "Gerhard Richter").save(db)
                } catch {
                    XCTFail("Unexpected Error")
                }
                return .commit
            }
            XCTFail("Expected Error")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "foo")
            XCTAssertEqual(error.code, 0)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 1)
        }
    }

    func testImplicitTransactionRollbackCausedByDatabaseErrorSuperseedTransactionObserver() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
        dbQueue.add(transactionObserver: observer)
        
        do {
            try dbQueue.inDatabase { db in
                do {
                    try Artwork(title: "meh").save(db)
                    XCTFail("Expected Error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                        XCTAssertEqual(observer.willChangeCount, 0)
                    #endif
                    XCTAssertEqual(observer.didChangeCount, 0)
                    XCTAssertEqual(observer.willCommitCount, 0)
                    XCTAssertEqual(observer.didCommitCount, 0)
                    XCTAssertEqual(observer.didRollbackCount, 0)
                    throw error
                }
            }
            XCTFail("Expected Error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
            #endif
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
        }
    }

    func testExplicitTransactionRollbackCausedByDatabaseErrorSuperseedTransactionObserver() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
        dbQueue.add(transactionObserver: observer)
        
        do {
            try dbQueue.inTransaction { db in
                do {
                    try Artwork(title: "meh").save(db)
                    XCTFail("Expected Error")
                } catch let error as DatabaseError {
                    // Immediate constraint check has failed.
                    XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                        XCTAssertEqual(observer.willChangeCount, 0)
                    #endif
                    XCTAssertEqual(observer.didChangeCount, 0)
                    XCTAssertEqual(observer.willCommitCount, 0)
                    XCTAssertEqual(observer.didCommitCount, 0)
                    XCTAssertEqual(observer.didRollbackCount, 0)
                    throw error
                }
                return .commit
            }
            XCTFail("Expected Error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
            #endif
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 1)
        }
    }

    func testMinimalRowIDUpdateObservation() throws {
        // Here we test that updating a Record made of a single primary key
        // column performs an actual UPDATE statement, even though it is
        // totally useless (UPDATE id = 1 FROM records WHERE id = 1).
        //
        // It is important to update something, so that TransactionObserver
        // can observe a change.
        //
        // The goal is to be able to write tests with minimal tables,
        // including tables made of a single primary key column. The less we
        // have exceptions, the better it is.
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.inDatabase { db in
            try MinimalRowID.setup(inDatabase: db)
            
            let record = MinimalRowID()
            try record.save(db)
            
            observer.resetCounts()
            try record.update(db)
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
        }
    }


    // MARK: - Multiple observers

    func testInsertEventIsNotifiedToAllObservers() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer1 = Observer()
        let observer2 = Observer()
        dbQueue.add(transactionObserver: observer1)
        dbQueue.add(transactionObserver: observer2)
        
        try dbQueue.inDatabase { db in
            let artist = Artist(name: "Gerhard Richter")
            
            //
            try artist.save(db)
            
            do {
                XCTAssertEqual(observer1.lastCommittedEvents.count, 1)
                let event = observer1.lastCommittedEvents.filter { event in
                    self.match(event: event, kind: .insert, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer1.lastCommittedPreUpdateEvents.count, 1)
                    let preUpdateEvent = observer1.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
                                   finalValues: [
                                    artist.id!.databaseValue,
                                    artist.name!.databaseValue
                            ])
                        }.first
                    XCTAssertTrue(preUpdateEvent != nil)
                #endif
            }
            do {
                XCTAssertEqual(observer2.lastCommittedEvents.count, 1)
                let event = observer2.lastCommittedEvents.filter { event in
                    self.match(event: event, kind: .insert, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer2.lastCommittedPreUpdateEvents.count, 1)
                    let preUpdateEvent = observer2.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
                                   finalValues: [
                                    artist.id!.databaseValue,
                                    artist.name!.databaseValue
                            ])
                        }.first
                    XCTAssertTrue(preUpdateEvent != nil)
                #endif
            }
        }
    }

    func testExplicitTransactionRollbackCausedBySecondTransactionObserverOutOfThree() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer1 = Observer()
        let observer2 = Observer()
        let observer3 = Observer()
        observer2.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
        
        dbQueue.add(transactionObserver: observer1)
        dbQueue.add(transactionObserver: observer2)
        dbQueue.add(transactionObserver: observer3)
        
        do {
            try dbQueue.inTransaction { db in
                do {
                    try Artist(name: "Gerhard Richter").save(db)
                } catch {
                    XCTFail("Unexpected Error")
                }
                return .commit
            }
            XCTFail("Expected Error")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "foo")
            XCTAssertEqual(error.code, 0)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer1.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer1.didChangeCount, 1)
            XCTAssertEqual(observer1.willCommitCount, 1)
            XCTAssertEqual(observer1.didCommitCount, 0)
            XCTAssertEqual(observer1.didRollbackCount, 1)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer2.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer2.didChangeCount, 1)
            XCTAssertEqual(observer2.willCommitCount, 1)
            XCTAssertEqual(observer2.didCommitCount, 0)
            XCTAssertEqual(observer2.didRollbackCount, 1)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer3.willChangeCount, 1)
            #endif
            XCTAssertEqual(observer3.didChangeCount, 1)
            XCTAssertEqual(observer3.willCommitCount, 0)
            XCTAssertEqual(observer3.didCommitCount, 0)
            XCTAssertEqual(observer3.didRollbackCount, 1)
        }
    }

    func testTransactionObserverAddAndRemove() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer)
        
        try dbQueue.inDatabase { db in
            let artist = Artist(name: "Gerhard Richter")
            
            //
            try artist.save(db)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
            let event = observer.lastCommittedEvents.filter { event in
                self.match(event: event, kind: .insert, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
                               finalValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                        ])
                    }.first
                XCTAssertTrue(preUpdateEvent != nil)
            #endif
        }
        
        observer.resetCounts()
        dbQueue.remove(transactionObserver: observer)
        
        try dbQueue.inTransaction { db in
            do {
                try Artist(name: "Vincent Fournier").save(db)
            } catch {
                XCTFail("Unexpected Error")
            }
            return .commit
        }
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            XCTAssertEqual(observer.willChangeCount, 0)
        #endif
        XCTAssertEqual(observer.didChangeCount, 0)
        XCTAssertEqual(observer.willCommitCount, 0)
        XCTAssertEqual(observer.didCommitCount, 0)
        XCTAssertEqual(observer.didRollbackCount, 0)
    }

    
    // MARK: - Filtered database events

    func testFilterDatabaseEvents() throws {
        let dbQueue = try makeDatabaseQueue()
        
        do {
            let observer = Observer(observes: { _ in false })
            dbQueue.add(transactionObserver: observer)
            
            try dbQueue.inTransaction { db in
                let artist = Artist(name: "Gerhard Richter")
                try artist.insert(db)
                try artist.update(db)
                try artist.delete(db)
                return .commit
            }
            
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            XCTAssertEqual(observer.lastCommittedEvents.count, 0)
        }
        
        do {
            let observer = Observer(observes: { _ in true })
            dbQueue.add(transactionObserver: observer)
            
            try dbQueue.inTransaction { db in
                let artist = Artist(name: "Gerhard Richter")
                try artist.insert(db)
                try artist.update(db)
                try artist.delete(db)
                return .commit
            }
            
            XCTAssertEqual(observer.didChangeCount, 3)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            XCTAssertEqual(observer.lastCommittedEvents.count, 3)
        }
        
        do {
            let observer = Observer(observes: { eventKind in
                switch eventKind {
                case .insert:
                    return true
                case .update:
                    return false
                case .delete:
                    return false
                }
            })
            dbQueue.add(transactionObserver: observer)
            
            try dbQueue.inTransaction { db in
                let artist = Artist(name: "Gerhard Richter")
                try artist.insert(db)
                try artist.update(db)
                try artist.delete(db)
                return .commit
            }
            
            XCTAssertEqual(observer.didChangeCount, 1)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            XCTAssertEqual(observer.lastCommittedEvents.count, 1)
        }
        
        do {
            let observer = Observer(observes: { eventKind in
                switch eventKind {
                case .insert:
                    return true
                case .update:
                    return true
                case .delete:
                    return false
                }
            })
            dbQueue.add(transactionObserver: observer)
            
            try dbQueue.inTransaction { db in
                let artist = Artist(name: "Gerhard Richter")
                try artist.insert(db)
                try artist.update(db)
                try artist.delete(db)
                return .commit
            }
            
            XCTAssertEqual(observer.didChangeCount, 2)
            XCTAssertEqual(observer.willCommitCount, 1)
            XCTAssertEqual(observer.didCommitCount, 1)
            XCTAssertEqual(observer.didRollbackCount, 0)
            XCTAssertEqual(observer.lastCommittedEvents.count, 2)
        }
    }

    
    // MARK: - Observation Extent
    
    func testDefaultObservationExtent() throws {
        weak var weakObserver: Observer? = nil
        let dbQueue = try makeDatabaseQueue()
        do {
            let observer = Observer()
            weakObserver = observer
            dbQueue.add(transactionObserver: observer)
            
            try dbQueue.inTransaction { _ in .commit }
            XCTAssertEqual(observer.didCommitCount, 1)
            try dbQueue.inTransaction { _ in .commit }
            XCTAssertEqual(observer.didCommitCount, 2)
        }
        XCTAssert(weakObserver == nil)
    }
    
    func testObservationExtentObserverLifetime() throws {
        weak var weakObserver: Observer? = nil
        let dbQueue = try makeDatabaseQueue()
        do {
            let observer = Observer()
            weakObserver = observer
            dbQueue.add(transactionObserver: observer, extent: .observerLifetime)
            
            try dbQueue.inTransaction { _ in .commit }
            XCTAssertEqual(observer.didCommitCount, 1)
            try dbQueue.inTransaction { _ in .commit }
            XCTAssertEqual(observer.didCommitCount, 2)
        }
        XCTAssert(weakObserver == nil)
    }
    
    func testObservationExtentUntilNextTransaction() throws {
        weak var weakObserver: Observer? = nil
        let dbQueue = try makeDatabaseQueue()
        do {
            let observer = Observer()
            weakObserver = observer
            dbQueue.add(transactionObserver: observer, extent: .nextTransaction)
        }
        if let observer = weakObserver {
            try dbQueue.inTransaction { _ in .commit }
            XCTAssertEqual(observer.didCommitCount, 1)
        } else {
            XCTFail("observer should not be deallocated until next transaction")
        }
        XCTAssert(weakObserver == nil)
    }
    
    func testObservationExtentUntilNextTransactionWithRollback() throws {
        weak var weakObserver: Observer? = nil
        let dbQueue = try makeDatabaseQueue()
        do {
            let observer = Observer()
            weakObserver = observer
            dbQueue.add(transactionObserver: observer, extent: .nextTransaction)
        }
        if let observer = weakObserver {
            try dbQueue.inTransaction { _ in .rollback }
            XCTAssertEqual(observer.didRollbackCount, 1)
        } else {
            XCTFail("observer should not be deallocated until next transaction")
        }
        XCTAssert(weakObserver == nil)
    }
    
    func testObservationExtentUntilNextTransactionWithRetainedObserver() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        dbQueue.add(transactionObserver: observer, extent: .nextTransaction)
        
        try dbQueue.inTransaction { _ in .commit }
        XCTAssertEqual(observer.didCommitCount, 1)
        try dbQueue.inTransaction { _ in .commit }
        XCTAssertEqual(observer.didCommitCount, 1)
    }
    
    func testObservationExtentUntilNextTransactionWithTriggeredTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        let witness = Observer()
        let observer = Observer(didCommitBlock: { db in
            try! db.inTransaction { .commit }
        })
        dbQueue.add(transactionObserver: witness)
        dbQueue.add(transactionObserver: observer, extent: .nextTransaction)
        
        try dbQueue.inTransaction { _ in .commit }
        XCTAssertEqual(observer.didCommitCount, 1)
        XCTAssertEqual(witness.didCommitCount, 2)
        try dbQueue.inTransaction { _ in .commit }
        XCTAssertEqual(observer.didCommitCount, 1)
        XCTAssertEqual(witness.didCommitCount, 3)
    }
    
    func testObservationExtentUntilNextTransactionAddedDuringTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        let observer = Observer()
        
        try dbQueue.inTransaction { db in
            db.add(transactionObserver: observer, extent: .nextTransaction)
            return .commit
        }
        
        XCTAssertEqual(observer.didCommitCount, 1)
        try dbQueue.inTransaction { _ in .commit }
        XCTAssertEqual(observer.didCommitCount, 1)
    }
    
    func testObservationExtentDatabaseLifetime() throws {
        // Observer deallocation happens concurrently with database deallocation:
        //
        // 1. DatabaseQueue.deinit (main queue)
        // 2. SerializedDatabase.deinit (main queue)
        // 3. DispatchQueue.deinit (main queue)
        // 4. SchedulingWatchDog.deinit (database queue)
        // 5. Database.deinit (database queue)
        // 6. Observer.deinit (database queue)
        let deinitSemaphore = DispatchSemaphore(value: 0)
        
        do {
            let dbQueue = try makeDatabaseQueue()
            weak var weakObserver: Observer? = nil
            do {
                let observer = Observer(deinitBlock: {
                    deinitSemaphore.signal()
                })
                weakObserver = observer
                dbQueue.add(transactionObserver: observer, extent: .databaseLifetime)
            }
            
            if let observer = weakObserver {
                try dbQueue.inTransaction { _ in .commit }
                XCTAssertEqual(observer.didCommitCount, 1)
            } else {
                XCTFail("observer should not be deallocated until database is closed")
            }
            
            if let observer = weakObserver {
                try dbQueue.inTransaction { _ in .commit }
                XCTAssertEqual(observer.didCommitCount, 2)
            } else {
                XCTFail("observer should not be deallocated until database is closed")
            }
        } // <- DatabaseQueue.deinit ... Observer.deinit
        
        // Wait for observer deallocation
        switch deinitSemaphore.wait(timeout: .now() + .seconds(60)) {
        case .success:
            break
        case .timedOut:
            XCTFail("Observer not deallocated")
        }
    }
}
