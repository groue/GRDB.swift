import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private enum Color: String, Decodable, DatabaseValueConvertible {
    case red, green, blue
}

private struct DecodableStruct : RowConvertible, Decodable {
    let id: Int64?
    let name: String
    let color: Color?
}

private class DecodableClass : RowConvertible, Decodable {
    let id: Int64?
    let name: String
    let color: Color?
    
    init(id: Int64?, name: String, color: Color?) {
        self.id = id
        self.name = name
        self.color = color
    }
}

private struct CustomDecodableStruct : RowConvertible, Decodable {
    let identifier: Int64?
    let pseudo: String
    let color: Color?
    
    private enum CodingKeys : String, CodingKey {
        case identifier = "id"
        case pseudo = "name"
        case color
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decodeIfPresent(Int64.self, forKey: .identifier)
        pseudo = try container.decode(String.self, forKey: .pseudo).uppercased()
        color = try container.decodeIfPresent(Color.self, forKey: .color)
    }
}

private struct DecodableNested : RowConvertible, Decodable {
    let child: DecodableStruct
}

// Not supported yet by Swift
// private class DecodableDerivedClass : DecodableClass {
//     let email: String?
//
//     init(id: Int64?, name: String, color: Color?, email: String?) {
//         self.email = email
//         super.init(id: id, name: name, color: color)
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
            let value = DecodableStruct(row: ["id": 1, "name": "Arthur", "color": "red"])
            XCTAssertEqual(value.id, 1)
            XCTAssertEqual(value.name, "Arthur")
            XCTAssertEqual(value.color, .red)
        }
        do {
            // Null, missing, and extra values
            let value = DecodableStruct(row: ["id": nil, "name": "Arthur", "ignored": true])
            XCTAssertNil(value.id)
            XCTAssertEqual(value.name, "Arthur")
            XCTAssertNil(value.color)
        }
    }

    func testCustomDecodableStruct() {
        do {
            // No null values
            let value = CustomDecodableStruct(row: ["id": 1, "name": "Arthur", "color": "red"])
            XCTAssertEqual(value.identifier, 1)
            XCTAssertEqual(value.pseudo, "ARTHUR")
            XCTAssertEqual(value.color, .red)
        }
        do {
            // Null, missing, and extra values
            let value = CustomDecodableStruct(row: ["id": nil, "name": "Arthur", "ignored": true])
            XCTAssertNil(value.identifier)
            XCTAssertEqual(value.pseudo, "ARTHUR")
            XCTAssertNil(value.color)
        }
    }
    
    func testDecodableClass() {
        do {
            // No null values
            let value = DecodableClass(row: ["id": 1, "name": "Arthur", "color": "red"])
            XCTAssertEqual(value.id, 1)
            XCTAssertEqual(value.name, "Arthur")
            XCTAssertEqual(value.color, .red)
        }
        do {
            // Null, missing, and extra values
            let value = DecodableClass(row: ["id": nil, "name": "Arthur", "ignored": true])
            XCTAssertNil(value.id)
            XCTAssertEqual(value.name, "Arthur")
            XCTAssertNil(value.color)
        }
    }
    
    func testDecodableNested() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let value = try DecodableNested.fetchOne(
                db,
                "SELECT :id AS id, :name AS name, :color AS color",
                arguments: ["id": 1, "name": "Arthur", "color": "red"],
                adapter: ScopeAdapter(["child": SuffixRowAdapter(fromIndex: 0)]))!
            XCTAssertEqual(value.child.id, 1)
            XCTAssertEqual(value.child.name, "Arthur")
            XCTAssertEqual(value.child.color, .red)
        }
    }
    
    // Not supported yet by Swift
    // func testDecodableDerivedClass() {
    //     do {
    //         // No null values
    //         let player = DecodableDerivedClass(row: ["id": 1, "name": "Arthur", "color": "red", "email": "arthur@example.com"])
    //         XCTAssertEqual(player.id, 1)
    //         XCTAssertEqual(player.name, "Arthur")
    //         XCTAssertEqual(player.color, .red)
    //         XCTAssertEqual(player.email, "arthur@example.com")
    //     }
    //     do {
    //         // Null, missing, and extra values
    //         let player = DecodableDerivedClass(row: ["id": nil, "name": "Arthur", "ignored": true])
    //         XCTAssertNil(player.id)
    //         XCTAssertEqual(player.name, "Arthur")
    //         XCTAssertNil(player.color)
    //         XCTAssertNil(player.email)
    //     }
    // }
}
