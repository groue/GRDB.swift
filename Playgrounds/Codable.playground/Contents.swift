// To run this playground, select and build the GRDBOSX scheme.

import GRDB

//: Connect to the database

let dbQueue = DatabaseQueue()

//: Define a record type that adopts both RowConvertible and Decodable

struct Player : RowConvertible, Decodable {
    var id: Int64?
    let name: String
    let score: Int
}