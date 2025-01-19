import XCTest
import GRDB

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
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "teams") { t in
                t.primaryKey("id", .integer)
                t.column("name", .text)
            }
            try db.create(table: "players") { t in
                t.primaryKey("id", .integer)
                t.belongsTo("team")
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
            let adapter = try request.makePreparedRequest(db, forSingleResult: false).adapter
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
    
    func testDefaultScopeIncludingRequiredEmptySelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.select([]).including(required: Player.defaultTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes.names), ["team"])
        XCTAssertEqual(rows[0].scopes["team"]!, ["id":1, "name":"Reds"])
    }
    
    func testDefaultScopeIncludingRequiredRestrictedSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.select(.allColumns(excluding: ["name"])).including(required: Player.defaultTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1])
        XCTAssertEqual(Set(rows[0].scopes.names), ["team"])
        XCTAssertEqual(rows[0].scopes["team"]!, ["id":1, "name":"Reds"])
    }
    
    func testDefaultScopeAnnotatedWithRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withRequired: Player.defaultTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "id":1, "name":"Reds"])
    }
    
    func testDefaultScopeAnnotatedWithRequiredCustomSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withRequired: Player.defaultTeam.select(Column("name").forKey("teamName")))
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "teamName":"Reds"])
    }
    
    func testDefaultScopeAnnotatedWithRequiredRestrictedSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withRequired: Player.defaultTeam.select(.allColumns(excluding: ["name"])))
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "id":1])
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
    
    func testDefaultScopeAnnotatedWithOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withOptional: Player.defaultTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "id":1, "name":"Reds"])
        XCTAssertEqual(rows[1], ["id":2, "teamId":nil, "name":"Barbara", "id":nil, "name":nil])
    }
    
    func testDefaultScopeAnnotatedWithOptionalCustomSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withOptional: Player.defaultTeam.select(Column("name").forKey("teamName")))
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "teamName":"Reds"])
        XCTAssertEqual(rows[1], ["id":2, "teamId":nil, "name":"Barbara", "teamName":nil])
    }

    func testDefaultScopeAnnotatedWithOptionalRestrictedSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withOptional: Player.defaultTeam.select(.allColumns(excluding: ["name"])))
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "id":1])
        XCTAssertEqual(rows[1], ["id":2, "teamId":nil, "name":"Barbara", "id":nil])
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
    
    func testCustomScopeIncludingRequiredEmptySelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.select([]).including(required: Player.customTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes.names), ["customTeam"])
        XCTAssertEqual(rows[0].scopes["customTeam"]!, ["id":1, "name":"Reds"])
    }
    
    func testCustomScopeIncludingRequiredRestrictedSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.select(.allColumns(excluding: ["name"])).including(required: Player.customTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "teamId":1])
        XCTAssertEqual(Set(rows[0].scopes.names), ["customTeam"])
        XCTAssertEqual(rows[0].scopes["customTeam"]!, ["id":1, "name":"Reds"])
    }
    
    func testCustomScopeAnnotatedWithRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withRequired: Player.customTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "id":1, "name":"Reds"])
    }
    
    func testCustomScopeAnnotatedWithRequiredCustomSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withRequired: Player.customTeam.select(Column("name").forKey("teamName")))
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "teamName":"Reds"])
    }
    
    func testCustomScopeAnnotatedWithRequiredRestrictedSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withRequired: Player.customTeam.select(.allColumns(excluding: ["name"])))
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "id":1])
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
    
    func testCustomScopeAnnotatedWithOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withOptional: Player.customTeam)
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "id":1, "name":"Reds"])
        XCTAssertEqual(rows[1], ["id":2, "teamId":nil, "name":"Barbara", "id":nil, "name":nil])
    }
    
    func testCustomScopeAnnotatedWithOptionalCustomSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withOptional: Player.customTeam.select(Column("name").forKey("teamName")))
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "teamName":"Reds"])
        XCTAssertEqual(rows[1], ["id":2, "teamId":nil, "name":"Barbara", "teamName":nil])
    }
    
    func testCustomScopeAnnotatedWithOptionalRestrictedSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.annotated(withOptional: Player.customTeam.select(.allColumns(excluding: ["name"])))
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["id":1, "teamId":1, "name":"Arthur", "id":1])
        XCTAssertEqual(rows[1], ["id":2, "teamId":nil, "name":"Barbara", "id":nil])
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
