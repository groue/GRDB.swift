import SwiftUI

@main
struct GRDBCombineDemoApp: App {
    let appDatabase = AppDatabase.shared

    var body: some Scene {
        WindowGroup {
            PlayerList(viewModel: PlayerListViewModel(database: appDatabase))
        }
    }
}
