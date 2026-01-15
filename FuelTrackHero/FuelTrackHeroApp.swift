import SwiftUI
import Firebase
import FirebaseAuth

@main
struct FuelTrackHeroApp: App {
    @StateObject private var appState = AppState()
    
    @UIApplicationDelegateAdaptor(LifecycleObserver.self) var lifecycleObserver
    
    init() {
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            HeroApplicationView()
                .environmentObject(appState)
        }
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(hex: "#1E1E1E")
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(hex: "#FFD84A"),
            .font: UIFont.systemFont(ofSize: 20, weight: .bold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(hex: "#1E1E1E")
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
}

class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    @Published var showingSplash = true
    
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: appState.showingSplash)
        .animation(.easeInOut(duration: 0.5), value: appState.hasCompletedOnboarding)
    }
}
