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
///
///     // Player(name: "Arthur", score: 100)
///     let newPlayer = player.with {
///         $0.score = 100
///     }
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
    func with(_ update: (inout Self) throws -> Void) rethrows -> Self {
        var result = self
        try update(&result)
        return result
    }
}
