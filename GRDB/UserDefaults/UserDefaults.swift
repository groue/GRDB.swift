import Foundation

/// Usage
///
///     let dbQueue = DatabaseQueue(...)
///     dbQueue.inDatabase { db in
///         let defaults = UserDefaults.inDatabase(db)
///         defaults.registerDefaults(["foo": "bar"])
///         defaults.setInteger(12, forKey: "baz")
///         defaults.integerForKey("bar")   // 12
///     }
public class UserDefaults {
    private weak var db: Database!
    private var registrationDictionary: [String: AnyObject] = [:]
    
    /// Returns the defaults for the database
    public static func inDatabase(db: Database) -> UserDefaults {
        registeredDefaults = registeredDefaults.filter { $0.db != nil }
        for defaults in registeredDefaults where defaults.db === db {
            return defaults
        }
        let defaults = UserDefaults(db: db)
        registeredDefaults.append(defaults)
        return defaults
    }
    
    private init(db: Database) {
        self.db = db
    }
    
    private static var registeredDefaults: [UserDefaults] = []
    
    private var needsTable: Bool = true
    private func createTableIfNeeded() {
        guard needsTable else { return }
        if !db.tableExists(UserDefaultsItemTableName) {
            try! db.execute("CREATE TABLE \(UserDefaultsItemTableName) (key TEXT NOT NULL PRIMARY KEY, value BLOB)")
        }
        needsTable = false
    }
    
    
    // MARK: - Registering Defaults
    
    public func registerDefaults(registrationDictionary: [String: AnyObject]) {
        for (key, value) in registrationDictionary {
            self.registrationDictionary[key] = value
        }
    }
    
    
    // MARK: - Setting Default Values
    
    public func removeObjectForKey(key: String) {
        createTableIfNeeded()
        try! UserDefaultsItem.fetchOne(db, key: key)?.delete(db)
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
        if let item = UserDefaultsItem.fetchOne(db, key: key) {
            return item.value
        }
        return registrationDictionary[key]
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
    var value: AnyObject?
}

extension UserDefaultsItem: RowConvertible {
    static func fromRow(row: Row) -> UserDefaultsItem {
        if let data = row.dataNoCopy(named: "value") {
            let value = try! NSPropertyListSerialization.propertyListWithData(data, options: .Immutable, format: nil)
            return UserDefaultsItem(key: row.value(named: "key"), value: value)
        } else {
            return UserDefaultsItem(key: row.value(named: "key"), value: nil)
        }
    }
}

extension UserDefaultsItem: Persistable {
    static func databaseTableName() -> String {
        return UserDefaultsItemTableName
    }
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        if let value = value {
            let data = NSPropertyListSerialization.dataFromPropertyList(value, format: .BinaryFormat_v1_0, errorDescription: nil)!
            return ["key": key, "value": data]
        } else {
            return ["key": key, "value": nil]
        }
    }
}

private let UserDefaultsItemTableName = "grdb_UserDefaults"
