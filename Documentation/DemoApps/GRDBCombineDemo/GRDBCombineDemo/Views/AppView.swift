import SwiftUI

/// The main application view
struct AppView: View {
    /// Database access
    @Environment(\.appDatabase) private var appDatabase
    
    /// The `players` property is kept up-to-date with the list of players.
    @Query(PlayerRequest(ordering: .byScore)) private var players: [Player]
    
    /// Tracks the presentation of the player creation sheet.
    @State private var newPlayerIsPresented = false

    // If you want to define the query on initialization, you will prefer:
    //
    // @Query<PlayerRequest> private var players: [Player]
    //
    // init(initialOrdering: PlayerRequest.Ordering) {
    //     _players = Query(PlayerRequest(ordering: initialOrdering))
    // }
    
    var body: some View {
        NavigationView {
            PlayerList(players: players)
                .navigationBarTitle(Text("\(players.count) Players"))
                .navigationBarItems(
                    leading: HStack {
                        EditButton()
                        newPlayerButton
                    },
                    trailing: ToggleOrderingButton(ordering: $players.ordering))
                .toolbar { toolbarContent }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button(
                action: { try? appDatabase?.deleteAllPlayers() },
                label: { Image(systemName: "trash").imageScale(.large) })
            Spacer()
            Button(
                action: { try? appDatabase?.refreshPlayers() },
                label: { Image(systemName: "arrow.clockwise").imageScale(.large) })
        }
    }
    
    /// The button that presents the player creation sheet.
    private var newPlayerButton: some View {
        Button(
            action: { newPlayerIsPresented = true },
            label: { Image(systemName: "plus") })
            .accessibility(label: Text("New Player"))
            .sheet(
                isPresented: $newPlayerIsPresented,
                content: {
                    PlayerCreationView(dismissAction: {
                        newPlayerIsPresented = false
                    })
                })
    }
}

private struct ToggleOrderingButton: View {
    @Binding var ordering: PlayerRequest.Ordering
    
    var body: some View {
        switch ordering {
        case .byName:
            Button(
                action: { ordering = .byScore },
                label: {
                    HStack {
                        Text("Name")
                        Image(systemName: "arrowtriangle.up.fill")
                    }
                })
        case .byScore:
            Button(
                action: { ordering = .byName },
                label: {
                    HStack {
                        Text("Score")
                        Image(systemName: "arrowtriangle.down.fill")
                    }
                })
        }
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview a database of random players
            AppView().environment(\.appDatabase, .random())

            // Preview an empty database
            AppView().environment(\.appDatabase, .empty())
        }
    }
}
