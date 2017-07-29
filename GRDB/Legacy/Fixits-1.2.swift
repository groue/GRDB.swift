extension Row {
    @available(*, unavailable, message:"use subscript instead: row[index]")
    public func value(atIndex index: Int) -> DatabaseValueConvertible? { preconditionFailure() }
    
    @available(*, unavailable, message:"use subscript instead: row[index]")
    public func value<Value: DatabaseValueConvertible>(atIndex index: Int) -> Value? { preconditionFailure() }
    
    @available(*, unavailable, message:"use subscript instead: row[index]")
    public func value<Value: DatabaseValueConvertible>(atIndex index: Int) -> Value { preconditionFailure() }

    @available(*, unavailable, message:"use subscript instead: row[column]")
    public func value(named name: String) -> DatabaseValueConvertible? { preconditionFailure() }
    
    @available(*, unavailable, message:"use subscript instead: row[column]")
    public func value<Value: DatabaseValueConvertible>(named name: String) -> Value? { preconditionFailure() }
    
    @available(*, unavailable, message:"use subscript instead: row[column]")
    public func value<Value: DatabaseValueConvertible>(named name: String) -> Value { preconditionFailure() }

    @available(*, unavailable, message:"use subscript instead: row[column]")
    public func value(_ column: Column) -> DatabaseValueConvertible? { preconditionFailure() }
    
    @available(*, unavailable, message:"use subscript instead: row[column]")
    public func value<Value: DatabaseValueConvertible>(_ column: Column) -> Value? { preconditionFailure() }
    
    @available(*, unavailable, message:"use subscript instead: row[column]")
    public func value<Value: DatabaseValueConvertible>(_ column: Column) -> Value { preconditionFailure() }
}
