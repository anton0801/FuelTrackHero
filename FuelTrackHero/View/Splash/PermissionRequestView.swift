import SwiftUI

struct PermissionRequestView: View {
    
    @EnvironmentObject var controller: ApplicationMediator
    @State private var animating = false
    
    var body: some View {
        GeometryReader { g in
            ZStack {
                // Background
                AsphaltBackground()
                
                Image(g.size.width > g.size.height ? "accept_l_bg" : "accept_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: g.size.width, height: g.size.height)
                    .ignoresSafeArea()
                    .opacity(0.9)
                
                VStack(spacing: g.size.width > g.size.height ? 12 : 16) {
                    Spacer()
                    
                    textArea
                    buttonArea1
                    buttonArea2
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, g.size.width > g.size.height ? 18 : 42)
            }
        }
        .ignoresSafeArea()
    }
    
    private var iconArea: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.15), Color.green.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 130, height: 130)
                .scaleEffect(animating ? 1.15 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                    value: animating
                )
            
            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
        }
        .onAppear { animating = true }
    }
    
    private var textArea: some View {
        VStack(spacing: 6) {
            Text("Allow notifications about bonuses and promos")
                .font(.custom("BagelFatOne-Regular", size: 24))
                .foregroundColor(.white)
                .padding(.horizontal, 52)
                .multilineTextAlignment(.center)
            
            Text("Stay tuned with best offers from our casino")
                .font(.custom("BagelFatOne-Regular", size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 52)
                .multilineTextAlignment(.center)
        }
    }
    
    private var buttonArea1: some View {
        VStack(spacing: 0) {
            Button(action: {
                controller.grantPermission()
            }) {
                Image("accept")
                    .resizable()
                    .frame(width: 300, height: 55)
            }
        }
    }
    
    private var buttonArea2: some View {
        Button(action: {
            controller.rejectPermission()
        }) {
            Text("Skip")
                .font(.custom("BagelFatOne-Regular", size: 15))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 44)
    }
}

#Preview {
    PermissionRequestView()
}
