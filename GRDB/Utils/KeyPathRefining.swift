/// A marker protocol for types that allow keyPath refining.
///
/// For example:
///
///     struct Player: KeyPathRefining {
///         var name: String
///         var score: Int
///     }
///
///     let player = Player(name: "Arthur", score: 1000)
///     player.with(\.score, 100)           // Player(name: "Arthur", score: 100)
///     player.map(\.score, { $0 + 100 })   // Player(name: "Arthur", score: 1100)
protocol KeyPathRefining { }

extension KeyPathRefining {
    @inlinable
    func with<T>(_ keyPath: WritableKeyPath<Self, T>, _ value: T) -> Self {
        var result = self
        result[keyPath: keyPath] = value
        return result
    }
    
    #if compiler(>=5.1)
    #else
    @inlinable
    func with<T>(_ keyPath: WritableKeyPath<Self, T?>, _ value: T) -> Self {
        var result = self
        result[keyPath: keyPath] = value
        return result
    }
    #endif
    
    @inlinable
    func map<T>(_ keyPath: WritableKeyPath<Self, T>, _ transform: (T) throws -> T) rethrows -> Self {
        var result = self
        result[keyPath: keyPath] = try transform(result[keyPath: keyPath])
        return result
    }
    
    @inlinable
    func mapInto<T>(_ keyPath: WritableKeyPath<Self, T>, _ update: (inout T) throws -> Void) rethrows -> Self {
        var result = self
        try update(&result[keyPath: keyPath])
        return result
    }
}

extension Array: KeyPathRefining where Element: KeyPathRefining { }
