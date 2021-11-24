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
        VStack {
            informationHeader(showCreateButton: player == nil)
            
            Spacer()
            
            if let player = player, let id = player.id {
                PlayerView(player: player, edit: {
                    editPlayer(id: id)
                })
                Spacer()
                informationFooter(id: id)
            } else {
                Text("The database contains no player.")
                Spacer()
            }
        }
        .padding(.horizontal)
        .sheet(item: $editedPlayer) { player in
            PlayerPresenceView(id: player.id)
        }
    }
    
    private func informationHeader(showCreateButton: Bool) -> some View {
        VStack {
            Text("The `@Query` demo application observes the database and displays information about the player.")
                .informationStyle()
            
            if showCreateButton {
                CreateButton("Create a Player")
            }
        }
        .informationBox()
    }
    
    private func informationFooter(id: Int64) -> some View {
        VStack(spacing: 10) {
            Text("**What if another application component deletes the player at the most unexpected moment?**")
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

struct AppView_Previews_Empty: PreviewProvider {
    static var previews: some View {
        AppView()
    }
}

struct AppView_Previews_Populated: PreviewProvider {
    static var previews: some View {
        AppView().environment(\.dbQueue, populatedDatabaseQueue())
    }
}
