import SwiftUI

struct PlayerFormView: View {
    @Binding var form: PlayerForm
    
    private enum FocusElement {
        case name
        case score
    }
    @FocusState private var focusedElement: FocusElement?
    
    var body: some View {
        Group {
            LabeledContent {
                TextField(text: $form.name) { EmptyView() }
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedElement, equals: .name)
                    .labelsHidden()
                    .onSubmit {
                        focusedElement = .score
                    }
            } label: {
                Text("Name").foregroundStyle(.secondary)
            }
            
            LabeledContent {
                TextField(value: $form.score, format: .number) { EmptyView() }
                    .keyboardType(.numberPad)
                    .focused($focusedElement, equals: .score)
                    .labelsHidden()
            } label: {
                Text("Score").foregroundStyle(.secondary)
            }
        }
        .onAppear { focusedElement = .name }
    }
}

struct PlayerForm {
    var name: String
    var score: Int?
}

#Preview {
    @Previewable @State var form = PlayerForm(name: "John", score: 100)
    
    Form {
        PlayerFormView(form: $form)
    }
}
