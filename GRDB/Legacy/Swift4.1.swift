// Compatibility layer for Swift < 4.1

#if swift(>=4.1)
#else
extension Sequence {
    func compactMap<ElementOfResult>(_ transform: (Self.Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
        return try flatMap(transform)
    }
}

extension UnsafeMutableRawBufferPointer {
    func copyMemory<C>(from source: C) where C : Collection, C.Element == UInt8 {
        copyBytes(from: source)
    }
}
#endif
