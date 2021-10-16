import SwiftUI

/// The view that creates a new player.
struct PlayerCreationView: View {
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.dismiss) private var dismiss
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
                    leading: Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    },
                    trailing: Button {
                        Task { await save() }
                    } label: {
                        Text("Save")
                    })
        }
    }
    
    private func save() async {
        do {
            var player = Player(id: nil, name: name, score: Int(score) ?? 0)
            try await appDatabase?.savePlayer(&player)
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
            .environment(\.appDatabase, .empty())
    }
}
