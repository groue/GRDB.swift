// Issue156
//
// This playground exists as a test of issue #156, for which I'm not sure we
// have a test today.

import Foundation
import GRDB
import PlaygroundSupport

class TestDeleteAll: NSObject {
    
    let databasePool: DatabasePool
    let fetchedRecordsController: FetchedRecordsController<MyRecord>
    
    override init() {
        // Init a databasePool & a fetchedRecordsController
        
        let databasePath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/myDatabase.sqlite"
        databasePool = try! DatabasePool(path: databasePath)
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("1") { db in
            try! db.create(table: MyRecord.databaseTableName) { t in
                t.column(MyRecord.MyColumn.name, .text)
            }
        }
        try! migrator.migrate(databasePool)
        
        fetchedRecordsController = try! FetchedRecordsController<MyRecord>(databasePool, request: MyRecord.all())
        try! fetchedRecordsController.performFetch()
        fetchedRecordsController.trackChanges { controller in
            print("RecordsDidChange triggered: number of records = \(controller.fetchedRecords.count)\n")
        }
        
        super.init()
        run()
    }
    
    func run() {
        insertThreeRecords()
        perform(#selector(deleteAllWithFilter), with: nil, afterDelay: 1)
        perform(#selector(insertThreeRecords), with: nil, afterDelay: 2)
        perform(#selector(deleteAll), with: nil, afterDelay: 3)
        perform(#selector(insertThreeRecords), with: nil, afterDelay: 4)
    }
    
    @objc
    func insertThreeRecords() {
        print("Insert 3 records")
        let myRecord1 = MyRecord(myColumn: "1")
        let myRecord2 = MyRecord(myColumn: "2")
        let myRecord3 = MyRecord(myColumn: "3")
        try! databasePool.writeInTransaction { db in
            try myRecord1.save(db)
            try myRecord2.save(db)
            try myRecord3.save(db)
            return .commit
        }
    }
    
    @objc
    func deleteAllWithFilter() {
        print("Delete all records with filter(1 == 1).deleteAll(db)")
        _ = try! databasePool.write { db in
            try MyRecord.filter(1 == 1).deleteAll(db)
        }
    }
    
    @objc
    func deleteAll() {
        print("Delete all records with deleteAll(db)")
        _ = try! databasePool.write { db in
            try MyRecord.deleteAll(db)
        }
    }
    
}

struct MyRecord: FetchableRecord, TableRecord, PersistableRecord {
    
    static let MyColumn = Column("MyColumn")
    static var databaseTableName: String { return String(describing: self) }
    
    let myColumn: String
    
    init(myColumn: String) {
        self.myColumn = myColumn
    }
    
    init(row: Row) {
        self.myColumn = row[MyRecord.MyColumn]
    }
    
    func encode(to container: inout PersistenceContainer) {
        container[MyRecord.MyColumn] = myColumn
    }
}


TestDeleteAll()
PlaygroundPage.current.needsIndefiniteExecution = true
