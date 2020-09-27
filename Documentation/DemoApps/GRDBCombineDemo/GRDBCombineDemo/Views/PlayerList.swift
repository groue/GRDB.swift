import SwiftUI

/// The list of players
struct PlayerList: View {
    /// Manages the list of players
    @ObservedObject var viewModel: PlayerListViewModel
    
    /// Controls the presentation of the player creation sheet.
    @State private var newPlayerIsPresented = false
    
    var body: some View {
        NavigationView {
            VStack {
                playerList
                toolbar
            }
            .navigationBarTitle(Text("\(viewModel.playerList.players.count) Players"))
            .navigationBarItems(
                leading: HStack {
                    EditButton()
                    newPlayerButton
                },
                trailing: toggleOrderingButton)
        }
    }
    
    private var playerList: some View {
        List {
            ForEach(viewModel.playerList.players) { player in
                NavigationLink(destination: self.editionView(for: player)) {
                    PlayerRow(player: player)
                        .animation(nil)
                }
            }
            .onDelete(perform: { offsets in
                self.viewModel.deletePlayers(atOffsets: offsets)
            })
        }
        .listStyle(PlainListStyle())
        .animation(viewModel.playerList.animatedChanges ? .default : nil)
    }
    
    private var toolbar: some View {
        HStack {
            Button(
                action: viewModel.deleteAllPlayers,
                label: { Image(systemName: "trash").imageScale(.large) })
            Spacer()
            Button(
                action: viewModel.refreshPlayers,
                label: { Image(systemName: "arrow.clockwise").imageScale(.large) })
            Spacer()
            Button(
                action: viewModel.stressTest,
                label: { Image(systemName: "tornado").imageScale(.large) })
        }
        
        .padding()
    }
    
    /// The button that toggles between name/score ordering.
    private var toggleOrderingButton: some View {
        switch viewModel.ordering {
        case .byName:
            return Button(action: viewModel.toggleOrdering, label: {
                HStack {
                    Text("Name")
                    Image(systemName: "arrowtriangle.up.fill")
                        .imageScale(.small)
                }
            })
        case .byScore:
            return Button(action: viewModel.toggleOrdering, label: {
                HStack {
                    Text("Score")
                    Image(systemName: "arrowtriangle.down.fill")
                        .imageScale(.small)
                }
            })
        }
    }
    
    /// The view that edits a player in the list.
    private func editionView(for player: Player) -> some View {
        PlayerEditionView(
            viewModel: viewModel.formViewModel(for: player))
            .navigationBarTitle(player.name)
    }
    
    /// The button that presents the player creation sheet.
    private var newPlayerButton: some View {
        Button(
            action: {
                // Make sure we do not edit a previously created player.
                self.viewModel.newPlayerViewModel.editNewPlayer()
                self.newPlayerIsPresented = true
            },
            label: { Image(systemName: "plus").imageScale(.large) })
            .sheet(
                isPresented: $newPlayerIsPresented,
                content: { self.newPlayerCreationSheet })
    }
    
    /// The player creation sheet.
    private var newPlayerCreationSheet: some View {
        PlayerCreationSheet(
            viewModel: self.viewModel.newPlayerViewModel,
            dismissAction: {
                self.newPlayerIsPresented = false
            })
    }
}

struct PlayerRow: View {
    var player: Player
    
    var body: some View {
        HStack {
            Text(player.name)
            Spacer()
            Text("\(player.score) points").foregroundColor(.gray)
        }
    }
}

struct PlayerListView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = PlayerListViewModel(database: .random())
        return PlayerList(viewModel: viewModel)
    }
}
