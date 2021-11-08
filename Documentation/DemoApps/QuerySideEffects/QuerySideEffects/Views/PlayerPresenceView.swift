import GRDB
import Query
import SwiftUI

struct PlayerPresenceView: View {
    @Environment(\.dbQueue) private var dbQueue
    @Environment(\.dismiss) private var dismiss
    @Query<PlayerPresenceRequest> private var playerPresence: PlayerPresence
    @State var gonePlayerAlertPresented = false
    
    init(id: Int64) {
        _playerPresence = Query(PlayerPresenceRequest(id: id))
    }
    
    var body: some View {
        NavigationView {
            if let player = playerPresence.player {
                VStack {
                    PlayerFormView(player: player)
                    
                    Spacer()
                    
                    if playerPresence.exists {
                        VStack(spacing: 10) {
                            Text("**What if another application component deletes the player at the most unexpected moment?**")
                                .informationStyle()
                            Button("Delete Player") {
                                _ = try! dbQueue.write(Player.deleteAll)
                            }
                        }
                        .informationBox()
                    }
                }
                .padding(.horizontal)
                .navigationTitle(player.name)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                    }
                }
            } else {
                PlayerNotFoundView()
            }
        }
        .alert("Ooops, player is gone.", isPresented: $gonePlayerAlertPresented, actions: {
            Button("OK") { dismiss() }
        })
        .onAppear {
            if !playerPresence.exists {
                gonePlayerAlertPresented = true
            }
        }
        .onChange(of: playerPresence.exists, perform: { playerExists in
            if !playerExists {
                gonePlayerAlertPresented = true
            }
        })
    }
}

struct PlayerPresenceView_Previews_Existing: PreviewProvider {
    static var previews: some View {
        PlayerPresenceView(id: 1)
    }
}

struct PlayerPresenceView_Previews_Missing: PreviewProvider {
    static var previews: some View {
        PlayerPresenceView(id: -1)
    }
}
