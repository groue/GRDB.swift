import GRDB

class PerformanceRecord : Record {
    var i0: Int?
    var i1: Int?
    var i2: Int?
    var i3: Int?
    var i4: Int?
    var i5: Int?
    var i6: Int?
    var i7: Int?
    var i8: Int?
    var i9: Int?
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    // Targets FMDB
    init(dictionary: [NSObject: AnyObject]) {
        super.init()
        if let n = dictionary["i0"] as? NSNumber { i0 = n.longValue }
        if let n = dictionary["i1"] as? NSNumber { i1 = n.longValue }
        if let n = dictionary["i2"] as? NSNumber { i2 = n.longValue }
        if let n = dictionary["i3"] as? NSNumber { i3 = n.longValue }
        if let n = dictionary["i4"] as? NSNumber { i4 = n.longValue }
        if let n = dictionary["i5"] as? NSNumber { i5 = n.longValue }
        if let n = dictionary["i6"] as? NSNumber { i6 = n.longValue }
        if let n = dictionary["i7"] as? NSNumber { i7 = n.longValue }
        if let n = dictionary["i8"] as? NSNumber { i8 = n.longValue }
        if let n = dictionary["i9"] as? NSNumber { i9 = n.longValue }
    }

    override func updateFromRow(row: Row) {
        if let dbv = row["i0"] { i0 = dbv.value() }
        if let dbv = row["i1"] { i1 = dbv.value() }
        if let dbv = row["i2"] { i2 = dbv.value() }
        if let dbv = row["i3"] { i3 = dbv.value() }
        if let dbv = row["i4"] { i4 = dbv.value() }
        if let dbv = row["i5"] { i5 = dbv.value() }
        if let dbv = row["i6"] { i6 = dbv.value() }
        if let dbv = row["i7"] { i7 = dbv.value() }
        if let dbv = row["i8"] { i8 = dbv.value() }
        if let dbv = row["i9"] { i9 = dbv.value() }
        super.updateFromRow(row)
    }
}
