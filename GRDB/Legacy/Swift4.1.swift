// Compatibility layer for Swift < 4.1

#if !swift(>=4.1)
extension Sequence {
    // From future import SE-0187
    func compactMap<ElementOfResult>(_ transform: (Self.Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
        return try flatMap(transform)
    }
}

extension UnsafeMutablePointer {
    // From future import SE-0184
    func deallocate() {
        deallocate(capacity: 0)
    }
}

extension UnsafeMutableRawBufferPointer {
    // From future import SE-0184
    func copyMemory<C>(from source: C) where C : Collection, C.Element == UInt8 {
        copyBytes(from: source)
    }
}
#endif
