import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var firebaseService = FirebaseService.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                
                RefuelingsListView()
                    .tag(1)
                
                StatisticsView()
                    .tag(2)
                
                GasStationsView()
                    .tag(3)
                
                SettingsView()
                    .tag(4)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            
            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal)
                .padding(.bottom, 10)
        }
        .environmentObject(firebaseService)
    }
}

struct TrackingContentView: View {
    
    @State private var destination: String? = ""
    
    var body: some View {
        ZStack {
            if let destination = destination,
               let url = URL(string: destination) {
                InterfaceRenderer(targetURL: url)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            initialize()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempURL"))) { _ in
            refresh()
        }
    }
    
    private func initialize() {
        let temp = UserDefaults.standard.string(forKey: "temp_url")
        let cached = UserDefaults.standard.string(forKey: "cached_endpoint") ?? ""
        
        destination = temp ?? cached
        
        if temp != nil {
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
    
    private func refresh() {
        if let temp = UserDefaults.standard.string(forKey: "temp_url"),
           !temp.isEmpty {
            destination = nil
            destination = temp
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
}


struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    let tabs: [(icon: String, title: String, color: Color)] = [
        ("house.fill", "Home", Color(hex: "#FFD84A")),
        ("list.bullet", "History", Color(hex: "#FF8A1F")),
        ("chart.bar.fill", "Stats", Color(hex: "#6B4CFF")),
        ("map.fill", "Stations", Color(hex: "#3ED4C9")),
        ("gearshape.fill", "Settings", Color(hex: "#C7C7C7"))
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabBarButton(
                    icon: tabs[index].icon,
                    title: tabs[index].title,
                    color: tabs[index].color,
                    isSelected: selectedTab == index
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }
                
                if index < tabs.count - 1 {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "#1E1E1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(isSelected ? color : .gray)
                .scaleEffect(isSelected ? 1.1 : 1.0)
            
            if isSelected {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
            }
        }
        .frame(minWidth: 60)
    }
}
