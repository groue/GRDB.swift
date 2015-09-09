import XCTest
import GRDB

class RowModelWithoutDatabaseTableName: RowModel { }
class RowModelWithoutDatabaseTable: RowModel {
    override static func databaseTableName() -> String? {
        return "foo"
    }
}

class InvalidRowModelTests: GRDBTestCase {
    
    // =========================================================================
    // MARK: - RowModelWithoutDatabaseTableName
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeFetchedByID() {
//        dbQueue.inDatabase { db in
//            RowModelWithoutDatabaseTableName.fetchOne(db, primaryKey: 1)
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeFetchedByKey() {
//        dbQueue.inDatabase { db in
//            RowModelWithoutDatabaseTableName.fetchOne(db, key: ["foo": "bar"])
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeInserted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTableName().insert(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTableName().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeSaved() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTableName().save(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTableName().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTableName().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeTestedForExistence() {
//        assertNoError {
//            dbQueue.inDatabase { db in
//                RowModelWithoutDatabaseTableName().exists(db)
//            }
//        }
//    }
    
    
    // =========================================================================
    // MARK: - RowModelWithoutDatabaseTable
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableCanNotBeFetchedByID() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                RowModelWithoutDatabaseTable.fetchOne(db, primaryKey: 1)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableCanNotBeFetchedByKey() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                RowModelWithoutDatabaseTable.fetchOne(db, key: ["id": 1])
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableCanNotBeInserted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTable().insert(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTable().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableCanNotBeSaved() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTable().save(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTable().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTable().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableCanNotBeTestedForExistence() {
//        assertNoError {
//            dbQueue.inDatabase { db in
//                RowModelWithoutDatabaseTable().exists(db)
//            }
//        }
//    }
}
