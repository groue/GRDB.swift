extension Request {
    @available(*, unavailable, renamed:"asRequest(of:)")
    public func bound<T>(to type: T.Type) -> AnyTypedRequest<T> { preconditionFailure() }
}
