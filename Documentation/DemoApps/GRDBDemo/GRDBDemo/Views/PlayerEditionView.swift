import SwiftUI

struct PlayerEditionView: View {
    @Environment(\.isPresented) var isPresented
    @Environment(\.appDatabase) var appDatabase
    @State var form: PlayerForm
    var player: Player
    
    init(player: Player) {
        self.player = player
        self._form = State(initialValue: PlayerForm(name: player.name, score: player.score))
    }
    
    var body: some View {
        Form {
            PlayerFormView(form: $form)
        }
        .navigationTitle(player.name)
        .onChange(of: isPresented) {
            if !isPresented {
                // Back button was pressed
                save()
            }
        }
    }
    
    private func save() {
        var player = player
        player.name = form.name
        player.score = form.score ?? 0
        try? appDatabase.savePlayer(&player)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        PlayerEditionView(player: .makeRandom())
    }
}
