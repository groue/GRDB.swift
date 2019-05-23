import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

enum Color32 : Int32 {
    case red
    case white
    case rose
}

enum Color64 : Int64 {
    case red
    case white
    case rose
}

enum Color : Int {
    case red
    case white
    case rose
}

enum Grape : String {
    case chardonnay
    case merlot
    case riesling
}

extension Color32 : DatabaseValueConvertible { }
extension Color64 : DatabaseValueConvertible { }
extension Color : DatabaseValueConvertible { }
extension Grape : DatabaseValueConvertible { }

class RawRepresentableDatabaseValueConvertibleTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(sql: "CREATE TABLE wines (grape TEXT, color INTEGER)")
        }
        try migrator.migrate(dbWriter)
    }
    
    func testColor32() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            
            do {
                for color in [Color32.red, Color32.white, Color32.rose] {
                    try db.execute(sql: "INSERT INTO wines (color) VALUES (?)", arguments: [color])
                }
                try db.execute(sql: "INSERT INTO wines (color) VALUES (NULL)")
            }
            
            do {
                let rows = try Row.fetchAll(db, sql: "SELECT color FROM wines ORDER BY color")
                let colors = rows.map { $0[0] as Color32? }
                XCTAssertTrue(colors[0] == nil)
                XCTAssertEqual(colors[1]!, Color32.red)
                XCTAssertEqual(colors[2]!, Color32.white)
                XCTAssertEqual(colors[3]!, Color32.rose)
            }
            
            do {
                let colors = try Optional<Color32>.fetchAll(db, sql: "SELECT color FROM wines ORDER BY color")
                XCTAssertTrue(colors[0] == nil)
                XCTAssertEqual(colors[1]!, Color32.red)
                XCTAssertEqual(colors[2]!, Color32.white)
                XCTAssertEqual(colors[3]!, Color32.rose)
            }
            
            return .rollback
        }
    }

    func testColor64() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            
            do {
                for color in [Color64.red, Color64.white, Color64.rose] {
                    try db.execute(sql: "INSERT INTO wines (color) VALUES (?)", arguments: [color])
                }
                try db.execute(sql: "INSERT INTO wines (color) VALUES (NULL)")
            }
            
            do {
                let rows = try Row.fetchAll(db, sql: "SELECT color FROM wines ORDER BY color")
                let colors = rows.map { $0[0] as Color64? }
                XCTAssertTrue(colors[0] == nil)
                XCTAssertEqual(colors[1]!, Color64.red)
                XCTAssertEqual(colors[2]!, Color64.white)
                XCTAssertEqual(colors[3]!, Color64.rose)
            }
            
            do {
                let colors = try Optional<Color64>.fetchAll(db, sql: "SELECT color FROM wines ORDER BY color")
                XCTAssertTrue(colors[0] == nil)
                XCTAssertEqual(colors[1]!, Color64.red)
                XCTAssertEqual(colors[2]!, Color64.white)
                XCTAssertEqual(colors[3]!, Color64.rose)
            }
            
            return .rollback
        }
    }

    func testColor() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            
            do {
                for color in [Color.red, Color.white, Color.rose] {
                    try db.execute(sql: "INSERT INTO wines (color) VALUES (?)", arguments: [color])
                }
                try db.execute(sql: "INSERT INTO wines (color) VALUES (NULL)")
            }
            
            do {
                let rows = try Row.fetchAll(db, sql: "SELECT color FROM wines ORDER BY color")
                let colors = rows.map { $0[0] as Color? }
                XCTAssertTrue(colors[0] == nil)
                XCTAssertEqual(colors[1]!, Color.red)
                XCTAssertEqual(colors[2]!, Color.white)
                XCTAssertEqual(colors[3]!, Color.rose)
            }
            
            do {
                let colors = try Optional<Color>.fetchAll(db, sql: "SELECT color FROM wines ORDER BY color")
                XCTAssertTrue(colors[0] == nil)
                XCTAssertEqual(colors[1]!, Color.red)
                XCTAssertEqual(colors[2]!, Color.white)
                XCTAssertEqual(colors[3]!, Color.rose)
            }
            
            return .rollback
        }
    }

    func testGrape() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            
            do {
                for grape in [Grape.chardonnay, Grape.merlot, Grape.riesling] {
                    try db.execute(sql: "INSERT INTO wines (grape) VALUES (?)", arguments: [grape])
                }
                try db.execute(sql: "INSERT INTO wines (grape) VALUES (NULL)")
            }
            
            do {
                let rows = try Row.fetchAll(db, sql: "SELECT grape FROM wines ORDER BY grape")
                let grapes = rows.map { $0[0] as Grape? }
                XCTAssertTrue(grapes[0] == nil)
                XCTAssertEqual(grapes[1]!, Grape.chardonnay)
                XCTAssertEqual(grapes[2]!, Grape.merlot)
                XCTAssertEqual(grapes[3]!, Grape.riesling)
            }
            
            do {
                let grapes = try Optional<Grape>.fetchAll(db, sql: "SELECT grape FROM wines ORDER BY grape")
                XCTAssertTrue(grapes[0] == nil)
                XCTAssertEqual(grapes[1]!, Grape.chardonnay)
                XCTAssertEqual(grapes[2]!, Grape.merlot)
                XCTAssertEqual(grapes[3]!, Grape.riesling)
            }
            
            return .rollback
        }
    }
}
