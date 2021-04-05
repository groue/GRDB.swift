#if GRDB_COMPARE
import SQLite
import RealmSwift
#endif


#if GRDB_COMPARE

// MARK:- SQLite

let itemTable = Table("item")
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


// MARK: - Realm

class RealmItem: RealmSwift.Object {
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
