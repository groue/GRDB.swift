import SwiftUI

/// The view that creates a new player.
struct PlayerCreationView: View {
    /// Executed when user cancels or saves the new user.
    let dismissAction: () -> Void
    
    @Environment(\.appDatabase) private var appDatabase
    @State private var name = ""
    @State private var score = ""
    @State private var errorAlertIsPresented = false
    @State private var errorAlertTitle = ""
    
    var body: some View {
        NavigationView {
            PlayerFormView(name: $name, score: $score)
                .alert(
                    isPresented: $errorAlertIsPresented,
                    content: { Alert(title: Text(errorAlertTitle)) })
                .navigationBarTitle("New Player")
                .navigationBarItems(
                    leading: Button(
                        action: dismissAction,
                        label: { Text("Cancel") }),
                    trailing: Button(
                        action: save,
                        label: { Text("Save") }))
        }
    }
    
    private func save() {
        do {
            var player = Player(id: nil, name: name, score: Int(score) ?? 0)
            try appDatabase?.savePlayer(&player)
            dismissAction()
        } catch {
            errorAlertTitle = (error as? LocalizedError)?.errorDescription ?? "An error occurred"
            errorAlertIsPresented = true
        }
    }
}

struct PlayerCreationSheet_Previews: PreviewProvider {
    static var previews: some View {
        PlayerCreationView(dismissAction: { })
            .environment(\.appDatabase, .empty())
    }
}
