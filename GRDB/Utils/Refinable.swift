/// A marker protocol for refinable types.
///
/// For example:
///
///     struct Player {
///         var name: String
///         var score: Int
///     }
///
///     extension Player: Refinable { }
///
///     let player = Player(name: "Arthur", score: 1000)
///     player.with { $0.score = 100 }   // Player(name: "Arthur", score: 100)
///     player.with(\.score, 100)        // Player(name: "Arthur", score: 100)
///     player.map(\.score) { $0 + 100 } // Player(name: "Arthur", score: 1100)
protocol Refinable { }

extension Refinable {
    
    /// Returns self modified with the *update* function.
    ///
    /// For example:
    ///
    ///     let player = Player(name: "Arthur", score: 1000)
    ///     let newPlayer = player.with {
    ///         $0.score = 100
    ///     }
    ///     newPlayer.name  // "Arthur"
    ///     newPlayer.score // 100
    @inline(__always)
    func with(_ update: (inout Self) throws -> Void) rethrows -> Self {
        var result = self
        try update(&result)
        return result
    }
    
    /// Returns self with the given value set on the given key path.
    ///
    /// For example:
    ///
    ///     let player = Player(name: "Arthur", score: 1000)
    ///     let newPlayer = player.with(\.score, 1100)
    ///     newPlayer.name  // "Arthur"
    ///     newPlayer.score // 1100
    @inline(__always)
    func with<T>(_ keyPath: WritableKeyPath<Self, T>, _ value: T) -> Self {
        with { $0[keyPath: keyPath] = value }
    }
    
    /// Returns self with the given transform function applied to the given key path.
    ///
    /// For example:
    ///
    ///     let player = Player(name: "Arthur", score: 1000)
    ///     let newPlayer = player.map(\.score) { $0 + 100 }
    ///     newPlayer.name  // "Arthur"
    ///     newPlayer.score // 1100
    @inline(__always)
    func map<T>(_ keyPath: WritableKeyPath<Self, T>, _ transform: (T) throws -> T) rethrows -> Self {
        try with {
            $0[keyPath: keyPath] = try transform($0[keyPath: keyPath])
        }
    }
    
    /// Returns self with the given update function applied to the given key path.
    ///
    /// For example:
    ///
    ///     let player = Player(name: "Arthur", scores: [100, 10])
    ///     let newPlayer = player.mapInto(\.scores) { $0.append(1000) }
    ///     newPlayer.name   // "Arthur"
    ///     newPlayer.scores // [100, 10, 1000]
    @inline(__always)
    func mapInto<T>(_ keyPath: WritableKeyPath<Self, T>, _ update: (inout T) throws -> Void) rethrows -> Self {
        try with {
            try update(&$0[keyPath: keyPath])
        }
    }
}

extension Array: Refinable where Element: Refinable { }
