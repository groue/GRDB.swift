import XCTest
import Foundation
import GRDB
#if GRDB_COMPARE
import CoreData
import RealmSwift
#endif

func generateSQLiteDatabaseIfMissing(at url: URL, insertedRowCount: Int) throws {
    try DatabaseQueue(path: url.path).write { db in
        if try db.tableExists("item") {
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item")!
            if count == insertedRowCount {
                return
            } else {
                try db.execute(sql: "DROP TABLE item")
            }
        }
        try db.execute(sql: "CREATE TABLE item (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
        
        let statement = try! db.makeStatement(sql: "INSERT INTO item (i0, i1, i2, i3, i4, i5, i6, i7, i8, i9) VALUES (?,?,?,?,?,?,?,?,?,?)")
        for i in 0..<insertedRowCount {
            try statement.execute(arguments: [i, i, i, i, i, i, i, i, i, i])
        }
    }
}

#if GRDB_COMPARE
func generateCoreDataDatabaseIfMissing(at url: URL, fromModelAt modelURL: URL, insertedRowCount: Int) throws {
    let mom = NSManagedObjectModel(contentsOf: modelURL)!
    let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
    try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
    let moc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    moc.performAndWait {
        moc.persistentStoreCoordinator = psc
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Item")
        if try! moc.count(for: request) == insertedRowCount {
            return
        }
        try! moc.execute(NSBatchDeleteRequest(fetchRequest: request))
        
        for i in 0..<insertedRowCount {
            let item = NSEntityDescription.insertNewObject(forEntityName: "Item", into: moc)
            item.setValue(NSNumber(value: i), forKey: "i0")
            item.setValue(NSNumber(value: i), forKey: "i1")
            item.setValue(NSNumber(value: i), forKey: "i2")
            item.setValue(NSNumber(value: i), forKey: "i3")
            item.setValue(NSNumber(value: i), forKey: "i4")
            item.setValue(NSNumber(value: i), forKey: "i5")
            item.setValue(NSNumber(value: i), forKey: "i6")
            item.setValue(NSNumber(value: i), forKey: "i7")
            item.setValue(NSNumber(value: i), forKey: "i8")
            item.setValue(NSNumber(value: i), forKey: "i9")
        }
        try! moc.save()
    }
}

func generateRealmDatabaseIfMissing(at url: URL, insertedRowCount: Int) throws {
    let realm = try Realm(fileURL: url)
    try realm.write {
        if realm.objects(RealmItem.self).count == insertedRowCount {
            return
        }
        
        realm.deleteAll()
        for i in 0..<insertedRowCount {
            realm.add(RealmItem(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i))
        }
    }
}
#endif
