import GRDB

class Person : Record {
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
    
    // MARK: - Record
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    override class func databaseTableName() -> String {
        return "persons"
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["id"] { id = dbv.value() }
        if let dbv = row["firstName"] { firstName = dbv.value() }
        if let dbv = row["lastName"] { lastName = dbv.value() }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "firstName": firstName,
            "lastName": lastName]
    }
}

extension Person : Hashable {
    
    var hashValue: Int {
        return self.id.hashValue
    }
}

func ==(lhs: Person, rhs: Person) -> Bool {
    return lhs.id == rhs.id
}
