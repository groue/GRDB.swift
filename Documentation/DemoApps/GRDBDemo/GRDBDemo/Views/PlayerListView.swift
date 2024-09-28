import SwiftUI

/// A view that displays a list of players.
struct PlayerListView: View {
    @Bindable var model: PlayerListModel
    
    var body: some View {
        List {
            ForEach(model.players, id: \.id) { player in
                NavigationLink {
                    PlayerEditionView(player: player)
                } label: {
                    PlayerRow(player: player)
                }
            }
            .onDelete { offsets in
                try? model.deletePlayers(at: offsets)
            }
        }
        .animation(.default, value: model.players)
        .listStyle(.plain)
        .navigationTitle("\(model.players.count) Players")
    }
}

struct PlayerRow: View {
    var player: Player
    
    var body: some View {
        HStack {
            Group {
                if player.name.isEmpty {
                    Text("Anonymous").italic()
                } else {
                    Text(player.name)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("\(player.score) points")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Previews

#Preview {
    struct Preview: View {
        @Environment(\.appDatabase) var appDatabase
        
        var body: some View {
            // This technique makes it possible to create an observable object
            // (PlayerListModel) from the SwiftUI environment.
            ContentView(appDatabase: appDatabase)
        }
    }
    
    struct ContentView: View {
        @State var model: PlayerListModel
        
        init(appDatabase: AppDatabase) {
            _model = State(initialValue: PlayerListModel(appDatabase: appDatabase))
        }

        var body: some View {
            NavigationStack {
                PlayerListView(model: model)
            }
            .onAppear { model.observePlayers() }
        }
    }
    
    return Preview().appDatabase(.random())
}
