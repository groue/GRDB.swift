import SwiftUI

/// The view that edits an existing player.
struct PlayerEditionView: View {
    @Environment(\.appDatabase) private var appDatabase
    @State var player: Player
    
    var body: some View {
        PlayerFormView(
            name: $player.name,
            score: Binding(
                get: { "\(player.score)" },
                set: { player.score = Int($0) ?? 0 }))
            .onDisappear {
                // save and ignore error
                try? appDatabase?.savePlayer(&player)
            }
    }
}

struct PlayerEditionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PlayerEditionView(player: Player.newRandom())
                .navigationBarTitle("Player Edition")
        }
    }
}
