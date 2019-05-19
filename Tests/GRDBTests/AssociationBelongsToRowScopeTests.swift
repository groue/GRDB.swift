import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct Team: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "teams"
    var id: Int64
    var name: String
}

private struct Player: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "players"
    static let defaultTeam = belongsTo(Team.self)
    static let customTeam = belongsTo(Team.self, key: "customTeam")
    var id: Int64
    var teamId: Int64?
    var name: String
}

/// Test row scopes
class AssociationBelongsToRowScopeTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "teams") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.create(table: "players") { t in
                t.column("id", .integer).primaryKey()
                t.column("teamId", .integer).references("teams")
                t.column("name", .text)
            }
            
            try Team(id: 1, name: "Reds").insert(db)
            try Player(id: 1, teamId: 1, name: "Arthur").insert(db)
            try Player(id: 2, teamId: nil, name: "Barbara").insert(db)
        }
    }
    
    func testJoiningDoesNotUseAnyRowAdapter() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = Player.joining(required: Player.defaultTeam)
            let (_, adapter) = try request.prepare(db, forSingleResult: false)
            XCTAssertNil(adapter)
        }
    }
    
    func testDefaultScopeIncludingRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.including(required: Player.defaultTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["team"])
        XCTAssertEqual(rows[0].scopes["team"]!, ["id":1, "name":"Reds"])
    }
    
    func testDefaultScopeIncludingOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.including(optional: Player.defaultTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["team"])
        XCTAssertEqual(rows[0].scopes["team"]!, ["id":1, "name":"Reds"])
        XCTAssertEqual(rows[1].unscoped, ["id":2, "teamId":nil, "name":"Barbara"])
        XCTAssertEqual(Set(rows[1].scopes.names), ["team"])
        XCTAssertEqual(rows[1].scopes["team"]!, ["id":nil, "name":nil])
    }
    
    func testDefaultScopeJoiningRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.joining(required: Player.defaultTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
        XCTAssertTrue(rows[0].scopes.names.isEmpty)
    }
    
    func testDefaultScopeJoiningOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.joining(optional: Player.defaultTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
        XCTAssertTrue(rows[0].scopes.names.isEmpty)
        XCTAssertEqual(rows[1].unscoped, ["id":2, "teamId":nil, "name":"Barbara"])
        XCTAssertTrue(rows[0].scopes.names.isEmpty)
    }
    
    func testCustomScopeIncludingRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.including(required: Player.customTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["customTeam"])
        XCTAssertEqual(rows[0].scopes["customTeam"]!, ["id":1, "name":"Reds"])
    }
    
    func testCustomScopeIncludingOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.including(optional: Player.customTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["customTeam"])
        XCTAssertEqual(rows[0].scopes["customTeam"]!, ["id":1, "name":"Reds"])
        XCTAssertEqual(rows[1].unscoped, ["id":2, "teamId":nil, "name":"Barbara"])
        XCTAssertEqual(Set(rows[1].scopes.names), ["customTeam"])
        XCTAssertEqual(rows[1].scopes["customTeam"]!, ["id":nil, "name":nil])
    }
    
    func testCustomPluralScopeIncludingRequired() throws {
        // Make sure explicit plural keys are preserved
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = Player.including(required: Player.belongsTo(Team.self, key: "teams"))
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["teams"])
            XCTAssertEqual(rows[0].scopes["teams"]!, ["id":1, "name":"Reds"])
        }
        do {
            let request = Player.including(required: Player.defaultTeam.forKey("teams"))
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["teams"])
            XCTAssertEqual(rows[0].scopes["teams"]!, ["id":1, "name":"Reds"])
        }
    }
    
    func testCustomPluralScopeIncludingOptional() throws {
        // Make sure explicit plural keys are preserved
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = Player.including(optional: Player.belongsTo(Team.self, key: "teams"))
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["teams"])
            XCTAssertEqual(rows[0].scopes["teams"]!, ["id":1, "name":"Reds"])
            XCTAssertEqual(rows[1].unscoped, ["id":2, "teamId":nil, "name":"Barbara"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["teams"])
            XCTAssertEqual(rows[1].scopes["teams"]!, ["id":nil, "name":nil])
        }
        do {
            let request = Player.including(optional: Player.defaultTeam.forKey("teams"))
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["teams"])
            XCTAssertEqual(rows[0].scopes["teams"]!, ["id":1, "name":"Reds"])
            XCTAssertEqual(rows[1].unscoped, ["id":2, "teamId":nil, "name":"Barbara"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["teams"])
            XCTAssertEqual(rows[1].scopes["teams"]!, ["id":nil, "name":nil])
        }
    }

    func testCustomScopeJoiningRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.joining(required: Player.customTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
        XCTAssertTrue(rows[0].scopes.names.isEmpty)
    }
    
    func testCustomScopeJoiningOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.joining(optional: Player.customTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1, "name":"Arthur"])
        XCTAssertTrue(rows[0].scopes.names.isEmpty)
        XCTAssertEqual(rows[1].unscoped, ["id":2, "teamId":nil, "name":"Barbara"])
        XCTAssertTrue(rows[0].scopes.names.isEmpty)
    }
}
