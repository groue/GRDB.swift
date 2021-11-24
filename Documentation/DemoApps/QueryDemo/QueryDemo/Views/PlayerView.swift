import SwiftUI

struct PlayerView: View {
    var player: Player
    var edit: () -> Void
    
    var body: some View {
        HStack {
            avatar()
            
            VStack(alignment: .leading) {
                Text(player.name).bold().font(.title3)
                Text("Score: \(player.score)")
            }
            
            Spacer()
            
            Button("Edit", action: edit)
        }
    }
    
    func avatar() -> some View {
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
    }
}

struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerView(player: .makeRandom(), edit: { })
            .padding()
    }
}
