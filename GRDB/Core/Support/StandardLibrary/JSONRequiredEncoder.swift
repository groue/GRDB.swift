struct JSONRequiredError: Error { }

/// The encoder that always ends up with a JSONRequiredError
struct JSONRequiredEncoder: Encoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { Record.databaseEncodingUserInfo }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let container = KeyedContainer<Key>(codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer { self }
    
    func singleValueContainer() -> SingleValueEncodingContainer { self }
    
    struct KeyedContainer<KeyType: CodingKey>: KeyedEncodingContainerProtocol {
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any] { Record.databaseEncodingUserInfo }
        
        // swiftlint:disable comma
        func encodeNil(forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Bool,   forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Int,    forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Int8,   forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Int16,  forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Int32,  forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Int64,  forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: UInt,   forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: UInt8,  forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: UInt16, forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: UInt32, forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: UInt64, forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Float,  forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: Double, forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode(_ value: String, forKey key: KeyType) throws { throw JSONRequiredError() }
        func encode<T>(_ value: T, forKey key: KeyType) throws where T: Encodable { throw JSONRequiredError() }
        // swiftlint:enable comma
        
        func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type,
            forKey key: KeyType)
        -> KeyedEncodingContainer<NestedKey>
        where NestedKey: CodingKey
        {
            let container = KeyedContainer<NestedKey>(codingPath: codingPath + [key])
            return KeyedEncodingContainer(container)
        }
        
        func nestedUnkeyedContainer(forKey key: KeyType) -> UnkeyedEncodingContainer {
            JSONRequiredEncoder(codingPath: codingPath)
        }
        
        func superEncoder() -> Encoder {
            JSONRequiredEncoder(codingPath: codingPath)
        }
        
        func superEncoder(forKey key: KeyType) -> Encoder {
            JSONRequiredEncoder(codingPath: codingPath)
        }
    }
}

extension JSONRequiredEncoder: SingleValueEncodingContainer {
    func encodeNil() throws { throw JSONRequiredError() }
    func encode(_ value: Bool  ) throws { throw JSONRequiredError() }
    func encode(_ value: Int   ) throws { throw JSONRequiredError() }
    func encode(_ value: Int8  ) throws { throw JSONRequiredError() }
    func encode(_ value: Int16 ) throws { throw JSONRequiredError() }
    func encode(_ value: Int32 ) throws { throw JSONRequiredError() }
    func encode(_ value: Int64 ) throws { throw JSONRequiredError() }
    func encode(_ value: UInt  ) throws { throw JSONRequiredError() }
    func encode(_ value: UInt8 ) throws { throw JSONRequiredError() }
    func encode(_ value: UInt16) throws { throw JSONRequiredError() }
    func encode(_ value: UInt32) throws { throw JSONRequiredError() }
    func encode(_ value: UInt64) throws { throw JSONRequiredError() }
    func encode(_ value: Float ) throws { throw JSONRequiredError() }
    func encode(_ value: Double) throws { throw JSONRequiredError() }
    func encode(_ value: String) throws { throw JSONRequiredError() }
    func encode<T>(_ value: T) throws where T: Encodable { throw JSONRequiredError() }
}

extension JSONRequiredEncoder: UnkeyedEncodingContainer {
    var count: Int { 0 }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
    -> KeyedEncodingContainer<NestedKey>
    where NestedKey: CodingKey
    {
        let container = KeyedContainer<NestedKey>(codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }
    
    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer { self }
    
    mutating func superEncoder() -> Encoder { self }
}
