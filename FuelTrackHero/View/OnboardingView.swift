import SwiftUI
import WebKit

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "gauge.high",
            title: "Track Your Fuel",
            description: "Monitor fuel consumption with precision. Get real-time insights into your vehicle's efficiency.",
            color: Color(hex: "#FFD84A")
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Analyze Trends",
            description: "Beautiful charts show your consumption patterns, costs, and savings over time.",
            color: Color(hex: "#FF8A1F")
        ),
        OnboardingPage(
            icon: "map.fill",
            title: "Find Best Stations",
            description: "Track your favorite gas stations and compare prices to save money.",
            color: Color(hex: "#6B4CFF")
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Smart Reminders",
            description: "Never forget to refuel. Get notified when it's time to track your data.",
            color: Color(hex: "#3ED4C9")
        )
    ]
    
    var body: some View {
        ZStack {
            AsphaltBackground()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            pageIndex: index,
                            currentPage: currentPage
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Custom page indicator and buttons
                VStack(spacing: 30) {
                    // Page indicators
                    HStack(spacing: 12) {
                        ForEach(pages.indices, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? pages[index].color : Color.gray.opacity(0.3))
                                .frame(width: currentPage == index ? 12 : 8, height: currentPage == index ? 12 : 8)
                                .shadow(color: currentPage == index ? pages[index].color.opacity(0.6) : .clear, radius: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Action buttons
                    HStack(spacing: 15) {
                        if currentPage < pages.count - 1 {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    appState.hasCompletedOnboarding = true
                                }
                            }) {
                                Text("Skip")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                        
                        Button(action: {
                            if currentPage < pages.count - 1 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentPage += 1
                                }
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    appState.hasCompletedOnboarding = true
                                }
                            }
                        }) {
                            HStack {
                                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#1E1E1E"))
                                
                                if currentPage < pages.count - 1 {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color(hex: "#1E1E1E"))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [pages[currentPage].color, pages[currentPage].color.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: pages[currentPage].color.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}


extension RenderingDelegate: WKUIDelegate {
    
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              let manager = manager,
              let primary = manager.primaryInterface else {
            return nil
        }
        
        let secondary = WKWebView(frame: .zero, configuration: configuration)
        
        prepareSecondary(secondary, within: primary)
        attachSwipeRecognizer(to: secondary)
        
        manager.secondaryInterfaces.append(secondary)
        
        if let url = navigationAction.request.url,
           url.absoluteString != "about:blank" {
            secondary.load(navigationAction.request)
        }
        
        return secondary
    }
    
    private func prepareSecondary(_ secondary: WKWebView, within primary: WKWebView) {
        secondary.translatesAutoresizingMaskIntoConstraints = false
        secondary.scrollView.isScrollEnabled = true
        secondary.scrollView.minimumZoomScale = 1.0
        secondary.scrollView.maximumZoomScale = 1.0
        secondary.scrollView.bounces = false
        secondary.scrollView.bouncesZoom = false
        secondary.allowsBackForwardNavigationGestures = true
        secondary.navigationDelegate = self
        secondary.uiDelegate = self
        
        primary.addSubview(secondary)
        
        NSLayoutConstraint.activate([
            secondary.leadingAnchor.constraint(equalTo: primary.leadingAnchor),
            secondary.trailingAnchor.constraint(equalTo: primary.trailingAnchor),
            secondary.topAnchor.constraint(equalTo: primary.topAnchor),
            secondary.bottomAnchor.constraint(equalTo: primary.bottomAnchor)
        ])
    }
    
    private func attachSwipeRecognizer(to interface: WKWebView) {
        let recognizer = UIScreenEdgePanGestureRecognizer(
            target: self,
            action: #selector(handleSwipeGesture(_:))
        )
        recognizer.edges = .left
        interface.addGestureRecognizer(recognizer)
    }
    
    @objc private func handleSwipeGesture(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        guard recognizer.state == .ended,
              let interface = recognizer.view as? WKWebView else {
            return
        }
        
        if interface.canGoBack {
            interface.goBack()
        } else if manager?.secondaryInterfaces.last === interface {
            manager?.navigateToPrevious(target: nil)
        }
    }
    
    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    let pageIndex: Int
    let currentPage: Int
    
    @State private var iconScale: CGFloat = 0.5
    @State private var iconRotation: Double = 0
    @State private var textOffset: CGFloat = 50
    @State private var textOpacity: Double = 0
    @State private var particles: [CGPoint] = []
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated icon with particles
            ZStack {
                // Particle effects
                ForEach(particles.indices, id: \.self) { index in
                    Circle()
                        .fill(page.color.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .position(particles[index])
                        .blur(radius: 2)
                }
                
                // Glow circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.color.opacity(0.3),
                                page.color.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                
                // Icon background
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 160, height: 160)
                
                // Icon
                Image(systemName: page.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.color, page.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: page.color.opacity(0.6), radius: 15)
                    .scaleEffect(iconScale)
                    .rotation3DEffect(
                        .degrees(iconRotation),
                        axis: (x: 0, y: 1, z: 0)
                    )
            }
            .frame(height: 250)
            
            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
            }
            .offset(y: textOffset)
            .opacity(textOpacity)
            
            Spacer()
        }
        .onChange(of: currentPage) { newValue in
            if newValue == pageIndex {
                animateIn()
            }
        }
        .onAppear {
            if currentPage == pageIndex {
                animateIn()
            }
        }
    }
    
    private func animateIn() {
        // Reset states
        iconScale = 0.5
        iconRotation = 0
        textOffset = 50
        textOpacity = 0
        particles = []
        
        // Create particles
        createParticles()
        
        // Animate icon
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
            iconScale = 1.0
        }
        
        withAnimation(.easeInOut(duration: 2.0).delay(0.2)) {
            iconRotation = 360
        }
        
        // Animate text
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
            textOffset = 0
            textOpacity = 1.0
        }
    }
    
    private func createParticles() {
        let center = CGPoint(x: UIScreen.main.bounds.width / 2, y: 200)
        for _ in 0..<8 {
            let angle = Double.random(in: 0...(2 * .pi))
            let radius = CGFloat.random(in: 80...120)
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            particles.append(CGPoint(x: x, y: y))
        }
    }
}
