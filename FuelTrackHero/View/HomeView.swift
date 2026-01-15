import SwiftUI

struct HomeView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @State private var showingAddRefueling = false
    @State private var featherOffset: CGFloat = 0
    @State private var canRotation: Double = 0
    
    var lastRefueling: Refueling? {
        firebaseService.refuelings.first
    }
    
    var averageConsumption: Double {
        let consumptions = firebaseService.refuelings.compactMap { $0.consumption }
        guard !consumptions.isEmpty else { return 0 }
        return consumptions.reduce(0, +) / Double(consumptions.count)
    }
    
    var consumptionTrend: (value: Double, isImproving: Bool) {
        let recent = firebaseService.refuelings.prefix(3).compactMap { $0.consumption }
        let older = firebaseService.refuelings.dropFirst(3).prefix(3).compactMap { $0.consumption }
        
        guard !recent.isEmpty, !older.isEmpty else { return (0, true) }
        
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)
        let diff = olderAvg - recentAvg
        
        return (abs(diff), diff > 0)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Track your fuel efficiency")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Animated feather
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#3ED4C9"))
                        .offset(y: featherOffset)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                featherOffset = -10
                            }
                        }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Last refueling card
                if let last = lastRefueling {
                    LastRefuelingCard(refueling: last, canRotation: $canRotation)
                        .padding(.horizontal)
                        .onAppear {
                            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                                canRotation = 360
                            }
                        }
                } else {
                    EmptyStateCard()
                        .padding(.horizontal)
                }
                
                // Average consumption display
                ConsumptionCard(
                    consumption: averageConsumption,
                    trend: consumptionTrend
                )
                .padding(.horizontal)
                
                // Weekly chart
                WeeklyConsumptionChart()
                    .padding(.horizontal)
                
                // Quick actions
                QuickActionsSection(showingAddRefueling: $showingAddRefueling)
                    .padding(.horizontal)
                    .padding(.bottom, 100)
            }
        }
        .background(AsphaltBackground())
        .sheet(isPresented: $showingAddRefueling) {
            AddRefuelingView()
        }
    }
}

// MARK: - Last Refueling Card
struct LastRefuelingCard: View {
    let refueling: Refueling
    @Binding var canRotation: Double
    @EnvironmentObject var firebaseService: FirebaseService
    
    var gasStation: GasStation? {
        guard let stationId = refueling.gasStationId else { return nil }
        return firebaseService.gasStations.first { $0.id == stationId }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with 3D fuel can
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#FFD84A").opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "drop.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#FFD84A"), Color(hex: "#FF8A1F")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(hex: "#FFD84A").opacity(0.6), radius: 10)
                        .rotation3DEffect(
                            .degrees(canRotation),
                            axis: (x: 0, y: 1, z: 0)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Refueling")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(refueling.date, style: .date)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding()
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Details
            VStack(spacing: 12) {
                RefuelingDetailRow(
                    icon: "drop.fill",
                    label: "Price per Liter",
                    value: String(format: "€%.2f", refueling.pricePerLiter),
                    color: Color(hex: "#FFD84A")
                )
                
                RefuelingDetailRow(
                    icon: "gauge.high",
                    label: "Liters",
                    value: String(format: "%.1f L", refueling.liters),
                    color: Color(hex: "#FF8A1F")
                )
                
                RefuelingDetailRow(
                    icon: "eurosign.circle.fill",
                    label: "Total Cost",
                    value: String(format: "€%.2f", refueling.totalCost),
                    color: Color(hex: "#6B4CFF")
                )
                
                RefuelingDetailRow(
                    icon: "speedometer",
                    label: "Odometer",
                    value: String(format: "%.0f km", refueling.odometer),
                    color: Color(hex: "#3ED4C9")
                )
                
                if let station = gasStation {
                    RefuelingDetailRow(
                        icon: "mappin.circle.fill",
                        label: "Station",
                        value: station.name,
                        color: Color(hex: "#C7C7C7")
                    )
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "#2A2A2A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#FFD84A").opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color(hex: "#FFD84A").opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

struct RefuelingDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Empty State Card
struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "fuelpump.circle")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#FFD84A").opacity(0.5))
            
            Text("No Refuelings Yet")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Add your first refueling to start tracking")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
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

// MARK: - Consumption Card
struct ConsumptionCard: View {
    let consumption: Double
    let trend: (value: Double, isImproving: Bool)
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Average Consumption")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.1f", consumption))
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#FFD84A"), Color(hex: "#FF8A1F")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(hex: "#FFD84A").opacity(0.5), radius: 20)
                
                Text("L/100km")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Trend indicator
            HStack(spacing: 8) {
                Image(systemName: trend.isImproving ? "arrow.down.right" : "arrow.up.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(trend.isImproving ? Color.green : Color.red)
                
                Text(String(format: "%.1f L/100km", trend.value))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(trend.isImproving ? Color.green : Color.red)
                
                Text(trend.isImproving ? "Better than before" : "Worse than before")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "#2A2A2A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#FF8A1F").opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color(hex: "#FF8A1F").opacity(0.2), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Weekly Chart
struct WeeklyConsumptionChart: View {
    @EnvironmentObject var firebaseService: FirebaseService
    
    var weeklyData: [Double] {
        let calendar = Calendar.current
        let today = Date()
        var data: [Double] = []
        
        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let dayStart = calendar.startOfDay(for: date)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                
                let dayRefuelings = firebaseService.refuelings.filter {
                    $0.date >= dayStart && $0.date < dayEnd
                }
                
                let avgConsumption = dayRefuelings.compactMap { $0.consumption }.reduce(0, +) / Double(max(dayRefuelings.count, 1))
                data.append(avgConsumption)
            }
        }
        
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last 7 Days")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<weeklyData.count, id: \.self) { index in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#FF8A1F"), Color(hex: "#FF8A1F").opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(
                                    width: (geometry.size.width - 56) / 7,
                                    height: max(weeklyData[index] * 10, 20)
                                )
                                .shadow(color: Color(hex: "#FF8A1F").opacity(0.4), radius: 5)
                            
                            Text(dayLabel(for: index))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .frame(height: 150)
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
    
    private func dayLabel(for index: Int) -> String {
        let calendar = Calendar.current
        let today = Date()
        guard let date = calendar.date(byAdding: .day, value: -(6 - index), to: today) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Quick Actions
struct QuickActionsSection: View {
    @Binding var showingAddRefueling: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Add refueling button
            Button(action: { showingAddRefueling = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                    
                    Text("Add Refueling")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    
                    Spacer()
                }
                .foregroundColor(Color(hex: "#1E1E1E"))
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FFD84A"), Color(hex: "#FF8A1F")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color(hex: "#FFD84A").opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}
