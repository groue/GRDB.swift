import SwiftUI

/// The Player edition view, designed to be the destination of
/// a NavigationLink.
struct PlayerEditor: View {
    /// Manages edition of the player
    let viewModel: PlayerFormViewModel
    
    var body: some View {
        PlayerForm(viewModel: viewModel)
        .onDisappear(perform: {
            // Ignore validation errors
            try? self.viewModel.savePlayer()
        })
    }
}

#if DEBUG
struct PlayerEditionView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = try! PlayerFormViewModel(
            database: .empty(),
            player: .newRandom())
        
        return NavigationView {
            PlayerEditor(viewModel: viewModel)
                .navigationBarTitle("Player Edition")
        }
    }
}
#endif
