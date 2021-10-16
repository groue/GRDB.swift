import SwiftUI

/// The Player editing form, embedded in both
/// `PlayerCreationView` and `PlayerEditionView`.
struct PlayerFormView: View {
    @Binding var name: String
    @Binding var score: String
        
    var body: some View {
        List {
            TextField("Name", text: $name)
                .accessibility(label: Text("Player Name"))
            TextField("Score", text: $score).keyboardType(.numberPad)
                .accessibility(label: Text("Player Score"))
        }
        .listStyle(InsetGroupedListStyle())
    }
}

struct PlayerFormView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PlayerFormView(
                name: .constant(""),
                score: .constant(""))
            PlayerFormView(
                name: .constant(Player.randomName()),
                score: .constant("\(Player.randomScore())"))
        }
    }
}
