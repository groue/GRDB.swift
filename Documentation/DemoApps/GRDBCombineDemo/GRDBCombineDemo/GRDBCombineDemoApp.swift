import SwiftUI

@main
struct GRDBCombineDemoApp: App {
    var body: some Scene {
        WindowGroup {
            AppView().environment(\.appDatabase, .shared)
        }
    }
}
