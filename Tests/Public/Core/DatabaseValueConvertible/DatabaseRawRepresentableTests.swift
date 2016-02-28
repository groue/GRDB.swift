import XCTest
import GRDB

enum Color32 : Int32 {
    case Red
    case White
    case Rose
}

enum Color64 : Int64 {
    case Red
    case White
    case Rose
}

enum Color : Int {
    case Red
    case White
    case Rose
}

enum Grape : String {
    case Chardonnay
    case Merlot
    case Riesling
}

extension Color32 : DatabaseRawRepresentable { }
extension Color64 : DatabaseRawRepresentable { }
extension Color : DatabaseRawRepresentable { }
extension Grape : DatabaseRawRepresentable { }

class RawRepresentableTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("CREATE TABLE wines (grape TEXT, color INTEGER)")
        }
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testColor32() {
        assertNoError {
            try dbQueue.inTransaction { db in
                
                do {
                    for color in [Color32.Red, Color32.White, Color32.Rose] {
                        try db.execute("INSERT INTO wines (color) VALUES (?)", arguments: [color])
                    }
                    try db.execute("INSERT INTO wines (color) VALUES (?)", arguments: [4])
                    try db.execute("INSERT INTO wines (color) VALUES (NULL)")
                }
                
                do {
                    let rows = Row.fetchAll(db, "SELECT color FROM wines ORDER BY color")
                    let colors = rows.map { $0.value(atIndex: 0) as Color32? }
                    XCTAssertTrue(colors[0] == nil)
                    XCTAssertEqual(colors[1]!, Color32.Red)
                    XCTAssertEqual(colors[2]!, Color32.White)
                    XCTAssertEqual(colors[3]!, Color32.Rose)
                    XCTAssertTrue(colors[4] == nil)
                }
                
                do {
                    let colors = Optional<Color32>.fetchAll(db, "SELECT color FROM wines ORDER BY color")
                    XCTAssertTrue(colors[0] == nil)
                    XCTAssertEqual(colors[1]!, Color32.Red)
                    XCTAssertEqual(colors[2]!, Color32.White)
                    XCTAssertEqual(colors[3]!, Color32.Rose)
                    XCTAssertTrue(colors[4] == nil)
                }
                
                return .Rollback
            }
        }
    }
    
    func testColor64() {
        assertNoError {
            try dbQueue.inTransaction { db in
                
                do {
                    for color in [Color64.Red, Color64.White, Color64.Rose] {
                        try db.execute("INSERT INTO wines (color) VALUES (?)", arguments: [color])
                    }
                    try db.execute("INSERT INTO wines (color) VALUES (?)", arguments: [4])
                    try db.execute("INSERT INTO wines (color) VALUES (NULL)")
                }
                
                do {
                    let rows = Row.fetchAll(db, "SELECT color FROM wines ORDER BY color")
                    let colors = rows.map { $0.value(atIndex: 0) as Color64? }
                    XCTAssertTrue(colors[0] == nil)
                    XCTAssertEqual(colors[1]!, Color64.Red)
                    XCTAssertEqual(colors[2]!, Color64.White)
                    XCTAssertEqual(colors[3]!, Color64.Rose)
                    XCTAssertTrue(colors[4] == nil)
                }
                
                do {
                    let colors = Optional<Color64>.fetchAll(db, "SELECT color FROM wines ORDER BY color")
                    XCTAssertTrue(colors[0] == nil)
                    XCTAssertEqual(colors[1]!, Color64.Red)
                    XCTAssertEqual(colors[2]!, Color64.White)
                    XCTAssertEqual(colors[3]!, Color64.Rose)
                    XCTAssertTrue(colors[4] == nil)
                }
                
                return .Rollback
            }
        }
    }
    
    func testColor() {
        assertNoError {
            try dbQueue.inTransaction { db in
                
                do {
                    for color in [Color.Red, Color.White, Color.Rose] {
                        try db.execute("INSERT INTO wines (color) VALUES (?)", arguments: [color])
                    }
                    try db.execute("INSERT INTO wines (color) VALUES (?)", arguments: [4])
                    try db.execute("INSERT INTO wines (color) VALUES (NULL)")
                }
                
                do {
                    let rows = Row.fetchAll(db, "SELECT color FROM wines ORDER BY color")
                    let colors = rows.map { $0.value(atIndex: 0) as Color? }
                    XCTAssertTrue(colors[0] == nil)
                    XCTAssertEqual(colors[1]!, Color.Red)
                    XCTAssertEqual(colors[2]!, Color.White)
                    XCTAssertEqual(colors[3]!, Color.Rose)
                    XCTAssertTrue(colors[4] == nil)
                }
                
                do {
                    let colors = Optional<Color>.fetchAll(db, "SELECT color FROM wines ORDER BY color")
                    XCTAssertTrue(colors[0] == nil)
                    XCTAssertEqual(colors[1]!, Color.Red)
                    XCTAssertEqual(colors[2]!, Color.White)
                    XCTAssertEqual(colors[3]!, Color.Rose)
                    XCTAssertTrue(colors[4] == nil)
                }
                
                return .Rollback
            }
        }
    }
    
    func testGrape() {
        assertNoError {
            try dbQueue.inTransaction { db in
                
                do {
                    for grape in [Grape.Chardonnay, Grape.Merlot, Grape.Riesling] {
                        try db.execute("INSERT INTO wines (grape) VALUES (?)", arguments: [grape])
                    }
                    try db.execute("INSERT INTO wines (grape) VALUES (?)", arguments: ["Syrah"])
                    try db.execute("INSERT INTO wines (grape) VALUES (NULL)")
                }
                
                do {
                    let rows = Row.fetchAll(db, "SELECT grape FROM wines ORDER BY grape")
                    let grapes = rows.map { $0.value(atIndex: 0) as Grape? }
                    XCTAssertTrue(grapes[0] == nil)
                    XCTAssertEqual(grapes[1]!, Grape.Chardonnay)
                    XCTAssertEqual(grapes[2]!, Grape.Merlot)
                    XCTAssertEqual(grapes[3]!, Grape.Riesling)
                    XCTAssertTrue(grapes[4] == nil)
                }
                
                do {
                    let grapes = Optional<Grape>.fetchAll(db, "SELECT grape FROM wines ORDER BY grape")
                    XCTAssertTrue(grapes[0] == nil)
                    XCTAssertEqual(grapes[1]!, Grape.Chardonnay)
                    XCTAssertEqual(grapes[2]!, Grape.Merlot)
                    XCTAssertEqual(grapes[3]!, Grape.Riesling)
                    XCTAssertTrue(grapes[4] == nil)
                }
                
                return .Rollback
            }
        }
    }
}
