extension Request {
    @available(*, unavailable, renamed:"fetching(_:)")
    public func bound<T>(to type: T.Type) -> AnyTypedRequest<T> { preconditionFailure() }
}
