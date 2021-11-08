import Query
import SwiftUI
import GRDB

struct AppView: View {
    /// A helper `Identifiable` type that can feed SwiftUI `sheet(item:onDismiss:content:)`
    private struct EditedPlayer: Identifiable {
        var id: Int64
    }
    
    @Environment(\.dbQueue) private var dbQueue
    @Query(PlayerRequest()) private var player
    @State private var editedPlayer: EditedPlayer?
    
    var body: some View {
        VStack {
            informationHeader(playerExists: player != nil)
            
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
    
    private func informationHeader(playerExists: Bool) -> some View {
        VStack {
            Text("The application observes the database and displays information about the player.")
                .informationStyle()
            
            if !playerExists {
                Button("Create a Player") {
                    try! dbQueue.write { db in
                        _ = try Player.makeRandom().inserted(db)
                    }
                }
            }
        }
        .informationBox()
    }
    
    private func informationFooter(id: Int64) -> some View {
        VStack(spacing: 10) {
            Text("**What if another application component deletes the player at the most unexpected moment?**")
                .informationStyle()
            Button("Delete Player") {
                _ = try! dbQueue.write(Player.deleteAll)
            }
            Spacer().frame(height: 10)
            Text("What if the player is deleted soon after the Edit button is hit?")
                .informationStyle()
            Button("Edit Player Then Delete") {
                editPlayer(id: id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    _ = try! dbQueue.write(Player.deleteAll)
                }
            }
            Spacer().frame(height: 10)
            Text("What if the player is deleted right before the Edit button is hit?")
                .informationStyle()
            Button("Delete Then Edit Player") {
                _ = try! dbQueue.write(Player.deleteAll)
                editPlayer(id: id)
            }
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
    }
}
