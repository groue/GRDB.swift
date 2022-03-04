import XCTest
import GRDB

private enum Color32 : Int32 {
    case red
    case white
    case rose
}

private enum Color64 : Int64 {
    case red
    case white
    case rose
}

private enum Color : Int {
    case red
    case white
    case rose
}

private enum Grape : String {
    case chardonnay
    case merlot
    case riesling
}

private enum FastGrape : String {
    case chardonnay
    case merlot
    case riesling
}

private struct Wrapper<RawValue>: RawRepresentable {
    var rawValue: RawValue
}

private struct FastWrapper<RawValue>: RawRepresentable {
    var rawValue: RawValue
}

extension Color32 : DatabaseValueConvertible { }
extension Color64 : DatabaseValueConvertible { }
extension Color : DatabaseValueConvertible { }
extension Grape : DatabaseValueConvertible { }
extension FastGrape : DatabaseValueConvertible, StatementColumnConvertible { }

extension Wrapper: SQLExpressible where RawValue: SQLExpressible { }
extension Wrapper: StatementBinding where RawValue: StatementBinding { }
extension Wrapper: DatabaseValueConvertible where RawValue: DatabaseValueConvertible { }

extension FastWrapper: SQLSelectable where RawValue: SQLSelectable { }
extension FastWrapper: SQLOrderingTerm where RawValue: SQLOrderingTerm { }
extension FastWrapper: SQLSpecificExpressible where RawValue: SQLSpecificExpressible { }
extension FastWrapper: SQLExpressible where RawValue: SQLExpressible { }
extension FastWrapper: StatementBinding where RawValue: StatementBinding { }
extension FastWrapper: DatabaseValueConvertible where RawValue: DatabaseValueConvertible { }
extension FastWrapper: StatementColumnConvertible where RawValue: StatementColumnConvertible { }

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
                let colors = try rows.map { try $0[0] as Color32? }
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
                let colors = try rows.map { try $0[0] as Color64? }
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
                let colors = try rows.map { try $0[0] as Color? }
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
                let grapes = try rows.map { try $0[0] as Grape? }
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

    func testFastGrape() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            
            do {
                for grape in [FastGrape.chardonnay, FastGrape.merlot, FastGrape.riesling] {
                    try db.execute(sql: "INSERT INTO wines (grape) VALUES (?)", arguments: [grape])
                }
                try db.execute(sql: "INSERT INTO wines (grape) VALUES (NULL)")
            }
            
            do {
                let rows = try Row.fetchAll(db, sql: "SELECT grape FROM wines ORDER BY grape")
                let grapes = try rows.map { try $0[0] as FastGrape? }
                XCTAssertTrue(grapes[0] == nil)
                XCTAssertEqual(grapes[1]!, FastGrape.chardonnay)
                XCTAssertEqual(grapes[2]!, FastGrape.merlot)
                XCTAssertEqual(grapes[3]!, FastGrape.riesling)
            }
            
            do {
                let grapes = try Optional<FastGrape>.fetchAll(db, sql: "SELECT grape FROM wines ORDER BY grape")
                XCTAssertTrue(grapes[0] == nil)
                XCTAssertEqual(grapes[1]!, FastGrape.chardonnay)
                XCTAssertEqual(grapes[2]!, FastGrape.merlot)
                XCTAssertEqual(grapes[3]!, FastGrape.riesling)
            }
            
            return .rollback
        }
    }

    func testWrapper() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            
            do {
                for color in [Wrapper(rawValue: 0), Wrapper(rawValue: 1), Wrapper(rawValue: 2)] {
                    try db.execute(sql: "INSERT INTO wines (color) VALUES (?)", arguments: [color])
                }
                try db.execute(sql: "INSERT INTO wines (color) VALUES (NULL)")
            }
            
            do {
                let rows = try Row.fetchAll(db, sql: "SELECT color FROM wines ORDER BY color")
                let values = try rows.map { try $0[0] as Wrapper<Int>? }
                XCTAssertTrue(values[0] == nil)
                XCTAssertEqual(values[1]!.rawValue, 0)
                XCTAssertEqual(values[2]!.rawValue, 1)
                XCTAssertEqual(values[3]!.rawValue, 2)
            }
            
            do {
                let values = try Optional<Wrapper<Int>>.fetchAll(db, sql: "SELECT color FROM wines ORDER BY color")
                XCTAssertTrue(values[0] == nil)
                XCTAssertEqual(values[1]!.rawValue, 0)
                XCTAssertEqual(values[2]!.rawValue, 1)
                XCTAssertEqual(values[3]!.rawValue, 2)
            }
            
            return .rollback
        }
    }

    func testFastWrapper() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inTransaction { db in
            
            do {
                for color in [FastWrapper(rawValue: 0), FastWrapper(rawValue: 1), FastWrapper(rawValue: 2)] {
                    try db.execute(sql: "INSERT INTO wines (color) VALUES (?)", arguments: [color])
                }
                try db.execute(sql: "INSERT INTO wines (color) VALUES (NULL)")
            }
            
            do {
                let rows = try Row.fetchAll(db, sql: "SELECT color FROM wines ORDER BY color")
                let values = try rows.map { try $0[0] as FastWrapper<Int>? }
                XCTAssertTrue(values[0] == nil)
                XCTAssertEqual(values[1]!.rawValue, 0)
                XCTAssertEqual(values[2]!.rawValue, 1)
                XCTAssertEqual(values[3]!.rawValue, 2)
            }
            
            do {
                let values = try Optional<FastWrapper<Int>>.fetchAll(db, sql: "SELECT color FROM wines ORDER BY color")
                XCTAssertTrue(values[0] == nil)
                XCTAssertEqual(values[1]!.rawValue, 0)
                XCTAssertEqual(values[2]!.rawValue, 1)
                XCTAssertEqual(values[3]!.rawValue, 2)
            }
            
            return .rollback
        }
    }
}
