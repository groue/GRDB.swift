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
    
    override class func databaseTableName() -> String {
        return "persons"
    }
    
    required init(_ row: Row) {
        id = row.value(named: "id")
        firstName = row.value(named: "firstName")
        lastName = row.value(named: "lastName")
        super.init(row)
        
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "firstName": firstName,
            "lastName": lastName]
    }
    
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        id = rowID
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
