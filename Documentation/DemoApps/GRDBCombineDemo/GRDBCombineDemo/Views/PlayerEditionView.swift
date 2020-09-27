import SwiftUI

/// The Player edition view, designed to be the destination of
/// a NavigationLink.
struct PlayerEditionView: View {
    /// Manages the player form
    let viewModel: PlayerFormViewModel
    
    var body: some View {
        PlayerForm(viewModel: viewModel)
            .onDisappear(perform: {
                // Ignore validation errors
                try? self.viewModel.savePlayer()
            })
    }
}

struct PlayerEditionView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = PlayerFormViewModel(
            database: .empty(),
            player: .newRandom())
        
        return NavigationView {
            PlayerEditionView(viewModel: viewModel)
                .navigationBarTitle("Player Edition")
        }
    }
}
