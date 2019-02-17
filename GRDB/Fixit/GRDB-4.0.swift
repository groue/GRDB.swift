// Fixits for changes introduced by GRDB 4.0.0

extension Cursor {
    @available(*, unavailable, renamed: "compactMap")
    public func flatMap<ElementOfResult>(_ transform: @escaping (Element) throws -> ElementOfResult?) -> MapCursor<FilterCursor<MapCursor<Self, ElementOfResult?>>, ElementOfResult> { preconditionFailure() }
}

extension DatabaseWriter {
    @available(*, unavailable, message: "Use concurrentRead instead")
    public func readFromCurrentState(_ block: @escaping (Database) -> Void) throws { preconditionFailure() }
}
