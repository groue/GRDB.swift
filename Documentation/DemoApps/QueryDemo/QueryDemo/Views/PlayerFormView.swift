import GRDB
import SwiftUI

/// The view that edits a player
struct PlayerFormView: View {
    @Environment(\.dbQueue) var dbQueue
    var player: Player
    
    var body: some View {
        Stepper(
            "Score: \(player.score)",
            onIncrement: { updateScore { $0 += 10 } },
            onDecrement: { updateScore { $0 = max(0, $0 - 10) } })
    }
    
    private func updateScore(_ transform: (inout Int) -> Void) {
        do {
            _ = try dbQueue.write { db in
                var player = player
                try player.updateChanges(db) {
                    transform(&$0.score)
                }
            }
        } catch PersistenceError.recordNotFound {
            // Oops, player does not exist.
            // Ignore this error: `PlayerPresenceView` will dismiss.
            //
            // You can comment out this specific handling of
            // `PersistenceError.recordNotFound`, run the preview, change the
            // score, and see what happens.
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
