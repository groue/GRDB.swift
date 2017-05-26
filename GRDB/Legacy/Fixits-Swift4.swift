extension Row {
    @available(*, unavailable, message:"Use row[index] instead")
    public func value(atIndex index: Int) -> DatabaseValueConvertible? { preconditionFailure() }
    
    @available(*, unavailable, message:"Use row[index] instead")
    public func value<T>(atIndex index: Int) -> T? { preconditionFailure() }
    
    @available(*, unavailable, message:"Use row[index] instead")
    public func value<T>(atIndex index: Int) -> T { preconditionFailure() }
    
    @available(*, unavailable, message:"Use row[column] instead")
    public func value(named columnName: String) -> DatabaseValueConvertible? { preconditionFailure() }
    
    @available(*, unavailable, message:"Use row[column] instead")
    public func value<T>(named columnName: String) -> T? { preconditionFailure() }
    
    @available(*, unavailable, message:"Use row[column] instead")
    public func value<T>(named columnName: String) -> T { preconditionFailure() }
    
    @available(*, unavailable, message:"Use row[column] instead")
    public func value(_ column: Column) -> DatabaseValueConvertible? { preconditionFailure() }
    
    @available(*, unavailable, message:"Use row[column] instead")
    public func value<T>(_ column: Column) -> T? { preconditionFailure() }
    
    @available(*, unavailable, message:"Use row[column] instead")
    public func value<T>(_ column: Column) -> T { preconditionFailure() }
}
