import SwiftUI
import Combine

struct SplashScreen: View {
    @EnvironmentObject var appState: AppState
    @State private var canRotation: Double = 0
    @State private var canScale: CGFloat = 0.5
    @State private var canOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var featherParticles: [FeatherParticle] = []
    @State private var glowIntensity: Double = 0
    
    var body: some View {
        GeometryReader { g in
            ZStack {
                AsphaltBackground()
                
                Image(g.size.width > g.size.height ? "app_l_background" : "app_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: g.size.width, height: g.size.height)
                    .ignoresSafeArea()
                    .opacity(0.5)
                
                // Feather particles
                ForEach(featherParticles) { particle in
                    FeatherView(particle: particle)
                }
                
                VStack(spacing: 30) {
                    
                    // App title
                    VStack(spacing: 8) {
                        Text("FUEL TRACK")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: "#FFD84A"))
                            .tracking(2)
                        
                        Text("HERO")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#FFD84A"), Color(hex: "#FF8A1F")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .tracking(4)
                    }
                    .opacity(titleOpacity)
                    .shadow(color: Color(hex: "#FFD84A").opacity(0.5), radius: 10, x: 0, y: 5)
                    
                    // Animated fuel can
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: "#FFD84A").opacity(glowIntensity * 0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: 20)
                        
                        Image(systemName: "drop.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#FFD84A"), Color(hex: "#FF8A1F")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(hex: "#FFD84A").opacity(0.8), radius: 20, x: 0, y: 0)
                            .rotation3DEffect(
                                .degrees(canRotation),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.5
                            )
                            .scaleEffect(canScale)
                            .opacity(canOpacity)
                    }
                    
                }
            }
            .onAppear {
                startAnimations()
            }
        }
        .ignoresSafeArea()
    }
    
    private func startAnimations() {
        // Create feather particles
        for i in 0..<12 {
            let particle = FeatherParticle(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: -100...UIScreen.main.bounds.height),
                delay: Double(i) * 0.1
            )
            featherParticles.append(particle)
        }
        
        // Animate fuel can
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0)) {
            canScale = 1.0
            canOpacity = 1.0
        }
        
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            canRotation = 360
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowIntensity = 1.0
        }
        
        // Animate title
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            titleOpacity = 1.0
        }
    }
}

struct FeatherParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let delay: Double
}

struct FeatherView: View {
    let particle: FeatherParticle
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        Image(systemName: "leaf.fill")
            .resizable()
            .frame(width: 20, height: 20)
            .foregroundColor(Color(hex: "#3ED4C9").opacity(0.6))
            .rotationEffect(.degrees(rotation))
            .offset(x: particle.x, y: particle.y + offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 3.0)
                    .repeatForever(autoreverses: false)
                    .delay(particle.delay)
                ) {
                    offset = UIScreen.main.bounds.height + 100
                    opacity = 0
                }
                
                withAnimation(
                    .linear(duration: 3.0)
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
                
                withAnimation(.easeIn(duration: 0.5).delay(particle.delay)) {
                    opacity = 1
                }
            }
    }
}

#Preview(body: {
    SplashScreen()
})
