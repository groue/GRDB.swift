import SwiftUI

/// The view that edits an existing player.
struct PlayerEditionView: View {
    /// Write access to the database
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.isPresented) private var isPresented
    private let player: Player
    @State private var form: PlayerForm
    
    init(player: Player) {
        self.player = player
        self.form = PlayerForm(player)
    }
    
    var body: some View {
        PlayerFormView(form: $form)
            .onChange(of: isPresented) { isPresented in
                // Save when back button is pressed
                if !isPresented {
                    var savedPlayer = player
                    form.apply(to: &savedPlayer)
                    // Ignore error because I don't know how to cancel the
                    // back button and present the error
                    try? appDatabase.savePlayer(&savedPlayer)
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
