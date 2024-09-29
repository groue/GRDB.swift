import SwiftUI

/// The main navigation view.
struct PlayersNavigationView: View {
    @Environment(\.appDatabase) var appDatabase
    
    var body: some View {
        // This technique makes it possible to create an observable object
        // (PlayerListModel) from the SwiftUI environment.
        ContentView(appDatabase: appDatabase)
    }
}

private struct ContentView: View {
    /// The model for the player list.
    @State var model: PlayerListModel
    
    /// Tracks the edit mode of the player list.
    @State var editMode = EditMode.inactive
    
    /// Tracks the presentation of the player creation sheet.
    @State var presentsCreationSheet = false
    
    init(appDatabase: AppDatabase) {
        _model = State(initialValue: PlayerListModel(appDatabase: appDatabase))
    }
    
    var body: some View {
        NavigationStack {
            contentView
                .toolbar { bottomBarContent }
                .environment(\.editMode, $editMode)
        }
        .onAppear {
            model.observePlayers()
        }
        .onChange(of: model.ordering) {
            // Stop editing when ordering is modified
            stopEditing()
        }
        .onChange(of: model.players.isEmpty) {
            // Stop editing when the last player is deleted.
            if model.players.isEmpty {
                stopEditing()
            }
        }
        .sheet(isPresented: $presentsCreationSheet) {
            PlayerCreationSheet()
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if model.players.isEmpty {
            emptyPlayersView
        } else {
            PlayerListView(model: model)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        presentCreationSheetButton
                        EditButton()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ToggleOrderingButton(ordering: $model.ordering)
                    }
                }
        }
    }
    
    private var emptyPlayersView: some View {
        ContentUnavailableView {
            Label("The team is empty!", systemImage: "person.slash")
        } actions: {
            Button("Add Player") {
                presentsCreationSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        // Hide the title, but set a string anyway in order to avoid
        // an odd relayout when player list becomes empty during
        // the tornado.
        .navigationTitle("")
    }
    
    @ToolbarContentBuilder
    private var bottomBarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            deleteAllButton
            Spacer()
            refreshButton
            Spacer()
            tornadoButton
        }
    }
    
    private var presentCreationSheetButton: some View {
        Button {
            stopEditing()
            presentsCreationSheet = true
        } label: {
            Image(systemName: "plus")
        }
    }
    
    private var deleteAllButton: some View {
        Button {
            try? model.deleteAllPlayers()
        } label: {
            Image(systemName: "trash")
        }
    }
    
    private var refreshButton: some View {
        Button {
            Task {
                stopEditing()
                try? await model.refreshPlayers()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
    }
    
    private var tornadoButton: some View {
        Button {
            Task {
                stopEditing()
                try? await model.refreshPlayersManyTimes()
            }
        } label: {
            Image(systemName: "tornado")
        }
    }
    
    private func stopEditing() {
        withAnimation {
            editMode = .inactive
        }
    }
}

private struct ToggleOrderingButton: View {
    @Binding var ordering: PlayerListModel.Ordering
    
    var body: some View {
        switch ordering {
        case .byName:
            Button {
                ordering = .byScore
            } label: {
                buttonLabel("Name", systemImage: "arrowtriangle.up.fill")
            }
        case .byScore:
            Button {
                ordering = .byName
            } label: {
                buttonLabel("Score", systemImage: "arrowtriangle.down.fill")
            }
        }
    }
    
    private func buttonLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack {
            Text(title)
            Image(systemName: systemImage)
                .imageScale(.medium)
        }
    }
}

// MARK: - Previews

#Preview("Populated") {
    PlayersNavigationView()
        .appDatabase(.random())
}

#Preview("Empty") {
    PlayersNavigationView()
        .appDatabase(.empty())
}
