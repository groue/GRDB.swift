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
    public static func inDatabase(_ db: Database) -> UserDefaults {
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
    
    public func removeObject(forKey key: String) {
        createTableIfNeeded()
        try! db.execute("DELETE FROM \(UserDefaultsItemTableName) WHERE key = ?", arguments: [key])
    }
    
    public func setBool(_ value: Bool, forKey key: String) {
        setObject(NSNumber(value: value), forKey: key)
    }
    
    public func setDouble(_ value: Double, forKey key: String) {
        setObject(NSNumber(value: value), forKey: key)
    }
    
    public func setFloat(_ value: Float, forKey key: String) {
        setObject(NSNumber(value: value), forKey: key)
    }
    
    public func setInteger(_ value: Int, forKey key: String) {
        setObject(NSNumber(value: value), forKey: key)
    }
    
    public func setObject(_ value: AnyObject?, forKey key: String) {
        guard let value = value else {
            removeObject(forKey: key)
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
    
    public func setURL(_ value: NSURL?, forKey key: String) {
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
    
    public func array(forKey key: String) -> [AnyObject]? {
        return object(forKey: key) as? [AnyObject]
    }
    
    public func bool(forKey key: String) -> Bool {
        return (object(forKey: key) as? NSNumber)?.boolValue ?? false
    }
    
    public func data(forKey key: String) -> Data? {
        return object(forKey: key) as? Data
    }
    
    public func dictionary(forKey key: String) -> [String: AnyObject]? {
        return object(forKey: key) as? [String: AnyObject]
    }
    
    public func double(forKey key: String) -> Double {
        return (object(forKey: key) as? NSNumber)?.doubleValue ?? 0.0
    }
    
    public func float(forKey key: String) -> Float {
        return (object(forKey: key) as? NSNumber)?.floatValue ?? 0.0
    }
    
    public func integer(forKey key: String) -> Int {
        return (object(forKey: key) as? NSNumber)?.intValue ?? 0
    }
    
    public func object(forKey key: String) -> AnyObject? {
        createTableIfNeeded()
        return UserDefaultsItem.fetchOne(db, key: key)?.value
    }
    
    public func stringArray(forKey key: String) -> [String]? {
        return object(forKey: key) as? [String]
    }
    
    public func string(forKey key: String) -> String? {
        return object(forKey: key) as? String
    }
    
    public func URL(forKey key: String) -> NSURL? {
        return object(forKey: key) as? NSURL
    }
}

private struct UserDefaultsItem {
    let key: String
    var value: AnyObject
}

extension UserDefaultsItem: RowConvertible {
    init(row: Row) {
        let data = row.dataNoCopy(named: "value")!
        let value = try! PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        self.key = row.value(named: "key")
        self.value = value
    }
}

extension UserDefaultsItem: Persistable {
    static func databaseTableName() -> String {
        return UserDefaultsItemTableName
    }
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        let data = try! PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
        return ["key": key, "value": data]
    }
}

private let UserDefaultsItemTableName = "grdb_UserDefaults"


// ============================================================

let dbQueue = DatabaseQueue()
dbQueue.inDatabase { db in
    let defaults = UserDefaults.inDatabase(db)
    
    defaults.integer(forKey: "bar") // 0
    defaults.setInteger(12, forKey: "bar")
    defaults.integer(forKey: "bar") // 12
}
