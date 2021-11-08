import SwiftUI

struct PlayerView: View {
    var player: Player
    var edit: () -> Void
    
    var body: some View {
        HStack {
            AsyncImage(
                url: URL(string: "https://picsum.photos/seed/\(player.photoID)/200"),
                content: { image in
                    image.resizable()
                },
                placeholder: {
                    ProgressView()
                })
                .frame(width: 70, height: 70)
                .cornerRadius(10)
            VStack(alignment: .leading) {
                Text(player.name).bold()
                Text("Score: \(player.score)")
            }
            .padding(.vertical, 10)
            Spacer()
            Button("Edit", action: edit)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView(player: .makeRandom(), edit: { })
            .padding()
    }
}
