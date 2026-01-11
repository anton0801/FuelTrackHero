import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject var appData: AppData
    
    var bestWeek: String { "Week of Jan 1: 7.5 l/100km" } // Placeholder
    var worstWeek: String { "Week of Feb 1: 9.2 l/100km" }
    var averagePrice: Double { appData.refuels.isEmpty ? 0 : appData.refuels.map { $0.pricePerLiter }.reduce(0, +) / Double(appData.refuels.count) }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Consumption Graph
                    VStack(alignment: .leading) {
                        Text("Consumption Over Time")
                            .font(.title2.bold())
                            .foregroundColor(.purpleNeon)
                            .shadow(color: .purpleNeon.opacity(0.5), radius: 4)
                        
                        LineChart(data: appData.weeklyConsumption, color: .goldenNeon)
                            .frame(height: 220)
                            .padding(12)
                            .background(Color.shadowBlack.cornerRadius(20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.goldenNeon.opacity(0.3)))
                            .shadow(color: .shadowBlack, radius: 10)
                    }
                    
                    // Cost Graph
                    VStack(alignment: .leading) {
                        Text("Monthly Fuel Costs")
                            .font(.title2.bold())
                            .foregroundColor(.purpleNeon)
                            .shadow(color: .purpleNeon.opacity(0.5), radius: 4)
                        
                        BarChart(data: appData.monthlyCosts, color: .orangeGloss)
                            .frame(height: 220)
                            .padding(12)
                            .background(Color.shadowBlack.cornerRadius(20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.orangeGloss.opacity(0.3)))
                            .shadow(color: .shadowBlack, radius: 10)
                    }
                    
                    // Analytics
                    VStack(spacing: 16) {
                        Text("Analytics")
                            .font(.title2.bold())
                            .foregroundColor(.turquoiseLight)
                        
                        Grid {
                            GridRow {
                                Text("Best Week:")
                                Text(bestWeek)
                                    .foregroundColor(.green)
                            }
                            GridRow {
                                Text("Worst Week:")
                                Text(worstWeek)
                                    .foregroundColor(.red)
                            }
                            GridRow {
                                Text("Avg Consumption:")
                                Text("\(appData.averageConsumption?.formatted(to: 1) ?? "0.0") \(appData.settings.consumptionUnit)")
                                    .foregroundColor(Color.goldenNeon)
                            }
                            GridRow {
                                Text("Avg Fuel Price:")
                                Text("\(averagePrice.formatted(to: 2)) \(appData.settings.currency)")
                                    .foregroundColor(Color.goldenNeon)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(20)
                    .background(Color.asphaltBlack.cornerRadius(20))
                    .shadow(color: .shadowBlack, radius: 10)
                    
                    // Top AZS
                    VStack(alignment: .leading) {
                        Text("Top Gas Stations")
                            .font(.title2.bold())
                            .foregroundColor(.turquoiseLight)
                        
                        let sortedStations = appData.gasStations.sorted { $0.averagePrice < $1.averagePrice }
                        ForEach(sortedStations.prefix(3)) { station in
                            HStack {
                                Image(systemName: station.logo)
                                    .foregroundColor(.metalGray)
                                Text(station.name)
                                Spacer()
                                Text("Avg Price: \(station.averagePrice.formatted(to: 2))")
                                    .foregroundColor(.orangeGloss)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(20)
                    .background(Color.asphaltBlack.cornerRadius(20))
                    .shadow(color: .shadowBlack, radius: 10)
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .background(Color.asphaltBlack.ignoresSafeArea())
            .overlay(
                Image(systemName: "leaf.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.whiteHighlight.opacity(0.3))
                    .position(x: 100, y: 200)
            )
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    StatisticsView()
        .environmentObject(AppData())
}
