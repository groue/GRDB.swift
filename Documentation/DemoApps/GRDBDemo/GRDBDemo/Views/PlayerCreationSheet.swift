import SwiftUI

/// A view that creates a `Player`. Display it as a sheet.
struct PlayerCreationSheet: View {
    @Environment(\.appDatabase) var appDatabase
    @Environment(\.dismiss) var dismiss
    @State var form = PlayerForm(name: "", score: nil)
    
    var body: some View {
        NavigationStack {
            Form {
                PlayerFormView(form: $form)
            }
            .navigationTitle("New Player")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
    }
    
    private func save() {
        var player = Player(name: form.name, score: form.score ?? 0)
        try? appDatabase.savePlayer(&player)
        dismiss()
    }
}

// MARK: - Previews

#Preview {
    PlayerCreationSheet()
}
