import SwiftUI

@main
struct GRDBAsyncDemoApp: App {
    var body: some Scene {
        WindowGroup {
            AppView().environment(\.appDatabase, .shared)
        }
    }
}
