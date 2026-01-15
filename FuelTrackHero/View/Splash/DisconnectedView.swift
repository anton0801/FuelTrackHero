import SwiftUI

struct DisconnectedView: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                // Background
                AsphaltBackground()
                
                Image(g.size.width > g.size.height ? "wifi_background" : "wifi_l_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: g.size.width, height: g.size.height)
                    .ignoresSafeArea()
                    .opacity(0.5)
                
                Image("wifi")
                    .resizable()
                    .frame(width: 250, height: 200)
                    .padding(.leading, g.size.width > g.size.height ? 250 : 0)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    DisconnectedView()
}
