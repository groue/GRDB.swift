import GRDB
import Query
import SwiftUI

/// The sheet for player edition.
///
/// In this demo app, this view don't want to remain on screen
/// whenever the edited player no longer exists in the database.
struct PlayerPresenceView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Query<PlayerPresenceRequest>
    private var playerPresence: PlayerPresence
    
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
                            Text("What if another application component deletes the player at the most unexpected moment?s")
                                .informationStyle()
                            DeleteButton("Delete Player")
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
            Button("Dismiss") { dismiss() }
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

struct PlayerPresenceView_Previews: PreviewProvider {
    static var previews: some View {
        let playerId: Int64 = 1
        let dbQueue = populatedDatabaseQueue(playerId: playerId)
        PlayerPresenceView(id: playerId).environment(\.dbQueue, dbQueue)
        PlayerPresenceView(id: -1)
    }
}
