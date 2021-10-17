import SwiftUI

/// The Player editing form, embedded in both
/// `PlayerCreationView` and `PlayerEditionView`.
struct PlayerFormView: View {
    @Binding var form: PlayerForm
    
    var body: some View {
        List {
            TextField("Name", text: $form.name)
                .accessibility(label: Text("Player Name"))
            TextField("Score", text: $form.score).keyboardType(.numberPad)
                .accessibility(label: Text("Player Score"))
        }
        .listStyle(InsetGroupedListStyle())
    }
}

struct PlayerForm {
    var name: String
    var score: String
}

extension PlayerForm {
    init(_ player: Player) {
        self.name = player.name
        self.score = "\(player.score)"
    }
    
    func apply(to player: inout Player) {
        player.name = name
        player.score = Int(score) ?? 0
    }
}

struct PlayerFormView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PlayerFormView(form: .constant(PlayerForm(
                name: "",
                score: "")))
            PlayerFormView(form: .constant(PlayerForm(
                name: Player.randomName(),
                score: "\(Player.randomScore())")))
        }
    }
}
