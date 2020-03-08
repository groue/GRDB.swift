// Fixits for changes introduced by GRDB 5.0.0

#if os(iOS)
import UIKit
#endif

extension AnyFetchRequest {
    @available(*, unavailable, message: "Define your own FetchRequest type instead.")
    public init(_ prepare: @escaping (Database, _ singleResult: Bool) throws -> (SelectStatement, RowAdapter?))
    { preconditionFailure() }
}

extension DatabasePool {
    #if os(iOS)
    @available(*, unavailable, message: "Memory management is now enabled by default. This method does nothing.")
    public func setupMemoryManagement(in application: UIApplication) { preconditionFailure() }
    #endif
}

extension DatabaseQueue {
    #if os(iOS)
    @available(*, unavailable, message: "Memory management is now enabled by default. This method does nothing.")
    public func setupMemoryManagement(in application: UIApplication) { preconditionFailure() }
    #endif
}

extension FetchRequest {
    @available(*, unavailable, message: "Use makePreparedRequest(_:forSingleResult:) instead.")
    func prepare(_ db: Database, forSingleResult singleResult: Bool) throws -> (SelectStatement, RowAdapter?)
    { preconditionFailure() }
}

#if SQLITE_HAS_CODEC
extension Configuration {
    @available(*, unavailable, message: "Use Database.usePassphrase(_:) in Configuration.prepareDatabase instead.")
    public var passphrase: String? {
        get { preconditionFailure() }
        set { preconditionFailure() }
    }
}

extension DatabasePool {
    @available(*, unavailable, message: "Use Database.changePassphrase(_:) instead")
    public func change(passphrase: String) throws { preconditionFailure() }
}

extension DatabaseQueue {
    @available(*, unavailable, message: "Use Database.changePassphrase(_:) instead")
    public func change(passphrase: String) throws { preconditionFailure() }
}
#endif
