//
//  DatabaseJSONSuperEncoderTests.swift
//
//
//  Created by Finn Behrens on 06.05.22.
//

import GRDB
import XCTest

private struct JSON: Codable, FetchableRecord, PersistableRecord {
    internal init(json: JSON.Content = .init(a: 2, b: "test string"), x: Int64 = 1) {
        self.json = json
        self.x = x
    }

    static var databaseTableName: String = "json"

    var json: Content
    var x: Int64

    struct Content: Codable {
        var a: Int
        var b: String
    }

    enum CodingKeys: String, CodingKey {
        case x
        case json
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        try container.encode(x, forKey: .x)

        let superEncoder = container.superEncoder(forKey: .json)
        try json.encode(to: superEncoder)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        x = try container.decode(Int64.self, forKey: .x)

        let superDecoder = try container.superDecoder(forKey: .json)
        json = try Content(from: superDecoder)
    }
}

class DatabaseJSONSuperEncoderTests: GRDBTestCase {
    func testSuperEncoderForKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE json (json TEXT, x INTEGER)")

            try JSON().insert(db)
        }
    }

}
