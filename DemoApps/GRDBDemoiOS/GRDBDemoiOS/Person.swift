import Foundation
import GRDB

class Person : RowModel {
    var id: Int64!
    var firstName: String?
    var lastName: String?
    var fullName: String {
        return [firstName, lastName].flatMap { $0 }.joinWithSeparator(" ")
    }
    
    init(firstName: String? = nil, lastName: String? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        super.init()
    }
    
    // MARK: - RowModel
    
    override class var databaseTable: Table? {
        return Table(named: "persons", primaryKey: .RowID("id"))
    }
    
    override func updateFromRow(row: Row) {
        for (column, dbv) in row {
            switch column {
            case "id": id = dbv.value()
            case "firstName": firstName = dbv.value()
            case "lastName": lastName = dbv.value()
            default: break
            }
        }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "firstName": firstName,
            "lastName": lastName]
    }

    required init(row: Row) {
        super.init(row: row)
    }
}
