import SwiftUI

struct PlayerCreationSheet: View {
    @ObservedObject var viewModel: PlayerEditionViewModel
    @State var validationAlertVisible = false
    @State var validationAlertTitle = ""
    let dismiss: () -> Void
    
    var body: some View {
        NavigationView {
            PlayerEditionView(viewModel: self.viewModel)
                .alert(isPresented: $validationAlertVisible, content: {
                Alert(title: Text(validationAlertTitle))
            })
                .navigationBarTitle("New Player")
                .navigationBarItems(
                    leading: cancelButton,
                    trailing: saveButton)
        }
    }
    
    private var cancelButton: some View {
        Button(
            action: self.dismiss,
            label: { Text("Cancel") })
    }
    
    private var saveButton: some View {
        Button(
            action: {
                do {
                    try self.viewModel.save()
                    self.dismiss()
                } catch {
                    self.validationAlertTitle = (error as? LocalizedError)?.errorDescription ?? "An error occurred"
                    self.validationAlertVisible = true
                }
        },
            label: { Text("Save") })
    }
}
