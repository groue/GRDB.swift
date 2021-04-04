import XCTest
import GRDB
@testable import GRDBCombineDemo

class PlayerRequestTests: XCTestCase {
    func test_PlayerRequest_byName_fetches_well_ordered_players() throws {
        // Given a players database that contains two players
        let dbQueue = DatabaseQueue()
        _ = try AppDatabase(dbQueue)
        var player1 = Player(id: nil, name: "Arthur", score: 100)
        var player2 = Player(id: nil, name: "Barbara", score: 1000)
        try dbQueue.write { db in
            try player1.insert(db)
            try player2.insert(db)
        }
        
        // When we fetch players ordered by name
        let playerRequest = PlayerRequest(ordering: .byName)
        let players = try dbQueue.read(playerRequest.fetchValue)
        
        // Then the players are the two players ordered by name
        XCTAssertEqual(players, [player1, player2])
    }
    
    func test_PlayerRequest_byScore_fetches_well_ordered_players() throws {
        // Given a players database that contains two players
        let dbQueue = DatabaseQueue()
        _ = try AppDatabase(dbQueue)
        var player1 = Player(id: nil, name: "Arthur", score: 100)
        var player2 = Player(id: nil, name: "Barbara", score: 1000)
        try dbQueue.write { db in
            try player1.insert(db)
            try player2.insert(db)
        }
        
        // When we fetch players ordered by score
        let playerRequest = PlayerRequest(ordering: .byScore)
        let players = try dbQueue.read(playerRequest.fetchValue)
        
        // Then the players are the two players ordered by score descending
        XCTAssertEqual(players, [player2, player1])
    }
}
