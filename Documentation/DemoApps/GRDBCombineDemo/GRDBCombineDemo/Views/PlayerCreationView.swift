import SwiftUI

/// The view that creates a new player.
struct PlayerCreationView: View {
    /// Write access to the database
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss
    @State private var form = PlayerForm(name: "", score: "")
    @State private var errorAlertIsPresented = false
    @State private var errorAlertTitle = ""
    
    var body: some View {
        NavigationView {
            PlayerFormView(form: $form)
                .alert(
                    isPresented: $errorAlertIsPresented,
                    content: { Alert(title: Text(errorAlertTitle)) })
                .navigationBarTitle("New Player")
                .navigationBarItems(
                    leading: Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    },
                    trailing: Button {
                        save()
                    } label: {
                        Text("Save")
                    })
        }
    }
    
    private func save() {
        do {
            var player = Player(id: nil, name: "", score: 0)
            form.apply(to: &player)
            try appDatabase.savePlayer(&player)
            dismiss()
        } catch {
            errorAlertTitle = (error as? LocalizedError)?.errorDescription ?? "An error occurred"
            errorAlertIsPresented = true
        }
    }
}

struct PlayerCreationSheet_Previews: PreviewProvider {
    static var previews: some View {
        PlayerCreationView()
    }
}
