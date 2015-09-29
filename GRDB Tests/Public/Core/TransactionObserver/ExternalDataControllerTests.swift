import XCTest
import GRDB

class ExternalDataController : TransactionObserverType {
    let path: String
    let forbiddenData: NSData?
    private var externalData: ExternalData? = nil
    private var pendingExternalDatas: [Int64: ExternalData] = [:]
    var movedExternalDatas: [ExternalData] = []
    var storedExternalDatas: [ExternalData] = []
    var restoreOnRollback: Bool = false
    
    init(path: String, forbiddenData: NSData?) {
        self.path = path
        self.forbiddenData = forbiddenData
        setupDirectories()
    }
    
    func willSaveExternalData(externalData: ExternalData?) {
        self.externalData = externalData
    }
    
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        guard let externalData = externalData else {
            return
        }
        self.externalData = nil
        
        switch event.kind {
        case .Insert, .Update:
            externalData.rowID = event.rowID
            pendingExternalDatas[event.rowID] = externalData
        default:
            break
        }
    }
    
    func databaseWillCommit() throws {
        do {
            let fm = NSFileManager.defaultManager()
            print(pendingExternalDatas)
            for (_, externalData) in pendingExternalDatas.sort({ $0.0 < $1.0 }) {
                if let forbiddenData = forbiddenData, let data = externalData.data where forbiddenData == data {
                    throw NSError(domain: "ExternalDataController", code: 0, userInfo: nil)
                }
                let storagePath = storageDataPath(externalData)
                let storageDir = (storagePath as NSString).stringByDeletingLastPathComponent
                let tempPath = temporaryDataPath(externalData)
                let tempDir = (tempPath as NSString).stringByDeletingLastPathComponent
                if fm.fileExistsAtPath(storagePath) {
                    if fm.fileExistsAtPath(tempPath) {
                        try! fm.removeItemAtPath(tempPath)
                    }
                    if !fm.fileExistsAtPath(tempDir) {
                        try fm.createDirectoryAtPath(tempDir, withIntermediateDirectories: true, attributes: nil)
                    }
                    try fm.moveItemAtPath(storagePath, toPath: tempPath)
                }
                movedExternalDatas.append(externalData)
                if let data = externalData.data {
                    if !fm.fileExistsAtPath(storageDir) {
                        try fm.createDirectoryAtPath(storageDir, withIntermediateDirectories: true, attributes: nil)
                    }
                    try data.writeToFile(storagePath, options: [])
                }
                storedExternalDatas.append(externalData)
            }
        } catch {
            restoreOnRollback = true
            throw error
        }
    }
    
    func databaseDidCommit(db: Database) {
        // TODO: clean up tmp directory
        cleanup()
    }
    
    func databaseDidRollback(db: Database) {
        if restoreOnRollback {
            let fm = NSFileManager.defaultManager()
            for externalData in storedExternalDatas {
                if fm.fileExistsAtPath(storageDataPath(externalData)) {
                    try! fm.removeItemAtPath(storageDataPath(externalData))
                }
            }
            for externalData in movedExternalDatas {
                let storagePath = storageDataPath(externalData)
                let storageDir = (storagePath as NSString).stringByDeletingLastPathComponent
                let tempPath = temporaryDataPath(externalData)
                if fm.fileExistsAtPath(tempPath) {
                    if !fm.fileExistsAtPath(storageDir) {
                        try! fm.createDirectoryAtPath(storageDir, withIntermediateDirectories: true, attributes: nil)
                    }
                    try! fm.moveItemAtPath(tempPath, toPath: storagePath)
                }
            }
        }
        cleanup()
    }
    
    func cleanup() {
        restoreOnRollback = false
        movedExternalDatas = []
        storedExternalDatas = []
        pendingExternalDatas = [:]
    }
    
    func loadData(externalData: ExternalData) -> NSData? {
        guard externalData.rowID != nil else {
            return nil
        }
        let fm = NSFileManager.defaultManager()
        if fm.fileExistsAtPath(storageDataPath(externalData)) {
            return NSData(contentsOfFile: storageDataPath(externalData))!
        } else {
            return nil
        }
    }
    
    private var temporaryDirectoryPath: String {
        return (path as NSString).stringByAppendingPathComponent("tmp")
    }
    
    private func storageDataPath(externalData: ExternalData) -> String {
        var path = self.path as NSString
        path = path.stringByAppendingPathComponent(String(externalData.rowID!))
        path = path.stringByAppendingPathComponent(externalData.name)
        return path as String
    }
    
    private func temporaryDataPath(externalData: ExternalData) -> String {
        var path = self.temporaryDirectoryPath as NSString
        path = path.stringByAppendingPathComponent(String(externalData.rowID!))
        path = path.stringByAppendingPathComponent(externalData.name)
        return path as String
    }
    
    private func setupDirectories() {
        let fm = NSFileManager.defaultManager()
        try! fm.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
        try! fm.createDirectoryAtPath(temporaryDirectoryPath, withIntermediateDirectories: true, attributes: nil)
    }
}

final class ExternalData {
    var controller: ExternalDataController?
    var name: String
    var rowID: Int64?
    var data: NSData? {
        if let _data = _data {
            return _data
        } else {
            _data = controller!.loadData(self)
            return _data!
        }
    }
    var _data: NSData??
    
    init(name: String) {
        self.name = name
    }
    
    func copyWithData(data: NSData?) -> ExternalData {
        let copy = ExternalData(name: name)
        copy.controller = controller
        copy._data = data
        copy.rowID = rowID
        return copy
    }
    
    func willSave() {
        controller!.willSaveExternalData(self)
    }
}

class RecordWithExternalData : Record {
    var id: Int64?
    
    private var externalData = ExternalData(name: "data")
    var data: NSData? {
        get { return externalData.data }
        set { externalData = externalData.copyWithData(newValue) }
    }
    
    override static func databaseTableName() -> String {
        return "datas"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "data": nil]
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["id"] {
            id = dbv.value()
            externalData.rowID = dbv.value()
        }
        super.updateFromRow(row)
    }
    
    override func insert(db: Database) throws {
        externalData.willSave()
        try super.insert(db)
    }
    
    override func update(db: Database) throws {
        externalData.willSave()
        try super.update(db)
    }
    
    //
    
    static func setupInDatabase(db: Database) throws {
        // TODO: make tests run with a single "id INTEGER PRIMARY KEY" column.
        // The "update" method doing nothing in this case, we expect troubles.
        try db.execute(
            "CREATE TABLE datas (id INTEGER PRIMARY KEY, data BLOB)")
    }
}

class ExternalDataControllerTests : GRDBTestCase {
    var externalDataController: ExternalDataController!
    
    override var dbConfiguration: Configuration {
        externalDataController = ExternalDataController(path: "/tmp/ExternalDataController", forbiddenData: "Bunny".dataUsingEncoding(NSUTF8StringEncoding))
        var c = super.dbConfiguration
        c.transactionObserver = externalDataController
        return c
    }
    
    override func setUp() {
        super.setUp()
        
        assertNoError {
            try dbQueue.inDatabase { db in
                try RecordWithExternalData.setupInDatabase(db)
            }
        }
    }
    
    func testBlah() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = RecordWithExternalData()
                // TODO: this explicit line is a problem
                record.externalData.controller = self.externalDataController
                record.data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
                try record.save(db)
            }
            
            dbQueue.inDatabase { db in
                let record = RecordWithExternalData.fetchOne(db, "SELECT * FROM datas")!
                // TODO: this explicit line is a problem
                record.externalData.controller = self.externalDataController
                XCTAssertEqual(record.data, "foo".dataUsingEncoding(NSUTF8StringEncoding))
            }
        }
    }
    
    func testError() {
        assertNoError {
            let record = RecordWithExternalData()
            record.externalData.controller = self.externalDataController
            try dbQueue.inDatabase { db in
                record.data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
                try record.save(db)
            }
            
            do {
                try dbQueue.inTransaction { db in
                    record.data = "bar".dataUsingEncoding(NSUTF8StringEncoding)
                    try record.save(db)

                    record.data = "baz".dataUsingEncoding(NSUTF8StringEncoding)
                    try record.save(db)
                    
                    let forbiddenRecord = RecordWithExternalData()
                    forbiddenRecord.externalData.controller = self.externalDataController
                    forbiddenRecord.data = "Bunny".dataUsingEncoding(NSUTF8StringEncoding)
                    try forbiddenRecord.save(db)
                    return .Commit
                }
                XCTFail("Expected error")
            } catch let error as NSError {
                XCTAssertEqual(error.domain, "ExternalDataController")
            }
            
            let data = dbQueue.inDatabase { db -> NSData? in
                let record = RecordWithExternalData.fetchOne(db, "SELECT * FROM datas")!
                record.externalData.controller = self.externalDataController
                return record.data
            }
            XCTAssertEqual(data, "foo".dataUsingEncoding(NSUTF8StringEncoding))
        }
    }
}
