import SwiftUI

/// A button that creates players in the database
struct CreateButton: View {
    @Environment(\.dbQueue) private var dbQueue
    private var titleKey: LocalizedStringKey
    
    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }
    
    var body: some View {
        Button {
            try! dbQueue.write { db in
                _ = try Player.makeRandom().inserted(db)
            }
        } label: {
            Label(titleKey, systemImage: "plus")
        }
    }
}

/// A button that deletes players in the database
struct DeleteButton: View {
    private enum Mode {
        case deleteAfter
        case deleteBefore
    }
    
    @Environment(\.dbQueue) private var dbQueue
    private var titleKey: LocalizedStringKey
    private var action: (() -> Void)?
    private var mode: Mode
    
    /// Creates a button that simply deletes players.
    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
        self.mode = .deleteBefore
    }
    
    /// Creates a button that deletes players soon after performing `action`.
    init(
        _ titleKey: LocalizedStringKey,
        after action: @escaping () -> Void)
    {
        self.titleKey = titleKey
        self.action = action
        self.mode = .deleteAfter
    }
    
    /// Creates a button that deletes players immediately after performing `action`.
    init(
        _ titleKey: LocalizedStringKey,
        before action: @escaping () -> Void)
    {
        self.titleKey = titleKey
        self.action = action
        self.mode = .deleteBefore
    }
    
    var body: some View {
        Button {
            switch mode {
            case .deleteAfter:
                action?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    _ = try! dbQueue.write(Player.deleteAll)
                }
                
            case .deleteBefore:
                _ = try! dbQueue.write(Player.deleteAll)
                action?()
            }
        } label: {
            Label(titleKey, systemImage: "trash")
        }
    }
}

import Query
struct DatabaseButtons_Previews: PreviewProvider {
    struct Preview: View {
        @Query(PlayerCountRequest()) var playerCount: Int
        var body: some View {
            VStack {
                Text("Number of players: \(playerCount)")
                CreateButton("Create Player")
                DeleteButton("Delete Players")
            }
            .informationBox()
            .padding()
        }
    }
    
    static var previews: some View {
        Preview()
    }
}
