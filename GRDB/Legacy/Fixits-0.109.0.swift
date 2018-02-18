extension FetchRequest {
    @available(*, unavailable, renamed:"asRequest(of:)")
    public func bound<T>(to type: T.Type) -> AnyFetchRequest<T> { preconditionFailure() }
}
