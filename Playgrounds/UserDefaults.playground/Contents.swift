// To run this playground, select and build the GRDBOSX scheme.

import GRDB

/// UserDefaults is a class that behaves like NSUserDefaults.
///
/// Usage:
///
///     let dbQueue = DatabaseQueue(...)
///     dbQueue.inDatabase { db in
///         let defaults = UserDefaults.inDatabase(db)
///         defaults.setInteger(12, forKey: "bar")
///         defaults.integerForKey("bar") // 12
///     }
public class UserDefaults {
    private weak var db: Database!
    private var needsTable: Bool = true
    private static var registeredDefaults: [UserDefaults] = []
    
    /// Returns the defaults for the database
    public static func inDatabase(db: Database) -> UserDefaults {
        registeredDefaults = registeredDefaults.filter { $0.db != nil }
        for defaults in registeredDefaults where defaults.db === db { return defaults }
        let defaults = UserDefaults(db: db)
        registeredDefaults.append(defaults)
        return defaults
    }
    
    private init(db: Database) {
        self.db = db
    }
    
    private func createTableIfNeeded() {
        guard needsTable else { return }
        needsTable = false
        try! db.execute("CREATE TABLE IF NOT EXISTS \(UserDefaultsItemTableName) (key TEXT NOT NULL PRIMARY KEY, value BLOB)")
    }
    
    
    // MARK: - Setting Default Values
    
    public func removeObjectForKey(key: String) {
        createTableIfNeeded()
        try! db.execute("DELETE FROM \(UserDefaultsItemTableName) WHERE key = ?", arguments: [key])
    }
    
    public func setBool(value: Bool, forKey key: String) {
        setObject(NSNumber(bool: value), forKey: key)
    }
    
    public func setDouble(value: Double, forKey key: String) {
        setObject(NSNumber(double: value), forKey: key)
    }
    
    public func setFloat(value: Float, forKey key: String) {
        setObject(NSNumber(float: value), forKey: key)
    }
    
    public func setInteger(value: Int, forKey key: String) {
        setObject(NSNumber(integer: value), forKey: key)
    }
    
    public func setObject(value: AnyObject?, forKey key: String) {
        guard let value = value else {
            removeObjectForKey(key)
            return
        }
        
        createTableIfNeeded()
        if var item = UserDefaultsItem.fetchOne(db, key: key) {
            item.value = value
            try! item.update(db)
        } else {
            try! UserDefaultsItem(key: key, value: value).insert(db)
        }
    }
    
    public func setURL(value: NSURL?, forKey key: String) {
        setObject(value, forKey: key)
    }
    
    
    // MARK: - Reading Default Values
    
    public var dictionaryRepresentation: [String: AnyObject] {
        createTableIfNeeded()
        var dic: [String: AnyObject] = [:]
        for item in UserDefaultsItem.fetchAll(db) {
            dic[item.key] = item.value
        }
        return dic
    }
    
    public func arrayForKey(key: String) -> [AnyObject]? {
        return objectForKey(key) as? [AnyObject]
    }
    
    public func boolForKey(key: String) -> Bool {
        return (objectForKey(key) as? NSNumber)?.boolValue ?? false
    }
    
    public func dataForKey(key: String) -> NSData? {
        return objectForKey(key) as? NSData
    }
    
    public func dictionaryForKey(key: String) -> [String: AnyObject]? {
        return objectForKey(key) as? [String: AnyObject]
    }
    
    public func doubleForKey(key: String) -> Double {
        return (objectForKey(key) as? NSNumber)?.doubleValue ?? 0.0
    }
    
    public func floatForKey(key: String) -> Float {
        return (objectForKey(key) as? NSNumber)?.floatValue ?? 0.0
    }
    
    public func integerForKey(key: String) -> Int {
        return (objectForKey(key) as? NSNumber)?.integerValue ?? 0
    }
    
    public func objectForKey(key: String) -> AnyObject? {
        createTableIfNeeded()
        return UserDefaultsItem.fetchOne(db, key: key)?.value
    }
    
    public func stringArrayForKey(key: String) -> [String]? {
        return objectForKey(key) as? [String]
    }
    
    public func stringForKey(key: String) -> String? {
        return objectForKey(key) as? String
    }
    
    public func URLForKey(key: String) -> NSURL? {
        return objectForKey(key) as? NSURL
    }
}

private struct UserDefaultsItem {
    let key: String
    var value: AnyObject
}

extension UserDefaultsItem: RowConvertible {
    init(_ row: Row) {
        let data = row.dataNoCopy(named: "value")!
        let value = try! NSPropertyListSerialization.propertyListWithData(data, options: .Immutable, format: nil)
        self.key = row.value(named: "key")
        self.value = value
    }
}

extension UserDefaultsItem: Persistable {
    static func databaseTableName() -> String {
        return UserDefaultsItemTableName
    }
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        let data = try! NSPropertyListSerialization.dataWithPropertyList(value, format: .BinaryFormat_v1_0, options: 0)
        return ["key": key, "value": data]
    }
}

private let UserDefaultsItemTableName = "grdb_UserDefaults"


// ============================================================

let dbQueue = DatabaseQueue()
dbQueue.inDatabase { db in
    let defaults = UserDefaults.inDatabase(db)
    
    defaults.integerForKey("bar") // 0
    defaults.setInteger(12, forKey: "bar")
    defaults.integerForKey("bar") // 12
}
