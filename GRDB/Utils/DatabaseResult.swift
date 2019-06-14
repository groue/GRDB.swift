#if compiler(>=5.0)
typealias DatabaseResult<Success> = Swift.Result<Success, Error>
#else
enum DatabaseResult<Success> {
    case success(Success)
    case failure(Error)
    
    init(catching body: () throws -> Success) {
        do {
            self = try .success(body())
        } catch {
            self = .failure(error)
        }
    }
    
    func map<T>(_ transform: (Success) -> T) -> DatabaseResult<T> {
        switch self {
        case .success(let success):
            return .success(transform(success))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func get() throws -> Success {
        switch self {
        case .success(let success):
            return success
        case .failure(let error):
            throw error
        }
    }
}
#endif
