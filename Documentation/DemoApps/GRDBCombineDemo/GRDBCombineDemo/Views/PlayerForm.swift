import SwiftUI

/// The Player editing form, embedded in both
/// `PlayerCreationSheet` and `PlayerEditionView`.
struct PlayerForm: View {
    /// Manages the player form
    @ObservedObject var viewModel: PlayerFormViewModel
    
    var body: some View {
        List {
            TextField("Name", text: $viewModel.name)
            TextField("Score", text: $viewModel.score)
                .keyboardType(.numberPad)
        }
        .listStyle(GroupedListStyle())
        // Make sure the form is reset, in case a previous edition ended
        // with a validation error.
        //
        // The bug we want to prevent is the following:
        //
        // 1. Launch the app
        // 2. Tap a player
        // 3. Erase the name so that validation fails
        // 4. Hit the back button
        // 5. Tap the same player
        // 6. Bug: the form displays an empty name.
        .onAppear(perform: viewModel.reset)
    }
}

struct PlayerFormView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = PlayerFormViewModel(
            database: .empty(),
            player: .newRandom())
        
        return PlayerForm(viewModel: viewModel)
    }
}
