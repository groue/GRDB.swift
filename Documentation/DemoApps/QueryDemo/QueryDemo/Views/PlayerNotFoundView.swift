import SwiftUI

/// The view that is displayed when a player can not be found.
struct PlayerNotFoundView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            VStack {
                Spacer()
                Text("404").font(Font.system(size: 64)).fontWeight(.heavy)
                Text("😵").font(Font.system(size: 100))
                Spacer()
                Spacer()
                Spacer()
            }.padding()
        }
    }
}

struct PlayerNotFoundView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerNotFoundView()
    }
}
