import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private final class Person : RowConvertible, TableMapping {
    let id: Int64
    let name: String
    let birthCountryIsoCode: String?
    
    let birthCountry: Country?
    static let birthCountry = Relation(to: "countries", fromColumns: ["birthCountryIsoCode"])
    
    let ruledCountry: Country?
    static let ruledCountry = Relation(to: "countries", columns: ["leaderID"])
    
    static func databaseTableName() -> String {
        return "persons"
    }
    
    init(_ row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        birthCountryIsoCode = row.value(named: "birthCountryIsoCode")
        
        if let birthCountryRow = row.scoped(on: Person.birthCountry) {
            birthCountry = Country(birthCountryRow)
        } else {
            birthCountry = nil
        }
        
        if let ruledCountryRow = row.scoped(on: Person.ruledCountry) where ruledCountryRow.value(named: "isoCode") != nil {
            ruledCountry = Country(ruledCountryRow)
        } else {
            ruledCountry = nil
        }
    }
}

private final class Country : RowConvertible, TableMapping {
    let isoCode: String
    let name: String
    let leaderID: Int64?
    
    let leader: Person?
    static let leader = Relation(to: "persons", fromColumns: ["leaderID"])
    static let members = Relation(to: "persons", columns: ["birthCountryIsoCode"])
    
    static func databaseTableName() -> String {
        return "countries"
    }
    
    init(_ row: Row) {
        isoCode = row.value(named: "isoCode")
        name = row.value(named: "name")
        leaderID = row.value(named: "leaderID")
        
        if let leaderRow = row.scoped(on: Country.leader) {
            leader = Person(leaderRow)
        } else {
            leader = nil
        }
    }
}

private final class Node : RowConvertible, TableMapping, Persistable {
    var id: Int64?
    var name: String
    var leftId: Int64?
    var rightId: Int64?
    
    static let left = Relation(to: "nodes", fromColumns: ["leftId"])
    static let right = Relation(to: "nodes", fromColumns: ["rightId"])
    
    init(name: String) {
        self.name = name
    }
    
    static func databaseTableName() -> String {
        return "nodes"
    }
    
    required init(_ row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        leftId = row.value(named: "leftId")
        rightId = row.value(named: "rightId")
    }
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name, "leftId": leftId, "rightId": rightId]
    }
    
    func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        id = rowID
    }
}

class RelationTests: GRDBTestCase {
    override func setUpDatabase(dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .Integer).primaryKey()
                t.column("name", .Text).notNull()
                t.column("birthCountryIsoCode", .Text).notNull().references("countries", column: "isoCode")
            }
            try db.create(table: "countries") { t in
                t.column("isoCode", .Text).notNull().primaryKey()
                t.column("name", .Text).notNull()
                t.column("leaderId", .Integer).references("persons")
            }
            try db.create(table: "nodes") { t in
                t.column("id", .Integer).primaryKey()
                t.column("name", .Text).notNull()
                t.column("leftId", .Integer).references("nodes")
                t.column("rightId", .Integer).references("nodes")
            }
        }
    }
    
    func testExplicitRelationAlias() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO countries (isoCode, name) VALUES (?, ?)", arguments: ["FR", "France"])
                try db.execute("INSERT INTO persons (id, name, birthCountryIsoCode) VALUES (NULL, ?, ?)", arguments: ["Arthur", "FR"])
                return .Commit
            }
            
            let request = Person
                .include(Person.birthCountry.aliased("foo"))
                .filter(sql: "foo.isoCode = ?", arguments: ["FR"])
            XCTAssertEqual(
                sql(dbQueue, request),
                "SELECT \"persons\".*, \"foo\".* " +
                    "FROM \"persons\" " +
                    "LEFT JOIN \"countries\" \"foo\" ON (\"foo\".\"isoCode\" = \"persons\".\"birthCountryIsoCode\") " +
                "WHERE (foo.isoCode = 'FR')")
            
            dbQueue.inDatabase { db in
                let persons = request.fetchAll(db)
                XCTAssertEqual(persons.count, 1)
                
                XCTAssertEqual(persons[0].name, "Arthur")
                XCTAssertEqual(persons[0].birthCountry!.name, "France")
            }
            
            dbQueue.inDatabase { db in
                let request = Person
                    .include(Person.birthCountry.aliased("foo"))
                    .filter(sql: "foo.isoCode = ?", arguments: ["US"])
                let persons = request.fetchAll(db)
                
                XCTAssertEqual(persons.count, 0)
            }
        }
    }
    
    func testPersonToRuledCountryAndToBirthCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("PRAGMA defer_foreign_keys = ON")
                try db.execute("INSERT INTO persons (id, name, birthCountryIsoCode) VALUES (?, ?, ?)", arguments: [1, "Arthur", "FR"])
                try db.execute("INSERT INTO persons (id, name, birthCountryIsoCode) VALUES (?, ?, ?)", arguments: [2, "Barbara", "FR"])
                try db.execute("INSERT INTO persons (id, name, birthCountryIsoCode) VALUES (?, ?, ?)", arguments: [3, "John", "US"])
                try db.execute("INSERT INTO countries (isoCode, name, leaderID) VALUES (?, ?, ?)", arguments: ["FR", "France", 2])
                try db.execute("INSERT INTO countries (isoCode, name, leaderID) VALUES (?, ?, ?)", arguments: ["US", "United States", 3])
                return .Commit
            }
            
            let request = Person
                .include(Person.ruledCountry)
                .include(Person.birthCountry)
            
            XCTAssertEqual(
                sql(dbQueue, request),
                "SELECT \"persons\".*, \"countries0\".*, \"countries1\".* " +
                    "FROM \"persons\" " +
                    "LEFT JOIN \"countries\" \"countries0\" ON (\"countries0\".\"leaderID\" = \"persons\".\"id\") " +
                "LEFT JOIN \"countries\" \"countries1\" ON (\"countries1\".\"isoCode\" = \"persons\".\"birthCountryIsoCode\")")
            
            dbQueue.inDatabase { db in
                // TODO: sort persons using SQL
                let persons = request.fetchAll(db).sort { $0.id < $1.id }
                
                XCTAssertEqual(persons.count, 3)
                
                XCTAssertEqual(persons[0].name, "Arthur")
                XCTAssertNil(persons[0].ruledCountry)
                XCTAssertEqual(persons[0].birthCountry!.name, "France")
                
                XCTAssertEqual(persons[1].name, "Barbara")
                XCTAssertEqual(persons[1].ruledCountry!.name, "France")
                XCTAssertEqual(persons[1].birthCountry!.name, "France")
                
                XCTAssertEqual(persons[2].name, "John")
                XCTAssertEqual(persons[2].ruledCountry!.name, "United States")
                XCTAssertEqual(persons[2].birthCountry!.name, "United States")
            }
        }
    }
    
    func testPersonToRuledCountryAndToBirthCountryToLeaderToRuledCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("PRAGMA defer_foreign_keys = ON")
                try db.execute("INSERT INTO persons (id, name, birthCountryIsoCode) VALUES (?, ?, ?)", arguments: [1, "Arthur", "FR"])
                try db.execute("INSERT INTO persons (id, name, birthCountryIsoCode) VALUES (?, ?, ?)", arguments: [2, "Barbara", "FR"])
                try db.execute("INSERT INTO persons (id, name, birthCountryIsoCode) VALUES (?, ?, ?)", arguments: [3, "John", "US"])
                try db.execute("INSERT INTO countries (isoCode, name, leaderID) VALUES (?, ?, ?)", arguments: ["FR", "France", 2])
                try db.execute("INSERT INTO countries (isoCode, name, leaderID) VALUES (?, ?, ?)", arguments: ["US", "United States", 3])
                return .Commit
            }
            
            let request = Person
                .include(Person.ruledCountry
                    .include(Country.leader))
                .include(Person.birthCountry
                    .include(Country.leader
                        .include(Person.ruledCountry)))
            
            XCTAssertEqual(
                sql(dbQueue, request),
                "SELECT \"persons0\".*, \"countries0\".*, \"persons1\".*, \"countries1\".*, \"persons2\".*, \"countries2\".* " +
                    "FROM \"persons\" \"persons0\" " +
                    "LEFT JOIN \"countries\" \"countries0\" ON (\"countries0\".\"leaderID\" = \"persons0\".\"id\") " +
                    "LEFT JOIN \"persons\" \"persons1\" ON (\"persons1\".\"id\" = \"countries0\".\"leaderID\") " +
                    "LEFT JOIN \"countries\" \"countries1\" ON (\"countries1\".\"isoCode\" = \"persons0\".\"birthCountryIsoCode\") " +
                    "LEFT JOIN \"persons\" \"persons2\" ON (\"persons2\".\"id\" = \"countries1\".\"leaderID\") " +
                "LEFT JOIN \"countries\" \"countries2\" ON (\"countries2\".\"leaderID\" = \"persons2\".\"id\")")
            
            dbQueue.inDatabase { db in
                // TODO: sort persons using SQL
                let persons = request.fetchAll(db).sort { $0.id < $1.id }
                
                XCTAssertEqual(persons.count, 3)
                
                XCTAssertEqual(persons[0].name, "Arthur")
                XCTAssertNil(persons[0].ruledCountry)
                XCTAssertEqual(persons[0].birthCountry!.name, "France")
                XCTAssertEqual(persons[0].birthCountry!.leader!.name, "Barbara")
                XCTAssertEqual(persons[0].birthCountry!.leader!.ruledCountry!.name, "France")
                
                XCTAssertEqual(persons[1].name, "Barbara")
                XCTAssertEqual(persons[1].ruledCountry!.name, "France")
                XCTAssertEqual(persons[1].ruledCountry!.leader!.name, "Barbara")
                XCTAssertEqual(persons[1].birthCountry!.name, "France")
                XCTAssertEqual(persons[1].birthCountry!.leader!.name, "Barbara")
                XCTAssertEqual(persons[1].birthCountry!.leader!.ruledCountry!.name, "France")
                
                XCTAssertEqual(persons[2].name, "John")
                XCTAssertEqual(persons[2].ruledCountry!.name, "United States")
                XCTAssertEqual(persons[2].ruledCountry!.leader!.name, "John")
                XCTAssertEqual(persons[2].birthCountry!.name, "United States")
                XCTAssertEqual(persons[2].birthCountry!.leader!.name, "John")
                XCTAssertEqual(persons[2].birthCountry!.leader!.ruledCountry!.name, "United States")
            }
        }
    }
    
    func testDeeplyReusedRelation() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let root = Node(name: "root")
            let left = Node(name: "left")
            let right = Node(name: "right")
            let leftLeft = Node(name: "leftLeft")
            let leftRight = Node(name: "leftRight")
            let rightLeft = Node(name: "rightLeft")
            let rightRight = Node(name: "rightRight")
            let leftLeftLeft = Node(name: "leftLeftLeft")
            let rightRightRight = Node(name: "rightRightRight")
            try dbQueue.inDatabase { db in
                try leftLeftLeft.insert(db)
                leftLeft.leftId = leftLeftLeft.id
                try leftLeft.insert(db)
                try leftRight.insert(db)
                left.leftId = leftLeft.id
                left.rightId = leftRight.id
                try left.insert(db)
                
                try rightRightRight.insert(db)
                rightRight.rightId = rightRightRight.id
                try rightLeft.insert(db)
                try rightRight.insert(db)
                right.leftId = rightLeft.id
                right.rightId = rightRight.id
                try right.insert(db)
                
                root.leftId = left.id
                root.rightId = right.id
                try root.insert(db)
            }
            
            let request = Node.include(
                Node.left.include(Node.left, Node.right.aliased("foo")),
                Node.right.include(Node.left, Node.right))
                .order { [
                    $0["id"],
                    $0.scoped(on: Node.left)["id"],
                    $0.scoped(on: Node.right)["id"],
                    $0.scoped(on: Node.left, Node.left)["id"],
                    $0.scoped(on: Node.left, Node.right)["id"],
                    $0.scoped(on: Node.right, Node.left)["id"],
                    $0.scoped(on: Node.right, Node.right)["id"],
                    ] }
            
            dbQueue.inDatabase { db in
                let rows = Row.fetchAll(db, request)
                XCTAssertEqual(self.lastSQLQuery,
                    "SELECT \"nodes0\".*, \"nodes1\".*, \"nodes2\".*, \"foo\".*, \"nodes3\".*, \"nodes4\".*, \"nodes5\".* " +
                        "FROM \"nodes\" \"nodes0\" " +
                        "LEFT JOIN \"nodes\" \"nodes1\" ON (\"nodes1\".\"id\" = \"nodes0\".\"leftId\") " +
                        "LEFT JOIN \"nodes\" \"nodes2\" ON (\"nodes2\".\"id\" = \"nodes1\".\"leftId\") " +
                        "LEFT JOIN \"nodes\" \"foo\" ON (\"foo\".\"id\" = \"nodes1\".\"rightId\") " +
                        "LEFT JOIN \"nodes\" \"nodes3\" ON (\"nodes3\".\"id\" = \"nodes0\".\"rightId\") " +
                        "LEFT JOIN \"nodes\" \"nodes4\" ON (\"nodes4\".\"id\" = \"nodes3\".\"leftId\") " +
                        "LEFT JOIN \"nodes\" \"nodes5\" ON (\"nodes5\".\"id\" = \"nodes3\".\"rightId\") " +
                    "ORDER BY \"nodes0\".\"id\", \"nodes1\".\"id\", \"nodes3\".\"id\", \"nodes2\".\"id\", \"foo\".\"id\", \"nodes4\".\"id\", \"nodes5\".\"id\"")
                
                if let index = rows.indexOf({ $0.value(named:"id") == root.id }) {
                    let row = rows[index]
                    XCTAssertTrue(row.value(named:"id") == root.id)
                    XCTAssertTrue(row.value(named:"leftId") == root.leftId)
                    XCTAssertTrue(row.value(named:"rightId") == root.rightId)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"id") == left.id)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"leftId") == left.leftId)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"rightId") == left.rightId)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.left)!.value(named:"id") == leftLeft.id)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.left)!.value(named:"leftId") == leftLeftLeft.id)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.left)!.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.right)!.value(named:"id") == leftRight.id)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.right)!.value(named:"leftId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.right)!.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"id") == right.id)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"leftId") == right.leftId)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"rightId") == right.rightId)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.left)!.value(named:"id") == rightLeft.id)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.left)!.value(named:"leftId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.left)!.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.right)!.value(named:"id") == rightRight.id)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.right)!.value(named:"leftId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.right)!.value(named:"rightId") == rightRightRight.id)
                } else {
                    XCTFail()
                }
                if let index = rows.indexOf({ $0.value(named:"id") == left.id }) {
                    let row = rows[index]
                    XCTAssertTrue(row.value(named:"id") == left.id)
                    XCTAssertTrue(row.value(named:"leftId") == left.leftId)
                    XCTAssertTrue(row.value(named:"rightId") == left.rightId)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"id") == leftLeft.id)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"leftId") == leftLeftLeft.id)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.left)!.value(named:"id") == leftLeftLeft.id)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.left)!.value(named:"leftId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.left)!.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.right) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"id") == leftRight.id)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"leftId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.right) == nil)
                } else {
                    XCTFail()
                }
                if let index = rows.indexOf({ $0.value(named:"id") == leftLeft.id }) {
                    let row = rows[index]
                    XCTAssertTrue(row.value(named:"id") == leftLeft.id)
                    XCTAssertTrue(row.value(named:"leftId") == leftLeftLeft.id)
                    XCTAssertTrue(row.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"id") == leftLeftLeft.id)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"leftId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.right) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.right) == nil)
                } else {
                    XCTFail()
                }
                if let index = rows.indexOf({ $0.value(named:"id") == leftRight.id }) {
                    let row = rows[index]
                    XCTAssertTrue(row.value(named:"id") == leftRight.id)
                    XCTAssertTrue(row.value(named:"leftId") == nil)
                    XCTAssertTrue(row.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.right) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.right) == nil)
                } else {
                    XCTFail()
                }
                if let index = rows.indexOf({ $0.value(named:"id") == right.id }) {
                    let row = rows[index]
                    XCTAssertTrue(row.value(named:"id") == right.id)
                    XCTAssertTrue(row.value(named:"leftId") == right.leftId)
                    XCTAssertTrue(row.value(named:"rightId") == right.rightId)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"id") == rightLeft.id)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"leftId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left)!.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.right) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"id") == rightRight.id)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"leftId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"rightId") == rightRightRight.id)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.right)!.value(named:"id") == rightRightRight.id)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.right)!.value(named:"leftId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.right)!.value(named:"rightId") == nil)
                } else {
                    XCTFail()
                }
                if let index = rows.indexOf({ $0.value(named:"id") == rightLeft.id }) {
                    let row = rows[index]
                    XCTAssertTrue(row.value(named:"id") == rightLeft.id)
                    XCTAssertTrue(row.value(named:"leftId") == nil)
                    XCTAssertTrue(row.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.right) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.right) == nil)
                } else {
                    XCTFail()
                }
                if let index = rows.indexOf({ $0.value(named:"id") == rightRight.id }) {
                    let row = rows[index]
                    XCTAssertTrue(row.value(named:"id") == rightRight.id)
                    XCTAssertTrue(row.value(named:"leftId") == nil)
                    XCTAssertTrue(row.value(named:"rightId") == rightRightRight.id)
                    XCTAssertTrue(row.scoped(on: Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.left, Node.right) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"id") == rightRightRight.id)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"leftId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.right)!.value(named:"rightId") == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.left) == nil)
                    XCTAssertTrue(row.scoped(on: Node.right, Node.right) == nil)
                } else {
                    XCTFail()
                }
            }
        }
    }
    
    func testCountriesWithMemberCount() {
        assertNoError {
            // TODO: test other closures: order, having
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO countries (isoCode, name) VALUES (?, ?)", arguments: ["FR", "France"])
                try db.execute("INSERT INTO persons (id, name, birthCountryIsoCode) VALUES (NULL, ?, ?)", arguments: ["Arthur", "FR"])
                return .Commit
            }
            
            let request = Country
                .include(Country.members.select { count($0["id"]).aliased("memberCount") })
                .group { $0["isoCode"] }
            XCTAssertEqual(
                sql(dbQueue, request),
                "SELECT \"countries\".*, COUNT(\"persons\".\"id\") AS \"memberCount\" FROM \"countries\" LEFT JOIN \"persons\" ON (\"persons\".\"birthCountryIsoCode\" = \"countries\".\"isoCode\") GROUP BY \"countries\".\"isoCode\"")
            
            dbQueue.inDatabase { db in
                let row = Row.fetchOne(db, request)!
                XCTAssertEqual(row.value(named: "isoCode") as String, "FR")
                XCTAssertEqual(row.value(named: "name") as String, "France")
                XCTAssertEqual(row.value(named: "memberCount") as Int, 1)
                XCTAssertEqual(row.scoped(on: Country.members)!.value(named: "memberCount") as Int, 1)
            }
        }
    }
    
    func testCountAnnotation() {
        assertNoError {
            // TODO: test other closures: order, having
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("INSERT INTO countries (isoCode, name) VALUES (?, ?)", arguments: ["FR", "France"])
                try db.execute("INSERT INTO persons (id, name, birthCountryIsoCode) VALUES (NULL, ?, ?)", arguments: ["Arthur", "FR"])
                return .Commit
            }
            
            // TODO: get inspiration from https://docs.djangoproject.com/en/1.10/topics/db/aggregation/
            //
            //     Publisher.objects.annotate(num_books=Count('book'))
            //     Publisher.objects.annotate(num_books=Count('book')).order_by('-num_books')[:5]
            //
            // Check http://stackoverflow.com/questions/3141463/inner-join-with-count-on-three-tables
            // for a use case that mixes count(distinct) and count()
            let request = Country.all().annotate(count(Country.members))
            XCTAssertEqual(
                sql(dbQueue, request),
                "SELECT \"countries\".*, COUNT(\"persons\".\"id\") AS \"personsCount\" FROM \"countries\" LEFT JOIN \"persons\" ON (\"persons\".\"birthCountryIsoCode\" = \"countries\".\"isoCode\") GROUP BY \"countries\".\"isoCode\"")
            
            dbQueue.inDatabase { db in
                let row = Row.fetchOne(db, request)!
                XCTAssertEqual(row.value(named: "isoCode") as String, "FR")
                XCTAssertEqual(row.value(named: "name") as String, "France")
                XCTAssertEqual(row.value(named: "personsCount") as Int, 1)
                XCTAssertEqual(row.scoped(on: Country.members)!.value(named: "personsCount") as Int, 1)
            }
        }
    }
}
