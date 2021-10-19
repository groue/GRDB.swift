import SwiftUI

/// The view that edits an existing player.
struct PlayerEditionView: View {
    @Environment(\.appDatabase) private var appDatabase
    private let player: Player
    @State private var form: PlayerForm
    
    init(player: Player) {
        self.player = player
        self.form = PlayerForm(player)
    }
    
    var body: some View {
        PlayerFormView(form: $form)
            .onDisappear {
                Task {
                    // save and ignore error
                    var savedPlayer = player
                    form.apply(to: &savedPlayer)
                    try? await appDatabase.savePlayer(&savedPlayer)
                }
            }
    }
}

struct PlayerEditionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PlayerEditionView(player: Player.makeRandom())
                .navigationBarTitle("Player Edition")
        }
    }
}
