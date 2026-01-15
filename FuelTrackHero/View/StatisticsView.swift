import SwiftUI
import WebKit
import Combine

struct StatisticsView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    
    var statistics: FuelStatistics {
        firebaseService.getStatistics()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header stats
                    VStack(spacing: 16) {
                        StatCard(
                            title: "Average Consumption",
                            value: "\(statistics.averageConsumption.formatted(digits: 1)) L/100km",
                            icon: "gauge.high",
                            color: Color(hex: "#FFD84A")
                        )
                        
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Total Spent",
                                value: "€\(statistics.totalSpent.formatted(digits: 2))",
                                icon: "eurosign.circle.fill",
                                color: Color(hex: "#FF8A1F"),
                                isCompact: true
                            )
                            
                            StatCard(
                                title: "Total Distance",
                                value: "\(Int(statistics.totalDistance)) km",
                                icon: "road.lanes",
                                color: Color(hex: "#6B4CFF"),
                                isCompact: true
                            )
                        }
                        
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Best Week",
                                value: "\(statistics.bestWeekConsumption.formatted(digits: 1))",
                                icon: "arrow.down.circle.fill",
                                color: Color.green,
                                isCompact: true
                            )
                            
                            StatCard(
                                title: "Worst Week",
                                value: "\(statistics.worstWeekConsumption.formatted(digits: 1))",
                                icon: "arrow.up.circle.fill",
                                color: Color.red,
                                isCompact: true
                            )
                        }
                    }
                    .padding()
                    
                    // Consumption chart
                    ConsumptionChartView()
                        .padding()
                    
                    // Price trends
                    PriceTrendsView()
                        .padding()
                    
                    Spacer(minLength: 100)
                }
            }
            .background(AsphaltBackground())
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isCompact: Bool = false
    
    var body: some View {
        VStack(spacing: isCompact ? 8 : 12) {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 24 : 32, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: isCompact ? 12 : 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            
            Text(value)
                .font(.system(size: isCompact ? 18 : 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(isCompact ? 16 : 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#2A2A2A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ConsumptionChartView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    
    var chartData: [(date: Date, consumption: Double)] {
        firebaseService.refuelings
            .compactMap { refueling -> (Date, Double)? in
                guard let consumption = refueling.consumption else { return nil }
                return (refueling.date, consumption)
            }
            .reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Consumption Trend")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if chartData.isEmpty {
                Text("Not enough data")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(40)
            } else {
                GeometryReader { geometry in
                    LineChartView(data: chartData, width: geometry.size.width, height: 200)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "#2A2A2A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

final class RenderingManager: ObservableObject {
    
    @Published private(set) var primaryInterface: WKWebView!
    @Published var secondaryInterfaces: [WKWebView] = []
    
    let persistenceManager = PersistenceManager()
    
    private var observers = Set<AnyCancellable>()
    
    func createPrimaryInterface() {
        let settings = buildSettings()
        primaryInterface = WKWebView(frame: .zero, configuration: settings)
        customizeInterface(primaryInterface)
    }
    
    private func buildSettings() -> WKWebViewConfiguration {
        let settings = WKWebViewConfiguration()
        settings.allowsInlineMediaPlayback = true
        settings.mediaTypesRequiringUserActionForPlayback = []
        
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        settings.preferences = preferences
        
        let contentPrefs = WKWebpagePreferences()
        contentPrefs.allowsContentJavaScript = true
        settings.defaultWebpagePreferences = contentPrefs
        
        return settings
    }
    
    private func customizeInterface(_ interface: WKWebView) {
        interface.scrollView.minimumZoomScale = 1.0
        interface.scrollView.maximumZoomScale = 1.0
        interface.scrollView.bounces = false
        interface.scrollView.bouncesZoom = false
        interface.allowsBackForwardNavigationGestures = true
    }
    
    func navigateToPrevious(target: URL? = nil) {
        if !secondaryInterfaces.isEmpty {
            if let last = secondaryInterfaces.last {
                last.removeFromSuperview()
                secondaryInterfaces.removeLast()
            }
            
            if let target = target {
                primaryInterface.load(URLRequest(url: target))
            }
        } else if primaryInterface.canGoBack {
            primaryInterface.goBack()
        }
    }
    
    func reloadInterface() {
        primaryInterface.reload()
    }
}

struct LineChartView: View {
    let data: [(date: Date, consumption: Double)]
    let width: CGFloat
    let height: CGFloat
    
    var maxConsumption: Double {
        data.map { $0.consumption }.max() ?? 10
    }
    
    var minConsumption: Double {
        data.map { $0.consumption }.min() ?? 0
    }
    
    var body: some View {
        ZStack {
            // Grid lines
            ForEach(0..<5) { i in
                Path { path in
                    let y = CGFloat(i) * height / 4
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
            
            // Line chart
            Path { path in
                for (index, point) in data.enumerated() {
                    let x = CGFloat(index) * (width / CGFloat(data.count - 1))
                    let normalizedValue = (point.consumption - minConsumption) / (maxConsumption - minConsumption)
                    let y = height - (CGFloat(normalizedValue) * height)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [Color(hex: "#FFD84A"), Color(hex: "#FF8A1F")],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: Color(hex: "#FFD84A").opacity(0.5), radius: 10)
            
            // Data points
            ForEach(data.indices, id: \.self) { index in
                let point = data[index]
                let x = CGFloat(index) * (width / CGFloat(data.count - 1))
                let normalizedValue = (point.consumption - minConsumption) / (maxConsumption - minConsumption)
                let y = height - (CGFloat(normalizedValue) * height)
                
                Circle()
                    .fill(Color(hex: "#FFD84A"))
                    .frame(width: 8, height: 8)
                    .position(x: x, y: y)
                    .shadow(color: Color(hex: "#FFD84A").opacity(0.6), radius: 5)
            }
        }
    }
}

struct PriceTrendsView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    
    var priceData: [Double] {
        Array(firebaseService.refuelings.prefix(10).map { $0.pricePerLiter }.reversed())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Price History")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if priceData.isEmpty {
                Text("Not enough data")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(40)
            } else {
                GeometryReader { geometry in
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(priceData.indices, id: \.self) { index in
                            VStack {
                                Spacer()
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#FF8A1F"), Color(hex: "#FF8A1F").opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(height: (priceData[index] / (priceData.max() ?? 2)) * geometry.size.height * 0.8)
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "#2A2A2A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

