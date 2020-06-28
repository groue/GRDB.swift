/// Dependency Injection based on the "How to Control the World" article:
/// https://www.pointfree.co/blog/posts/21-how-to-control-the-world
struct World {
    /// The application database
    var database: () -> AppDatabase
}

/// The current world.
///
/// Its setup is done by `AppDelegate`, or tests.
var Current = World(database: { fatalError("Database is uninitialized") })
