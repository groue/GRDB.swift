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
    
    
    // Record
    
    required init(_ row: Row) {
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
        super.init(row)
    }
    
    // FMDB
    
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
}

class PerformanceObjCRecord : NSObject {
    var i0: NSNumber?
    var i1: NSNumber?
    var i2: NSNumber?
    var i3: NSNumber?
    var i4: NSNumber?
    var i5: NSNumber?
    var i6: NSNumber?
    var i7: NSNumber?
    var i8: NSNumber?
    var i9: NSNumber?
    
    init(dictionary: NSDictionary) {
        super.init()
        for (key, value) in dictionary {
            setValue(value, forKey: key as! String)
        }
    }
}

