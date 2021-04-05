import SwiftUI

struct PlayerList: View {
    /// Database access
    @Environment(\.appDatabase) private var appDatabase
    
    /// The players in the list
    var players: [Player]
    
    var body: some View {
        List {
            ForEach(players) { player in
                NavigationLink(destination: editionView(for: player)) {
                    PlayerRow(player: player).animation(nil)
                }
            }
            .onDelete(perform: { offsets in
                let playerIds = offsets.compactMap { players[$0].id }
                try? appDatabase?.deletePlayers(ids: playerIds)
            })
        }
        .animation(.default)
        .listStyle(PlainListStyle())
    }
    
    /// The view that edits a player in the list.
    private func editionView(for player: Player) -> some View {
        PlayerEditionView(player: player).navigationBarTitle(player.name)
    }
}

private struct PlayerRow: View {
    var player: Player
    
    var body: some View {
        HStack {
            Text(player.name)
            Spacer()
            Text("\(player.score) points").foregroundColor(.gray)
        }
    }
}

struct PlayerList_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PlayerList(players: [
                Player(id: 1, name: "Arthur", score: 100),
                Player(id: 2, name: "Barbara", score: 1000),
            ])
            .navigationTitle("Preview")
        }
    }
}
