import GRDB
import SQLite
import RealmSwift


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


// MARK:- GRDB

class Item : Record {
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
        i0 = row.value(named: "i0")
        i1 = row.value(named: "i1")
        i2 = row.value(named: "i2")
        i3 = row.value(named: "i3")
        i4 = row.value(named: "i4")
        i5 = row.value(named: "i5")
        i6 = row.value(named: "i6")
        i7 = row.value(named: "i7")
        i8 = row.value(named: "i8")
        i9 = row.value(named: "i9")
        super.init(row: row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["i0": i0, "i1": i1, "i2": i2, "i3": i3, "i4": i4, "i5": i5, "i6": i6, "i7": i7, "i8": i8, "i9": i9]
    }
}


// MARK:- FMDB

extension Item {
    
    convenience init(dictionary: [NSObject: AnyObject]) {
        self.init(
            i0: (dictionary["i0"] as! NSNumber).longValue,
            i1: (dictionary["i1"] as! NSNumber).longValue,
            i2: (dictionary["i2"] as! NSNumber).longValue,
            i3: (dictionary["i3"] as! NSNumber).longValue,
            i4: (dictionary["i4"] as! NSNumber).longValue,
            i5: (dictionary["i5"] as! NSNumber).longValue,
            i6: (dictionary["i6"] as! NSNumber).longValue,
            i7: (dictionary["i7"] as! NSNumber).longValue,
            i8: (dictionary["i8"] as! NSNumber).longValue,
            i9: (dictionary["i9"] as! NSNumber).longValue)
    }
    
}


// MARK: - Realm

class RealmItem : RealmSwift.Object {
    dynamic var i0: Int = 0
    dynamic var i1: Int = 0
    dynamic var i2: Int = 0
    dynamic var i3: Int = 0
    dynamic var i4: Int = 0
    dynamic var i5: Int = 0
    dynamic var i6: Int = 0
    dynamic var i7: Int = 0
    dynamic var i8: Int = 0
    dynamic var i9: Int = 0

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
