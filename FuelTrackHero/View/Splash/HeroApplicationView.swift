import SwiftUI
import Combine

struct HeroApplicationView: View {
    
    @EnvironmentObject var appState: AppState
    @StateObject private var controller = ApplicationController()
    @State private var eventSubscriptions: Set<AnyCancellable> = []
    
    var body: some View {
        ZStack {
            mainContent
            
            if controller.showPermissionRequest {
                PermissionRequestView()
                    .environmentObject(controller)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            setupEventHandlers()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch controller.displayMode {
        case .loading:
            SplashScreen()
            
        case .active:
            if controller.targetEndpoint != nil {
                TrackingContentView()
            } else {
                RootView()
                    .environmentObject(appState)
                    .preferredColorScheme(.dark)
            }
            
        case .standby:
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
            
        case .offline:
            DisconnectedView()
        }
    }
    
    private func setupEventHandlers() {
        NotificationCenter.default
            .publisher(for: Notification.Name("ConversionDataReceived"))
            .compactMap { $0.userInfo?["conversionData"] as? [String: Any] }
            .sink { data in
                controller.handleAttributionData(data)
            }
            .store(in: &eventSubscriptions)
        
        NotificationCenter.default
            .publisher(for: Notification.Name("deeplink_values"))
            .compactMap { $0.userInfo?["deeplinksData"] as? [String: Any] }
            .sink { data in
                controller.handleDeeplinkData(data)
            }
            .store(in: &eventSubscriptions)
    }
}

