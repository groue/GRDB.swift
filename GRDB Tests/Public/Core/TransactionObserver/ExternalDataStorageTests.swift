import XCTest
import GRDB

class ExternalDataStorage : TransactionObserverType {
    let path: String
    let forbiddenData: NSData?
    private var data: NSData?? = nil
    private var dataForRowID: [Int64: NSData?] = [:]
    var movedRowIDs: [Int64] = []
    var storedRowIDs: [Int64] = []
    var restoreOnRollback: Bool = false
    
    init(path: String, forbiddenData: NSData?) {
        self.path = path
        self.forbiddenData = forbiddenData
        setupDirectories()
    }
    
    func willSaveData(data: NSData?) {
        self.data = data
    }
    
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        guard let data = data else {
            return
        }
        
        switch event.kind {
        case .Insert, .Update:
            dataForRowID[event.rowID] = data
        default:
            break
        }
        self.data = nil
    }
    
    func databaseWillCommit() throws {
        do {
            let fm = NSFileManager.defaultManager()
            print(dataForRowID)
            for (rowID, data) in dataForRowID.sort({ $0.0 < $1.0 }) {
                if let forbiddenData = forbiddenData where forbiddenData == data {
                    throw NSError(domain: "ExternalDataStorage", code: 0, userInfo: nil)
                }
                
                let storagePath = storageDataPath(rowID)
                let tempPath = temporaryDataPath(rowID)
                if fm.fileExistsAtPath(storagePath) {
                    if fm.fileExistsAtPath(tempPath) {
                        try! fm.removeItemAtPath(tempPath)
                    }
                    try fm.moveItemAtPath(storagePath, toPath: tempPath)
                }
                movedRowIDs.append(rowID)
                if let data = data {
                    try data.writeToFile(storagePath, options: [])
                }
                storedRowIDs.append(rowID)
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
            for rowID in storedRowIDs {
                if fm.fileExistsAtPath(storageDataPath(rowID)) {
                    try! fm.removeItemAtPath(storageDataPath(rowID))
                }
            }
            for rowID in movedRowIDs {
                if fm.fileExistsAtPath(temporaryDataPath(rowID)) {
                    try! fm.moveItemAtPath(temporaryDataPath(rowID), toPath: storageDataPath(rowID))
                }
            }
        }
        cleanup()
    }
    
    func cleanup() {
        restoreOnRollback = false
        movedRowIDs = []
        storedRowIDs = []
        dataForRowID = [:]
    }
    
    func loadData(rowID: Int64) -> NSData? {
        let fm = NSFileManager.defaultManager()
        if fm.fileExistsAtPath(storageDataPath(rowID)) {
            return NSData(contentsOfFile: storageDataPath(rowID))!
        } else {
            return nil
        }
    }
    
    private var temporaryDirectoryPath: String {
        return (path as NSString).stringByAppendingPathComponent("tmp")
    }
    
    private func storageDataPath(rowID: Int64) -> String {
        return (path as NSString).stringByAppendingPathComponent(String(rowID))
    }
    
    private func temporaryDataPath(rowID: Int64) -> String {
        return (temporaryDirectoryPath as NSString).stringByAppendingPathComponent(String(rowID))
    }
    
    private func setupDirectories() {
        let fm = NSFileManager.defaultManager()
        try! fm.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
        try! fm.createDirectoryAtPath(temporaryDirectoryPath, withIntermediateDirectories: true, attributes: nil)
    }
}

class ExternalDataProxy {
    let externalDataStorage: ExternalDataStorage
    var rowID: Int64?
    var data: NSData? {
        get {
            if let _data = _data {
                return _data
            } else {
                _data = externalDataStorage.loadData(rowID!)
                return _data!
            }
        }
        set {
            _data = newValue
        }
    }
    var _data: NSData??
    
    init(externalDataStorage: ExternalDataStorage) {
        self.externalDataStorage = externalDataStorage
    }
    
    func willSave() {
        externalDataStorage.willSaveData(data)
    }
}

class RecordWithExternalData : Record {
    var id: Int64? {
        didSet {
            if let externalDataProxy = externalDataProxy {
                externalDataProxy.rowID = id
            }
        }
    }
    var title: String?
    var data: NSData? {
        get { return externalDataProxy!.data }
        set { externalDataProxy!.data = newValue }
    }
    
    override static func databaseTableName() -> String {
        return "datas"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "title": title]
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["id"] { id = dbv.value() }
        if let dbv = row["title"] { title = dbv.value() }
        super.updateFromRow(row)
    }
    
    //
    
    private var externalDataProxy: ExternalDataProxy? {
        didSet {
            if let externalDataProxy = externalDataProxy {
                externalDataProxy.rowID = id
            }
        }
    }
    
    override func insert(db: Database) throws {
        externalDataProxy!.willSave()
        try super.insert(db)
    }
    
    override func update(db: Database) throws {
        externalDataProxy!.willSave()
        try super.update(db)
    }
    
    //
    
    static func setupInDatabase(db: Database) throws {
        // TODO: make tests run with a single "id INTEGER PRIMARY KEY" column.
        // The "update" method doing nothing in this case, we expect troubles.
        try db.execute(
            "CREATE TABLE datas (id INTEGER PRIMARY KEY, title TEXT)")
    }
}

class ExperimentalTransactionObserverTests : GRDBTestCase {
    var externalDataStorage: ExternalDataStorage!
    
    override var dbConfiguration: Configuration {
        externalDataStorage = ExternalDataStorage(path: "/tmp/ExternalDataStorage", forbiddenData: "Bunny".dataUsingEncoding(NSUTF8StringEncoding))
        var c = super.dbConfiguration
        c.transactionObserver = externalDataStorage
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
                record.externalDataProxy = ExternalDataProxy(externalDataStorage: self.externalDataStorage)
                record.data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
                try record.save(db)
            }
            
            dbQueue.inDatabase { db in
                let record = RecordWithExternalData.fetchOne(db, "SELECT * FROM datas")!
                // TODO: this explicit line is a problem
                record.externalDataProxy = ExternalDataProxy(externalDataStorage: self.externalDataStorage)
                XCTAssertEqual(record.data, "foo".dataUsingEncoding(NSUTF8StringEncoding))
            }
        }
    }
    
    func testError() {
        assertNoError {
            let record = RecordWithExternalData()
            record.externalDataProxy = ExternalDataProxy(externalDataStorage: self.externalDataStorage)
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
                    forbiddenRecord.externalDataProxy = ExternalDataProxy(externalDataStorage: self.externalDataStorage)
                    forbiddenRecord.data = "Bunny".dataUsingEncoding(NSUTF8StringEncoding)
                    try forbiddenRecord.save(db)
                    return .Commit
                }
                XCTFail("Expected error")
            } catch let error as NSError {
                XCTAssertEqual(error.domain, "ExternalDataStorage")
            }
            
            let data = dbQueue.inDatabase { db -> NSData? in
                let record = RecordWithExternalData.fetchOne(db, "SELECT * FROM datas")!
                record.externalDataProxy = ExternalDataProxy(externalDataStorage: self.externalDataStorage)
                return record.data
            }
            XCTAssertEqual(data, "foo".dataUsingEncoding(NSUTF8StringEncoding))
        }
    }
}
