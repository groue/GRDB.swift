//import XCTest
//import GRDB
//
//// See if TransactionObserverType can provide robust NSData external storage.
////
//// The answer is yes, we can.
////
//// However this requires records to be *managed*. All instances of our
//// RecordWithManagedData must be given their manager after instanciation.
//
//class ManagedDataController : TransactionObserverType {
//    // Base directory
//    let path: String
//    
//    // A magic testing data: ManagedDataController.databaseWillCommit() throws
//    // an error if this data wants to save.
//    let forbiddenData: NSData?
//    
//    // ManagedData management
//    private var managedData: ManagedData? = nil
//    private var pendingManagedDatas: [Int64: ManagedData] = [:]
//    var movedManagedDatas: [ManagedData] = []
//    var storedManagedDatas: [ManagedData] = []
//    var restoreFileSystemAfterRollback: Bool = false
//    
//    init(path: String, forbiddenData: NSData?) {
//        self.path = path
//        self.forbiddenData = forbiddenData
//        setupDirectories()
//    }
//    
//    func willSaveManagedData(managedData: ManagedData?) {
//        // Next step: databaseDidChangeWithEvent() or databaseDidRollback()
//        self.managedData = managedData
//    }
//    
//    func databaseDidChangeWithEvent(event: DatabaseEvent) {
//        guard let managedData = managedData else {
//            return
//        }
//        
//        self.managedData = nil
//
//        switch event.kind {
//        case .Insert, .Update:
//            managedData.rowID = event.rowID
//            // Replace any existing managedData for this rowID.
//            pendingManagedDatas[event.rowID] = managedData
//        default:
//            break
//        }
//    }
//    
//    func databaseWillCommit() throws {
//        do {
//            let fm = NSFileManager.defaultManager()
//            for (_, managedData) in pendingManagedDatas.sort({ $0.0 < $1.0 }) {
//                if let forbiddenData = forbiddenData, let data = managedData.data where forbiddenData == data {
//                    throw NSError(domain: "ManagedDataController", code: 0, userInfo: nil)
//                }
//                
//                let storagePath = storageDataPath(managedData)
//                let storageDir = (storagePath as NSString).stringByDeletingLastPathComponent
//                let tempPath = temporaryDataPath(managedData)
//                let tempDir = (tempPath as NSString).stringByDeletingLastPathComponent
//                
//                
//                // Move
//                
//                if fm.fileExistsAtPath(storagePath) {
//                    if fm.fileExistsAtPath(tempPath) {
//                        try! fm.removeItemAtPath(tempPath)
//                    }
//                    if !fm.fileExistsAtPath(tempDir) {
//                        try fm.createDirectoryAtPath(tempDir, withIntermediateDirectories: true, attributes: nil)
//                    }
//                    try fm.moveItemAtPath(storagePath, toPath: tempPath)
//                }
//                movedManagedDatas.append(managedData)
//                
//                
//                // Store
//                
//                if let data = managedData.data {
//                    if !fm.fileExistsAtPath(storageDir) {
//                        try fm.createDirectoryAtPath(storageDir, withIntermediateDirectories: true, attributes: nil)
//                    }
//                    try data.writeToFile(storagePath, options: [])
//                }
//                storedManagedDatas.append(managedData)
//            }
//        } catch {
//            // Could not save the managed data.
//            //
//            // Let the database perform a rollback, and restore the
//            // file system later, in databaseDidRollback():
//            restoreFileSystemAfterRollback = true
//            throw error
//        }
//    }
//    
//    func databaseDidCommit(db: Database) {
//        // TODO: clean up tmp directory
//        cleanup()
//    }
//    
//    func databaseDidRollback(db: Database) {
//        if restoreFileSystemAfterRollback {
//            let fm = NSFileManager.defaultManager()
//            
//            for managedData in storedManagedDatas {
//                if fm.fileExistsAtPath(storageDataPath(managedData)) {
//                    try! fm.removeItemAtPath(storageDataPath(managedData))
//                }
//            }
//            
//            for managedData in movedManagedDatas {
//                let storagePath = storageDataPath(managedData)
//                let storageDir = (storagePath as NSString).stringByDeletingLastPathComponent
//                let tempPath = temporaryDataPath(managedData)
//                if fm.fileExistsAtPath(tempPath) {
//                    if !fm.fileExistsAtPath(storageDir) {
//                        try! fm.createDirectoryAtPath(storageDir, withIntermediateDirectories: true, attributes: nil)
//                    }
//                    try! fm.moveItemAtPath(tempPath, toPath: storagePath)
//                }
//            }
//        }
//        cleanup()
//    }
//    
//    func cleanup() {
//        managedData = nil
//        restoreFileSystemAfterRollback = false
//        movedManagedDatas = []
//        storedManagedDatas = []
//        pendingManagedDatas = [:]
//    }
//    
//    func loadData(managedData: ManagedData) -> NSData? {
//        guard managedData.rowID != nil else {
//            return nil
//        }
//        let fm = NSFileManager.defaultManager()
//        if fm.fileExistsAtPath(storageDataPath(managedData)) {
//            return NSData(contentsOfFile: storageDataPath(managedData))!
//        } else {
//            return nil
//        }
//    }
//    
//    private var temporaryDirectoryPath: String {
//        return (path as NSString).stringByAppendingPathComponent("tmp")
//    }
//    
//    private func storageDataPath(managedData: ManagedData) -> String {
//        var path = self.path as NSString
//        path = path.stringByAppendingPathComponent(String(managedData.rowID!))
//        path = path.stringByAppendingPathComponent(managedData.name)
//        return path as String
//    }
//    
//    private func temporaryDataPath(managedData: ManagedData) -> String {
//        var path = self.temporaryDirectoryPath as NSString
//        path = path.stringByAppendingPathComponent(String(managedData.rowID!))
//        path = path.stringByAppendingPathComponent(managedData.name)
//        return path as String
//    }
//    
//    private func setupDirectories() {
//        let fm = NSFileManager.defaultManager()
//        try! fm.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
//        try! fm.createDirectoryAtPath(temporaryDirectoryPath, withIntermediateDirectories: true, attributes: nil)
//    }
//}
//
//final class ManagedData {
//    var controller: ManagedDataController?
//    var name: String
//    var rowID: Int64?
//    var data: NSData? {
//        if let _data = _data {
//            return _data
//        } else {
//            _data = controller!.loadData(self)
//            return _data!
//        }
//    }
//    var _data: NSData??
//    
//    init(name: String) {
//        self.name = name
//    }
//    
//    func copyWithData(data: NSData?) -> ManagedData {
//        let copy = ManagedData(name: name)
//        copy.controller = controller
//        copy._data = data
//        copy.rowID = rowID
//        return copy
//    }
//    
//    func willSave() {
//        controller!.willSaveManagedData(self)
//    }
//}
//
//// OK
//class RecordWithManagedData : Record {
//    // OK
//    var id: Int64?
//    
//    // OK. Odd, but OK: data is accessed through managedData.
//    private var managedData = ManagedData(name: "data")
//    var data: NSData? {
//        get { return managedData.data }
//        set { managedData = managedData.copyWithData(newValue) }    // Odd
//    }
//    
//    // OK
//    override static func databaseTableName() -> String {
//        return "datas"
//    }
//    
//    // Not OK: what is this useless "data" columns?
//    // Answer: this is an artificial column that makes our tests run despite
//    // the fact that Record.update() does nothing when there is nothing to
//    // update.
//    override var persistentDictionary: [String: DatabaseValueConvertible?] {
//        return ["id": id, "data": nil]
//    }
//    
//    override func updateFromRow(row: Row) {
//        if let dbv = row.databaseValue(named: "id") {
//            id = dbv.value()
//            // Hmm. Sure this rowID must be linked to managedData at some point.
//            managedData.rowID = dbv.value()
//        }
//        super.updateFromRow(row)
//    }
//    
//    override func insert(db: Database) throws {
//        // Hmm.
//        managedData.willSave()
//        try super.insert(db)
//    }
//    
//    override func update(db: Database) throws {
//        // Hmm.
//        managedData.willSave()
//        try super.update(db)
//    }
//    
//    // OK
//    static func setupInDatabase(db: Database) throws {
//        // TODO: make tests run with a single "id INTEGER PRIMARY KEY" column.
//        // The "update" method is doing nothing in this case, so we can expect troubles with managed data.
//        try db.execute(
//            "CREATE TABLE datas (id INTEGER PRIMARY KEY, data BLOB)")
//    }
//}
//
//class ManagedDataControllerTests : GRDBTestCase {
//    var managedDataController: ManagedDataController!
//    
//    override var dbConfiguration: Configuration {
//        managedDataController = ManagedDataController(path: "/tmp/ManagedDataController", forbiddenData: "Bunny".dataUsingEncoding(NSUTF8StringEncoding))
//        var c = super.dbConfiguration
//        c.transactionObserver = managedDataController
//        return c
//    }
//    
//    override func setUp() {
//        super.setUp()
//        
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RecordWithManagedData.setupInDatabase(db)
//            }
//        }
//    }
//    
//    func testImplicitTransaction() {
//        assertNoError {
//            // Test that we can store data in the file system...
//            let record = RecordWithManagedData()
//            try dbQueue.inDatabase { db in
//                // TODO: this explicit line is a problem
//                record.managedData.controller = self.managedDataController
//                record.data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
//                try record.save(db)
//            }
//            
//            // ... and get it back after a fetch:
//            dbQueue.inDatabase { db in
//                let reloadedRecord = RecordWithManagedData.fetchOne(db, key: record.id)!
//                reloadedRecord.managedData.controller = self.managedDataController
//                XCTAssertEqual(reloadedRecord.data, "foo".dataUsingEncoding(NSUTF8StringEncoding))
//            }
//        }
//    }
//    
//    func testExplicitTransaction() {
//        assertNoError {
//            // Test that we can stored data in the file system...
//            let record = RecordWithManagedData()
//            record.managedData.controller = self.managedDataController
//            try dbQueue.inDatabase { db in
//                record.data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
//                try record.save(db)
//            }
//            
//            try dbQueue.inTransaction { db in
//                // ... and that changes...
//                record.data = "bar".dataUsingEncoding(NSUTF8StringEncoding)
//                try record.save(db)
//                
//                // ... after changes...
//                record.data = "baz".dataUsingEncoding(NSUTF8StringEncoding)
//                try record.save(db)
//                
//                // ... are not applied in the file system...
//                let reloadedRecord = RecordWithManagedData.fetchOne(db, key: record.id)!
//                reloadedRecord.managedData.controller = self.managedDataController
//                XCTAssertEqual(reloadedRecord.data, "foo".dataUsingEncoding(NSUTF8StringEncoding))
//                
//                // ... until database commit:
//                return .Commit
//            }
//            
//            // We find our modified data after commit:
//            dbQueue.inDatabase { db in
//                let reloadedRecord = RecordWithManagedData.fetchOne(db, key: record.id)!
//                reloadedRecord.managedData.controller = self.managedDataController
//                XCTAssertEqual(reloadedRecord.data, "baz".dataUsingEncoding(NSUTF8StringEncoding))
//            }
//        }
//    }
//    
//    func testCommitError() {
//        assertNoError {
//            // Test that we can stored data in the file system...
//            let record = RecordWithManagedData()
//            record.managedData.controller = self.managedDataController
//            try dbQueue.inDatabase { db in
//                record.data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
//                try record.save(db)
//            }
//            
//            do {
//                try dbQueue.inTransaction { db in
//                    // ... and that changes...
//                    record.data = "bar".dataUsingEncoding(NSUTF8StringEncoding)
//                    try record.save(db)
//                    
//                    // ... after changes...
//                    record.data = "baz".dataUsingEncoding(NSUTF8StringEncoding)
//                    try record.save(db)
//                    
//                    // ... are not applied in the file system...
//                    let reloadedRecord = RecordWithManagedData.fetchOne(db, key: record.id)!
//                    reloadedRecord.managedData.controller = self.managedDataController
//                    XCTAssertEqual(reloadedRecord.data, "foo".dataUsingEncoding(NSUTF8StringEncoding))
//
//                    // ... until database commit, which may fail:
//                    let forbiddenRecord = RecordWithManagedData()
//                    forbiddenRecord.managedData.controller = self.managedDataController
//                    forbiddenRecord.data = "Bunny".dataUsingEncoding(NSUTF8StringEncoding)
//                    try forbiddenRecord.save(db)
//                    return .Commit
//                }
//                XCTFail("Expected error")
//            } catch let error as NSError {
//                XCTAssertEqual(error.domain, "ManagedDataController")
//            }
//            
//            // We find our original data back after failure:
//            dbQueue.inDatabase { db in
//                let reloadedRecord = RecordWithManagedData.fetchOne(db, key: record.id)!
//                reloadedRecord.managedData.controller = self.managedDataController
//                XCTAssertEqual(reloadedRecord.data, "foo".dataUsingEncoding(NSUTF8StringEncoding))
//            }
//        }
//    }
//}
