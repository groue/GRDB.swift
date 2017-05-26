import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct DecodableStruct : RowConvertible, Decodable {
    let id: Int64?
    let name: String
    let score: Int?
}

private class DecodableClass : RowConvertible, Decodable {
    let id: Int64?
    let name: String
    let score: Int?
    
    init(id: Int64?, name: String, score: Int?) {
        self.id = id
        self.name = name
        self.score = score
    }
}

private struct CustomDecodableStruct : RowConvertible, Decodable {
    let identifier: Int64?
    let pseudo: String
    let score: Int?
    
    private enum CodingKeys : String, CodingKey {
        case identifier = "id"
        case pseudo = "name"
        case score
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decodeIfPresent(Int64.self, forKey: .identifier)
        pseudo = try container.decode(String.self, forKey: .pseudo)
        score = try container.decodeIfPresent(Int.self, forKey: .score).map { $0 * 1001 }
    }
}

private struct DecodableNested : RowConvertible, Decodable {
    let child: DecodableStruct
}

// Not supported yet by Swift
// private class DecodableDerivedClass : DecodableClass {
//     let email: String?
//
//     init(id: Int64?, name: String, score: Int?, email: String?) {
//         self.email = email
//         super.init(id: id, name: name, score: score)
//     }
//
//     // Codable boilerplate
//     private enum CodingKeys : CodingKey {
//         case email
//     }
//
//     required init(from decoder: Decoder) throws {
//         let container = try decoder.container(keyedBy: CodingKeys.self)
//         self.email = try container.decodeIfPresent(String.self, forKey: .email)
//         try super.init(from: container.superDecoder())
//     }
// }

class RowConvertibleCodableTests: GRDBTestCase {
    func testDecodableStruct() {
        do {
            // No null values
            let value = DecodableStruct(row: ["id": 1, "name": "Arthur", "score": 666])
            XCTAssertEqual(value.id, 1)
            XCTAssertEqual(value.name, "Arthur")
            XCTAssertEqual(value.score, 666)
        }
        do {
            // Null, missing, and extra values
            let value = DecodableStruct(row: ["id": nil, "name": "Arthur", "ignored": true])
            XCTAssertNil(value.id)
            XCTAssertEqual(value.name, "Arthur")
            XCTAssertNil(value.score)
        }
    }

    func testCustomDecodableStruct() {
        do {
            // No null values
            let value = CustomDecodableStruct(row: ["id": 1, "name": "Arthur", "score": 666])
            XCTAssertEqual(value.identifier, 1)
            XCTAssertEqual(value.pseudo, "Arthur")
            XCTAssertEqual(value.score, 666666)
        }
        do {
            // Null, missing, and extra values
            let value = CustomDecodableStruct(row: ["id": nil, "name": "Arthur", "ignored": true])
            XCTAssertNil(value.identifier)
            XCTAssertEqual(value.pseudo, "Arthur")
            XCTAssertNil(value.score)
        }
    }
    
    func testDecodableClass() {
        do {
            // No null values
            let value = DecodableClass(row: ["id": 1, "name": "Arthur", "score": 666])
            XCTAssertEqual(value.id, 1)
            XCTAssertEqual(value.name, "Arthur")
            XCTAssertEqual(value.score, 666)
        }
        do {
            // Null, missing, and extra values
            let value = DecodableClass(row: ["id": nil, "name": "Arthur", "ignored": true])
            XCTAssertNil(value.id)
            XCTAssertEqual(value.name, "Arthur")
            XCTAssertNil(value.score)
        }
    }
    
    func testDecodableNested() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let value = try DecodableNested.fetchOne(
                db,
                "SELECT :id AS id, :name AS name, :score AS score",
                arguments: ["id": 1, "name": "Arthur", "score": 666],
                adapter: ScopeAdapter(["child": SuffixRowAdapter(fromIndex: 0)]))!
            XCTAssertEqual(value.child.id, 1)
            XCTAssertEqual(value.child.name, "Arthur")
            XCTAssertEqual(value.child.score, 666)
        }
    }
    
    // Not supported yet by Swift
    // func testDecodableDerivedClass() {
    //     do {
    //         // No null values
    //         let player = DecodableDerivedClass(row: ["id": 1, "name": "Arthur", "score": 666, "email": "arthur@example.com"])
    //         XCTAssertEqual(player.id, 1)
    //         XCTAssertEqual(player.name, "Arthur")
    //         XCTAssertEqual(player.score, 666)
    //         XCTAssertEqual(player.email, "arthur@example.com")
    //     }
    //     do {
    //         // Null, missing, and extra values
    //         let player = DecodableDerivedClass(row: ["id": nil, "name": "Arthur", "ignored": true])
    //         XCTAssertNil(player.id)
    //         XCTAssertEqual(player.name, "Arthur")
    //         XCTAssertNil(player.score)
    //         XCTAssertNil(player.email)
    //     }
    // }
}
