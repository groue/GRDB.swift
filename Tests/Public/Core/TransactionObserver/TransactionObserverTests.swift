import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class TransactionObserver : TransactionObserverType {
    var lastCommittedEvents: [DatabaseEvent] = []
    var events: [DatabaseEvent] = []
    var commitError: ErrorType?
    var deinitBlock: (() -> ())?
    
    init(deinitBlock: (() -> ())? = nil) {
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
    func databaseWillChangeWithEvent(event: DatabasePreUpdateEvent) {
        willChangeCount += 1
        preUpdateEvents.append(event.copy())
    }
    #endif
    
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        didChangeCount += 1
        events.append(event.copy())
    }
    
    func databaseWillCommit() throws {
        willCommitCount += 1
        if let commitError = commitError {
            throw commitError
        }
    }
    
    func databaseDidCommit(db: Database) {
        didCommitCount += 1
        lastCommittedEvents = events
        events = []
        #if SQLITE_ENABLE_PREUPDATE_HOOK
            lastCommittedPreUpdateEvents = preUpdateEvents
            preUpdateEvents = []
        #endif
    }
    
    func databaseDidRollback(db: Database) {
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
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE artists (" +
                "id INTEGER PRIMARY KEY, " +
                "name TEXT" +
            ")")
    }
    
    // Record
    
    static override func databaseTableName() -> String {
        return "artists"
    }
    
    required init(_ row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        super.init(row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name]
    }
    
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
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
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE artworks (" +
                "id INTEGER PRIMARY KEY, " +
                "artistId INTEGER NOT NULL REFERENCES artists(id) ON DELETE CASCADE ON UPDATE CASCADE, " +
                "title TEXT" +
            ")")
    }
    
    // Record
    
    static override func databaseTableName() -> String {
        return "artworks"
    }
    
    required init(_ row: Row) {
        id = row.value(named: "id")
        title = row.value(named: "title")
        artistId = row.value(named: "artistId")
        super.init(row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "artistId": artistId, "title": title]
    }
    
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        self.id = rowID
    }
}

class TransactionObserverTests: GRDBTestCase {
    override func setUpDatabase(dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try Artist.setupInDatabase(db)
            try Artwork.setupInDatabase(db)
        }
    }
    
    private func match(event event: DatabaseEvent, kind: DatabaseEvent.Kind, tableName: String, rowId: Int64) -> Bool {
        return (event.tableName == tableName) && (event.rowID == rowId) && (event.kind == kind)
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    
    private func match(preUpdateEvent event: DatabasePreUpdateEvent, kind: DatabasePreUpdateEvent.Kind, tableName: String, initialRowID: Int64?, finalRowID: Int64?, initialValues: [DatabaseValue]?, finalValues: [DatabaseValue]?, depth: CInt = 0) -> Bool {
    
        func checkDatabaseValues(values: [DatabaseValue]?, expected: [DatabaseValue]?) -> Bool {
            if let values = values {
                guard let expected = expected else { return false }
                return values == expected
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
        guard checkDatabaseValues(event.initialDatabaseValues, expected: initialValues) else { return false }
        guard checkDatabaseValues(event.finalDatabaseValues, expected: finalValues) else { return false }
        
        return true
    }
    
    #endif
    
    // MARK: - Events
    
    func testInsertEvent() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            try dbQueue.inDatabase { db in
                let artist = Artist(name: "Gerhard Richter")
                
                //
                try artist.save(db)
                XCTAssertEqual(observer.lastCommittedEvents.count, 1)
                let event = observer.lastCommittedEvents.filter { event in
                    self.match(event: event, kind: .Insert, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                    let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .Insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
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
    
    func testUpdateEvent() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            try dbQueue.inDatabase { db in
                let artist = Artist(name: "Gerhard Richter")
                try artist.save(db)
                artist.name = "Vincent Fournier"
                
                //
                try artist.save(db)
                XCTAssertEqual(observer.lastCommittedEvents.count, 1)
                let event = observer.lastCommittedEvents.filter {
                    self.match(event: $0, kind: .Update, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                    let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .Update, tableName: "artists", initialRowID: artist.id!, finalRowID: artist.id!,
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
    }
    
    func testDeleteEvent() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            try dbQueue.inDatabase { db in
                let artist = Artist(name: "Gerhard Richter")
                try artist.save(db)
                
                //
                try artist.delete(db)
                XCTAssertEqual(observer.lastCommittedEvents.count, 1)
                let event = observer.lastCommittedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                    let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .Delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                            initialValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                            ], finalValues: nil)
                        }.first
                    XCTAssertTrue(preUpdateEvent != nil)
                #endif
            }
        }
    }
    
    func testCascadingDeleteEvents() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
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
                    self.match(event: $0, kind: .Delete, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(artistEvent != nil)
                let artwork1Event = observer.lastCommittedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artworks", rowId: artwork1.id!)
                    }.first
                XCTAssertTrue(artwork1Event != nil)
                let artwork2Event = observer.lastCommittedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artworks", rowId: artwork2.id!)
                    }.first
                XCTAssertTrue(artwork2Event != nil)
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 3)
                    let artistPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .Delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                            initialValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                            ], finalValues: nil)
                        }.first
                    XCTAssertTrue(artistPreUpdateEvent != nil)
                    let artwork1PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .Delete, tableName: "artworks", initialRowID: artwork1.id!, finalRowID: nil,
                            initialValues: [
                                artwork1.id!.databaseValue,
                                artwork1.artistId!.databaseValue,
                                artwork1.title!.databaseValue
                            ], finalValues: nil, depth: 1)
                        }.first
                    XCTAssertTrue(artwork1PreUpdateEvent != nil)
                    let artwork2PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .Delete, tableName: "artworks", initialRowID: artwork2.id!, finalRowID: nil,
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
    }
    
    
    // MARK: - Commits & Rollback
    
    func testImplicitTransactionCommit() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
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
    }
    
    func testCascadeWithImplicitTransactionCommit() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
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
                    self.match(event: $0, kind: .Delete, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(artistDeleteEvent != nil)
                
                let artwork1DeleteEvent = observer.lastCommittedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artworks", rowId: artwork1.id!)
                    }.first
                XCTAssertTrue(artwork1DeleteEvent != nil)
                
                let artwork2DeleteEvent = observer.lastCommittedEvents.filter {
                    self.match(event: $0, kind: .Delete, tableName: "artworks", rowId: artwork2.id!)
                    }.first
                XCTAssertTrue(artwork2DeleteEvent != nil)
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 3)
                    let artistPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .Delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                            initialValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                            ], finalValues: nil)
                        }.first
                    XCTAssertTrue(artistPreUpdateEvent != nil)
                    let artwork1PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .Delete, tableName: "artworks", initialRowID: artwork1.id!, finalRowID: nil,
                            initialValues: [
                                artwork1.id!.databaseValue,
                                artwork1.artistId!.databaseValue,
                                artwork1.title!.databaseValue
                            ], finalValues: nil, depth: 1)
                        }.first
                    XCTAssertTrue(artwork1PreUpdateEvent != nil)
                    let artwork2PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .Delete, tableName: "artworks", initialRowID: artwork2.id!, finalRowID: nil,
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
    }
    
    func testExplicitTransactionCommit() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
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
                return .Commit
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
                self.match(event: $0, kind: .Insert, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(artistEvent != nil)
            
            let artwork1Event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .Insert, tableName: "artworks", rowId: artwork1.id!)
                }.first
            XCTAssertTrue(artwork1Event != nil)
            
            let artwork2Event = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .Insert, tableName: "artworks", rowId: artwork2.id!)
                }.first
            XCTAssertTrue(artwork2Event != nil)
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 3)
                let artistPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .Insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!,
                        initialValues: nil, finalValues: [
                            artist.id!.databaseValue,
                            artist.name!.databaseValue
                        ])
                    }.first
                XCTAssertTrue(artistPreUpdateEvent != nil)
                let artwork1PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .Insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork1.id!,
                        initialValues: nil, finalValues: [
                            artwork1.id!.databaseValue,
                            artwork1.artistId!.databaseValue,
                            artwork1.title!.databaseValue
                        ])
                    }.first
                XCTAssertTrue(artwork1PreUpdateEvent != nil)
                let artwork2PreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .Insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork2.id!,
                        initialValues: nil, finalValues: [
                            artwork2.id!.databaseValue,
                            artwork2.artistId!.databaseValue,
                            artwork2.title!.databaseValue
                        ])
                    }.first
                XCTAssertTrue(artwork2PreUpdateEvent != nil)
            #endif
        }
    }
    
    func testCascadeWithExplicitTransactionCommit() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
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
                return .Commit
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
                self.match(event: $0, kind: .Insert, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(artistInsertEvent != nil)
            
            let artwork1InsertEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .Insert, tableName: "artworks", rowId: artwork1.id!)
                }.first
            XCTAssertTrue(artwork1InsertEvent != nil)
            
            let artwork2InsertEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .Insert, tableName: "artworks", rowId: artwork2.id!)
                }.first
            XCTAssertTrue(artwork2InsertEvent != nil)
            
            let artistDeleteEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .Delete, tableName: "artists", rowId: artist.id!)
                }.first
            XCTAssertTrue(artistDeleteEvent != nil)
            
            let artwork1DeleteEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .Delete, tableName: "artworks", rowId: artwork1.id!)
                }.first
            XCTAssertTrue(artwork1DeleteEvent != nil)
            
            let artwork2DeleteEvent = observer.lastCommittedEvents.filter {
                self.match(event: $0, kind: .Delete, tableName: "artworks", rowId: artwork2.id!)
                }.first
            XCTAssertTrue(artwork2DeleteEvent != nil)
            
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 6)  // 3 inserts, and 3 deletes
                let artistInsertPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .Insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!,
                        initialValues: nil, finalValues: [
                            artist.id!.databaseValue,
                            artist.name!.databaseValue
                        ])
                    }.first
                XCTAssertTrue(artistInsertPreUpdateEvent != nil)
                let artwork1InsertPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .Insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork1.id!,
                        initialValues: nil, finalValues: [
                            artwork1.id!.databaseValue,
                            artwork1.artistId!.databaseValue,
                            artwork1.title!.databaseValue
                        ])
                    }.first
                XCTAssertTrue(artwork1InsertPreUpdateEvent != nil)
                let artwork2InsertPreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .Insert, tableName: "artworks", initialRowID: nil, finalRowID: artwork2.id!,
                        initialValues: nil, finalValues: [
                            artwork2.id!.databaseValue,
                            artwork2.artistId!.databaseValue,
                            artwork2.title!.databaseValue
                        ])
                    }.first
                XCTAssertTrue(artwork2InsertPreUpdateEvent != nil)

                let artistDeletePreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .Delete, tableName: "artists", initialRowID: artist.id!, finalRowID: nil,
                        initialValues: [
                            artist.id!.databaseValue,
                            artist.name!.databaseValue
                        ], finalValues: nil)
                    }.first
                XCTAssertTrue(artistDeletePreUpdateEvent != nil)
                let artwork1DeletePreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .Delete, tableName: "artworks", initialRowID: artwork1.id!, finalRowID: nil,
                        initialValues: [
                            artwork1.id!.databaseValue,
                            artwork1.artistId!.databaseValue,
                            artwork1.title!.databaseValue
                        ], finalValues: nil, depth: 1)
                    }.first
                XCTAssertTrue(artwork1DeletePreUpdateEvent != nil)
                let artwork2DeletePreUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                    self.match(preUpdateEvent: event, kind: .Delete, tableName: "artworks", initialRowID: artwork2.id!, finalRowID: nil,
                        initialValues: [
                            artwork2.id!.databaseValue,
                            artwork2.artistId!.databaseValue,
                            artwork2.title!.databaseValue
                        ], finalValues: nil, depth: 1)
                    }.first
                XCTAssertTrue(artwork2DeletePreUpdateEvent != nil)
            #endif
        }
    }
    
    func testExplicitTransactionRollback() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
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
                return .Rollback
            }
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
            #endif
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 1)
        }
    }
    
    func testImplicitTransactionRollbackCausedByDatabaseError() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            do {
                try dbQueue.inDatabase { db in
                    do {
                        try Artwork(title: "meh").save(db)
                        XCTFail("Expected Error")
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 19)
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
                XCTAssertEqual(error.code, 19)
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 0)
                #endif
                XCTAssertEqual(observer.didChangeCount, 0)
                XCTAssertEqual(observer.willCommitCount, 0)
                XCTAssertEqual(observer.didCommitCount, 0)
                XCTAssertEqual(observer.didRollbackCount, 0)
            }
        }
    }

    func testExplicitTransactionRollbackCausedByDatabaseError() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            do {
                try dbQueue.inTransaction { db in
                    do {
                        try Artwork(title: "meh").save(db)
                        XCTFail("Expected Error")
                    } catch let error as DatabaseError {
                        // Immediate constraint check has failed.
                        XCTAssertEqual(error.code, 19)
                        #if SQLITE_ENABLE_PREUPDATE_HOOK
                            XCTAssertEqual(observer.willChangeCount, 0)
                        #endif
                        XCTAssertEqual(observer.didChangeCount, 0)
                        XCTAssertEqual(observer.willCommitCount, 0)
                        XCTAssertEqual(observer.didCommitCount, 0)
                        XCTAssertEqual(observer.didRollbackCount, 0)
                        throw error
                    }
                    return .Commit
                }
                XCTFail("Expected Error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.code, 19)
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 0)
                #endif
                XCTAssertEqual(observer.didChangeCount, 0)
                XCTAssertEqual(observer.willCommitCount, 0)
                XCTAssertEqual(observer.didCommitCount, 0)
                XCTAssertEqual(observer.didRollbackCount, 1)
            }
        }
    }
    
    func testImplicitTransactionRollbackCausedByTransactionObserver() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
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
    }
    
    func testExplicitTransactionRollbackCausedByTransactionObserver() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
            dbQueue.addTransactionObserver(observer)
            
            do {
                try dbQueue.inTransaction { db in
                    do {
                        try Artist(name: "Gerhard Richter").save(db)
                    } catch {
                        XCTFail("Unexpected Error")
                    }
                    return .Commit
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
    }
    
    func testImplicitTransactionRollbackCausedByDatabaseErrorSuperseedTransactionObserver() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
            dbQueue.addTransactionObserver(observer)
            
            do {
                try dbQueue.inDatabase { db in
                    do {
                        try Artwork(title: "meh").save(db)
                        XCTFail("Expected Error")
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 19)
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
                XCTAssertEqual(error.code, 19)
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 0)
                #endif
                XCTAssertEqual(observer.didChangeCount, 0)
                XCTAssertEqual(observer.willCommitCount, 0)
                XCTAssertEqual(observer.didCommitCount, 0)
                XCTAssertEqual(observer.didRollbackCount, 0)
            }
        }
    }
    
    func testExplicitTransactionRollbackCausedByDatabaseErrorSuperseedTransactionObserver() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            observer.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
            dbQueue.addTransactionObserver(observer)
            
            do {
                try dbQueue.inTransaction { db in
                    do {
                        try Artwork(title: "meh").save(db)
                        XCTFail("Expected Error")
                    } catch let error as DatabaseError {
                        // Immediate constraint check has failed.
                        XCTAssertEqual(error.code, 19)
                        #if SQLITE_ENABLE_PREUPDATE_HOOK
                            XCTAssertEqual(observer.willChangeCount, 0)
                        #endif
                        XCTAssertEqual(observer.didChangeCount, 0)
                        XCTAssertEqual(observer.willCommitCount, 0)
                        XCTAssertEqual(observer.didCommitCount, 0)
                        XCTAssertEqual(observer.didRollbackCount, 0)
                        throw error
                    }
                    return .Commit
                }
                XCTFail("Expected Error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.code, 19)
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.willChangeCount, 0)
                #endif
                XCTAssertEqual(observer.didChangeCount, 0)
                XCTAssertEqual(observer.willCommitCount, 0)
                XCTAssertEqual(observer.didCommitCount, 0)
                XCTAssertEqual(observer.didRollbackCount, 1)
            }
        }
    }
    
    func testMinimalRowIDUpdateObservation() {
        // Here we test that updating a Record made of a single primary key
        // column performs an actual UPDATE statement, even though it is
        // totally useless (UPDATE id = 1 FROM records WHERE id = 1).
        //
        // It is important to update something, so that TransactionObserverType
        // can observe a change.
        //
        // The goal is to be able to write tests with minimal tables,
        // including tables made of a single primary key column. The less we
        // have exceptions, the better it is.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            try dbQueue.inDatabase { db in
                try MinimalRowID.setupInDatabase(db)
                
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
    }
    
    
    // MARK: - Multiple observers
    
    func testInsertEventIsNotifiedToAllObservers() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer1 = TransactionObserver()
            let observer2 = TransactionObserver()
            dbQueue.addTransactionObserver(observer1)
            dbQueue.addTransactionObserver(observer2)
            
            try dbQueue.inDatabase { db in
                let artist = Artist(name: "Gerhard Richter")
                
                //
                try artist.save(db)
                
                do {
                    XCTAssertEqual(observer1.lastCommittedEvents.count, 1)
                    let event = observer1.lastCommittedEvents.filter { event in
                        self.match(event: event, kind: .Insert, tableName: "artists", rowId: artist.id!)
                        }.first
                    XCTAssertTrue(event != nil)
                    
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                        XCTAssertEqual(observer1.lastCommittedPreUpdateEvents.count, 1)
                        let preUpdateEvent = observer1.lastCommittedPreUpdateEvents.filter { event in
                            self.match(preUpdateEvent: event, kind: .Insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
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
                        self.match(event: event, kind: .Insert, tableName: "artists", rowId: artist.id!)
                        }.first
                    XCTAssertTrue(event != nil)
                    
                    #if SQLITE_ENABLE_PREUPDATE_HOOK
                        XCTAssertEqual(observer2.lastCommittedPreUpdateEvents.count, 1)
                        let preUpdateEvent = observer2.lastCommittedPreUpdateEvents.filter { event in
                            self.match(preUpdateEvent: event, kind: .Insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
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
    }
    
    func testExplicitTransactionRollbackCausedBySecondTransactionObserverOutOfThree() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer1 = TransactionObserver()
            let observer2 = TransactionObserver()
            let observer3 = TransactionObserver()
            observer2.commitError = NSError(domain: "foo", code: 0, userInfo: nil)
            
            dbQueue.addTransactionObserver(observer1)
            dbQueue.addTransactionObserver(observer2)
            dbQueue.addTransactionObserver(observer3)
            
            do {
                try dbQueue.inTransaction { db in
                    do {
                        try Artist(name: "Gerhard Richter").save(db)
                    } catch {
                        XCTFail("Unexpected Error")
                    }
                    return .Commit
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
    }
    
    func testTransactionObserverIsNotRetained() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            var observerReleased = false
            do {
                let observer = TransactionObserver(deinitBlock: { observerReleased = true })
                withExtendedLifetime(observer) {
                    dbQueue.addTransactionObserver(observer)
                    XCTAssertFalse(observerReleased)
                }
            }
            XCTAssertTrue(observerReleased)
            try dbQueue.inDatabase { db in
                try Artist(name: "Gerhard Richter").save(db)
            }
        }
    }
    
    func testTransactionObserverAddAndRemove() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let observer = TransactionObserver()
            dbQueue.addTransactionObserver(observer)
            
            try dbQueue.inDatabase { db in
                let artist = Artist(name: "Gerhard Richter")
                
                //
                try artist.save(db)
                XCTAssertEqual(observer.lastCommittedEvents.count, 1)
                let event = observer.lastCommittedEvents.filter { event in
                    self.match(event: event, kind: .Insert, tableName: "artists", rowId: artist.id!)
                    }.first
                XCTAssertTrue(event != nil)
                
                #if SQLITE_ENABLE_PREUPDATE_HOOK
                    XCTAssertEqual(observer.lastCommittedPreUpdateEvents.count, 1)
                    let preUpdateEvent = observer.lastCommittedPreUpdateEvents.filter { event in
                        self.match(preUpdateEvent: event, kind: .Insert, tableName: "artists", initialRowID: nil, finalRowID: artist.id!, initialValues: nil,
                            finalValues: [
                                artist.id!.databaseValue,
                                artist.name!.databaseValue
                            ])
                        }.first
                    XCTAssertTrue(preUpdateEvent != nil)
                #endif
            }
            
            observer.resetCounts()
            dbQueue.removeTransactionObserver(observer)
            
            try dbQueue.inTransaction { db in
                do {
                    try Artist(name: "Vincent Fournier").save(db)
                } catch {
                    XCTFail("Unexpected Error")
                }
                return .Commit
            }
            
            #if SQLITE_ENABLE_PREUPDATE_HOOK
                XCTAssertEqual(observer.willChangeCount, 0)
            #endif
            XCTAssertEqual(observer.didChangeCount, 0)
            XCTAssertEqual(observer.willCommitCount, 0)
            XCTAssertEqual(observer.didCommitCount, 0)
            XCTAssertEqual(observer.didRollbackCount, 0)
        }
    }

}
