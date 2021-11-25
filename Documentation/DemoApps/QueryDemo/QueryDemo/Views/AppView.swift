import Query
import SwiftUI
import GRDB

/// The main application view
struct AppView: View {
    /// A helper `Identifiable` type that can feed SwiftUI `sheet(item:onDismiss:content:)`
    private struct EditedPlayer: Identifiable {
        var id: Int64
    }
    
    @Query(PlayerRequest()) private var player
    @State private var editedPlayer: EditedPlayer?
    
    var body: some View {
        NavigationView {
            VStack {
                if let player = player, let id = player.id {
                    PlayerView(player: player, edit: { editPlayer(id: id) })
                        .padding(.vertical)
                    
                    Spacer()
                    populatedFooter(id: id)
                } else {
                    PlayerView(player: .placeholder)
                        .padding(.vertical)
                        .redacted(reason: .placeholder)
                    
                    Spacer()
                    emptyFooter()
                }
            }
            .padding(.horizontal)
            .sheet(item: $editedPlayer) { player in
                PlayerPresenceView(id: player.id)
            }
            .navigationTitle("@Query demo")
        }
    }
    
    private func emptyFooter() -> some View {
        VStack {
            Text("The demo application observes the database and displays information about the player.")
                .informationStyle()
            
            CreateButton("Create a Player")
        }
        .informationBox()
    }
    
    private func populatedFooter(id: Int64) -> some View {
        VStack(spacing: 10) {
            Text("What if another application component deletes the player at the most unexpected moment?")
                .informationStyle()
            DeleteButton("Delete Player")
            
            Spacer().frame(height: 10)
            Text("What if the player is deleted soon after the Edit button is hit?")
                .informationStyle()
            DeleteButton("Delete After Editing", after: {
                editPlayer(id: id)
            })
            
            Spacer().frame(height: 10)
            Text("What if the player is deleted right before the Edit button is hit?")
                .informationStyle()
            DeleteButton("Delete Before Editing", before: {
                editPlayer(id: id)
            })
        }
        .informationBox()
    }
    
    private func editPlayer(id: Int64) {
        editedPlayer = EditedPlayer(id: id)
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView()
        AppView().environment(\.dbQueue, populatedDatabaseQueue())
    }
}
