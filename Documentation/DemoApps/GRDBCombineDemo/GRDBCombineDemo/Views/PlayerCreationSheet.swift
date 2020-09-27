import SwiftUI

/// The Player creation sheet
struct PlayerCreationSheet: View {
    /// Manages the player form
    let viewModel: PlayerFormViewModel
    
    /// Executed when user cancels or saves the new user.
    let dismissAction: () -> Void
    
    @State private var errorAlertIsPresented = false
    @State private var errorAlertTitle = ""
    
    var body: some View {
        NavigationView {
            PlayerForm(viewModel: viewModel)
                .alert(
                    isPresented: $errorAlertIsPresented,
                    content: { Alert(title: Text(errorAlertTitle)) })
                .navigationBarTitle("New Player")
                .navigationBarItems(
                    leading: Button(
                        action: self.dismissAction,
                        label: { Text("Cancel") }),
                    trailing: Button(
                        action: self.save,
                        label: { Text("Save") }))
        }
    }
    
    private func save() {
        do {
            try viewModel.savePlayer()
            dismissAction()
        } catch {
            errorAlertTitle = (error as? LocalizedError)?.errorDescription ?? "An error occurred"
            errorAlertIsPresented = true
        }
    }
}

struct PlayerCreationSheet_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = PlayerFormViewModel(
            database: .empty(),
            player: .new())
        
        return PlayerCreationSheet(
            viewModel: viewModel,
            dismissAction: { })
    }
}
