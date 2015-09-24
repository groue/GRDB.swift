import GRDB

class PerformanceRecord : Record {
    var i0: Int64?
    var i1: Int64?
    var i2: Int64?
    var i3: Int64?
    var i4: Int64?
    var i5: Int64?
    var i6: Int64?
    var i7: Int64?
    var i8: Int64?
    var i9: Int64?
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    init(dictionary: [NSObject: AnyObject]) {
        super.init()
        if let n = dictionary["i0"] as? NSNumber { i0 = n.longLongValue }
        if let n = dictionary["i1"] as? NSNumber { i1 = n.longLongValue }
        if let n = dictionary["i2"] as? NSNumber { i2 = n.longLongValue }
        if let n = dictionary["i3"] as? NSNumber { i3 = n.longLongValue }
        if let n = dictionary["i4"] as? NSNumber { i4 = n.longLongValue }
        if let n = dictionary["i5"] as? NSNumber { i5 = n.longLongValue }
        if let n = dictionary["i6"] as? NSNumber { i6 = n.longLongValue }
        if let n = dictionary["i7"] as? NSNumber { i7 = n.longLongValue }
        if let n = dictionary["i8"] as? NSNumber { i8 = n.longLongValue }
        if let n = dictionary["i9"] as? NSNumber { i9 = n.longLongValue }
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
