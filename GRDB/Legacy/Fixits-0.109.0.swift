extension FetchRequest {
    @available(*, unavailable, message:"Use QueryInterfaceRequest.asRequest(of:), or AnyFetchRequest")
    public func bound<T>(to type: T.Type) -> AnyFetchRequest<T> { preconditionFailure() }
}
