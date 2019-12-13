import GRDB
#if GRDB_COMPARE
import SQLite
import RealmSwift
#endif


// MARK:- GRDB

struct ItemStruct : FetchableRecord, PersistableRecord {
    var i0: Int
    var i1: Int
    var i2: Int
    var i3: Int
    var i4: Int
    var i5: Int
    var i6: Int
    var i7: Int
    var i8: Int
    var i9: Int
    
    init(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int, i9: Int) {
        self.i0 = i0
        self.i1 = i1
        self.i2 = i2
        self.i3 = i3
        self.i4 = i4
        self.i5 = i5
        self.i6 = i6
        self.i7 = i7
        self.i8 = i8
        self.i9 = i9
    }
    
    init(row: GRDB.Row) {
        i0 = row["i0"]
        i1 = row["i1"]
        i2 = row["i2"]
        i3 = row["i3"]
        i4 = row["i4"]
        i5 = row["i5"]
        i6 = row["i6"]
        i7 = row["i7"]
        i8 = row["i8"]
        i9 = row["i9"]
    }
    
    static let databaseTableName = "items"
    
    func encode(to container: inout PersistenceContainer) {
        container["i0"] = i0
        container["i1"] = i1
        container["i2"] = i2
        container["i3"] = i3
        container["i4"] = i4
        container["i5"] = i5
        container["i6"] = i6
        container["i7"] = i7
        container["i8"] = i8
        container["i9"] = i9
    }

    init(dictionary: [AnyHashable: Any]) {
        i0 = dictionary["i0"] as! Int
        i1 = dictionary["i1"] as! Int
        i2 = dictionary["i2"] as! Int
        i3 = dictionary["i3"] as! Int
        i4 = dictionary["i4"] as! Int
        i5 = dictionary["i5"] as! Int
        i6 = dictionary["i6"] as! Int
        i7 = dictionary["i7"] as! Int
        i8 = dictionary["i8"] as! Int
        i9 = dictionary["i9"] as! Int
    }
}

struct ItemCodable : Codable, FetchableRecord, PersistableRecord {
    var i0: Int
    var i1: Int
    var i2: Int
    var i3: Int
    var i4: Int
    var i5: Int
    var i6: Int
    var i7: Int
    var i8: Int
    var i9: Int
    
    static let databaseTableName = "items"
}

class ItemClass : Record {
    var i0: Int
    var i1: Int
    var i2: Int
    var i3: Int
    var i4: Int
    var i5: Int
    var i6: Int
    var i7: Int
    var i8: Int
    var i9: Int
    
    init(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int, i9: Int) {
        self.i0 = i0
        self.i1 = i1
        self.i2 = i2
        self.i3 = i3
        self.i4 = i4
        self.i5 = i5
        self.i6 = i6
        self.i7 = i7
        self.i8 = i8
        self.i9 = i9
        super.init()
    }
    
    override class var databaseTableName: String {
        return "items"
    }
    
    required init(row: GRDB.Row) {
        i0 = row["i0"]
        i1 = row["i1"]
        i2 = row["i2"]
        i3 = row["i3"]
        i4 = row["i4"]
        i5 = row["i5"]
        i6 = row["i6"]
        i7 = row["i7"]
        i8 = row["i8"]
        i9 = row["i9"]
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["i0"] = i0
        container["i1"] = i1
        container["i2"] = i2
        container["i3"] = i3
        container["i4"] = i4
        container["i5"] = i5
        container["i6"] = i6
        container["i7"] = i7
        container["i8"] = i8
        container["i9"] = i9
    }
}

#if GRDB_COMPARE

// MARK:- SQLite

let itemsTable = Table("items")
let i0Column = Expression<Int>("i0")
let i1Column = Expression<Int>("i1")
let i2Column = Expression<Int>("i2")
let i3Column = Expression<Int>("i3")
let i4Column = Expression<Int>("i4")
let i5Column = Expression<Int>("i5")
let i6Column = Expression<Int>("i6")
let i7Column = Expression<Int>("i7")
let i8Column = Expression<Int>("i8")
let i9Column = Expression<Int>("i9")


// MARK:- FMDB

extension ItemClass {
    
    convenience init(dictionary: [AnyHashable: Any]) {
        self.init(
            i0: dictionary["i0"] as! Int,
            i1: dictionary["i1"] as! Int,
            i2: dictionary["i2"] as! Int,
            i3: dictionary["i3"] as! Int,
            i4: dictionary["i4"] as! Int,
            i5: dictionary["i5"] as! Int,
            i6: dictionary["i6"] as! Int,
            i7: dictionary["i7"] as! Int,
            i8: dictionary["i8"] as! Int,
            i9: dictionary["i9"] as! Int)
    }
    
}


// MARK: - Realm

class RealmItem : RealmSwift.Object {
    @objc dynamic var i0: Int = 0
    @objc dynamic var i1: Int = 0
    @objc dynamic var i2: Int = 0
    @objc dynamic var i3: Int = 0
    @objc dynamic var i4: Int = 0
    @objc dynamic var i5: Int = 0
    @objc dynamic var i6: Int = 0
    @objc dynamic var i7: Int = 0
    @objc dynamic var i8: Int = 0
    @objc dynamic var i9: Int = 0

    convenience init(i0: Int, i1: Int, i2: Int, i3: Int, i4: Int, i5: Int, i6: Int, i7: Int, i8: Int, i9: Int) {
        self.init()
        self.i0 = i0
        self.i1 = i1
        self.i2 = i2
        self.i3 = i3
        self.i4 = i4
        self.i5 = i5
        self.i6 = i6
        self.i7 = i7
        self.i8 = i8
        self.i9 = i9
    }
}

#endif
