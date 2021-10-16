import SwiftUI

/// The main application view
struct AppView: View {
    /// Database access
    @Environment(\.appDatabase) private var appDatabase
    
    /// The `players` property is kept up-to-date with the list of players.
    @Query(PlayerRequest(ordering: .byScore)) private var players: [Player]
    
    /// We'll need to leave edit mode in several occasions.
    @State private var editMode = EditMode.inactive
    
    /// Tracks the presentation of the player creation sheet.
    @State private var newPlayerIsPresented = false
    
    /// Workaround "flash of missing content" with Swift async/await
    /// <https://forums.swift.org/t/52862>
    @State private var missingContent = true
    
    // If you want to define the query on initialization, you will prefer:
    //
    // @Query<PlayerRequest> private var players: [Player]
    //
    // init(initialOrdering: PlayerRequest.Ordering) {
    //     _players = Query(PlayerRequest(ordering: initialOrdering))
    // }
    
    var body: some View {
        NavigationView {
            if missingContent {
                EmptyView().onChange(of: players) { players in
                    missingContent = false
                }
            } else {
                PlayerList(players: players)
                    .navigationBarTitle(Text(missingContent ? "" : "\(players.count) Players"))
                    .navigationBarItems(
                        leading: HStack {
                            EditButton()
                            newPlayerButton
                        },
                        trailing: ToggleOrderingButton(
                            ordering: $players.ordering,
                            willChange: {
                                // onChange(of: $players.wrappedValue.ordering)
                                // reveals a bug in SwiftUI: the List remains in
                                // editing mode if the editMode is changed during
                                // the animation of the list content.
                                // Word around: stop editing *before* the ordering
                                // is changed, and the list content is updated.
                                stopEditing()
                            }))
                    .toolbar { toolbarContent }
                    .onChange(of: players) { players in
                        if players.isEmpty {
                            stopEditing()
                        }
                    }
                    .environment(\.editMode, $editMode)
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                // Don't stopEditing() here because this is
                // performed `onChange(of: players)`
                Task {
                    try? await appDatabase?.deleteAllPlayers()
                }
            } label: {
                Image(systemName: "trash").imageScale(.large)
            }
            
            Spacer()
            
            Button {
                stopEditing()
                Task {
                    try? await appDatabase?.refreshPlayers()
                }
            } label: {
                Image(systemName: "arrow.clockwise").imageScale(.large)
            }
            
            Spacer()
            
            Button {
                stopEditing()
                // Perform 50 refreshes in parallel
                Task {
                    try? await withThrowingTaskGroup(of: Void.self) { group in
                        for _ in 0..<50 {
                            _ = group.addTaskUnlessCancelled {
                                try await appDatabase?.refreshPlayers()
                            }
                        }
                        try await group.waitForAll()
                    }
                }
            } label: {
                Image(systemName: "tornado").imageScale(.large)
            }
        }
    }
    
    /// The button that presents the player creation sheet.
    private var newPlayerButton: some View {
        Button {
            stopEditing()
            newPlayerIsPresented = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibility(label: Text("New Player"))
        .sheet(isPresented: $newPlayerIsPresented) {
            PlayerCreationView()
        }
    }
    
    private func stopEditing() {
        withAnimation {
            editMode = .inactive
        }
    }
}

private struct ToggleOrderingButton: View {
    @Binding var ordering: PlayerRequest.Ordering
    let willChange: () -> Void
    
    var body: some View {
        switch ordering {
        case .byName:
            Button {
                willChange()
                ordering = .byScore
            } label: {
                Label("Name", systemImage: "arrowtriangle.up.fill").labelStyle(.titleAndIcon)
            }
        case .byScore:
            Button {
                willChange()
                ordering = .byName
            } label: {
                Label("Name", systemImage: "arrowtriangle.down.fill").labelStyle(.titleAndIcon)
            }
        }
    }
}

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview a database of random players
            AppView().environment(\.appDatabase, .random())
            
            // Preview an empty database
            AppView().environment(\.appDatabase, .empty())
        }
    }
}
