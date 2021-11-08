import GRDB
import SwiftUI

struct PlayerFormView: View {
    @Environment(\.dbQueue) var dbQueue
    var player: Player
    
    var body: some View {
        Stepper(
            "Score: \(player.score)",
            onIncrement: {
                modifyPlayer { $0.score += 10 }
            },
            onDecrement: {
                modifyPlayer { $0.score = max(0, $0.score - 10) }
            })

    }
    
    private func modifyPlayer(_ transform: (inout Player) -> Void) {
        do {
            _ = try dbQueue.write { db in
                var player = player
                try player.updateChanges(db, with: transform)
            }
        } catch PersistenceError.recordNotFound {
            // Oops, player no longer exists.
            // Ignore this error: it is handled in PlayerPresenceView.
        } catch {
            fatalError("\(error)")
        }
    }
}

struct PlayerFormView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerFormView(player: .makeRandom())
            .padding()
    }
}
