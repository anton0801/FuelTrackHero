import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appData: AppData
    @State private var featherOffset: CGFloat = -50
    @State private var featherRotation: Double = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Last Refuel Block with gloss
                    if let last = appData.lastRefuel {
                        VStack(spacing: 12) {
                            Image(systemName: "fuelpump.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.metalGray, .whiteHighlight]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: Color.shadowBlack, radius: 8, x: 4, y: 4)
                            
                            Text("Last Refuel")
                                .font(.title2.bold())
                                .foregroundColor(.purpleNeon)
                                .shadow(color: Color.purpleNeon.opacity(0.6), radius: 4)
                            
                            Grid(alignment: .leading) {
                                GridRow {
                                    Text("Price/L:")
                                    Text("\(last.pricePerLiter.formatted(to: 2)) \(appData.settings.currency)")
                                        .foregroundColor(Color.goldenNeon)
                                }
                                GridRow {
                                    Text("Liters:")
                                    Text("\(last.liters.formatted(to: 2))")
                                        .foregroundColor(Color.goldenNeon)
                                }
                                GridRow {
                                    Text("Total:")
                                    Text("\(last.totalAmount.formatted(to: 2)) \(appData.settings.currency)")
                                        .foregroundColor(Color.goldenNeon)
                                }
                                GridRow {
                                    Text("Mileage:")
                                    Text("\(last.mileage.formatted(to: 0)) km")
                                        .foregroundColor(Color.goldenNeon)
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [.asphaltBlack, .shadowBlack]), startPoint: .top, endPoint: .bottom)
                                .cornerRadius(20)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.metalGray.opacity(0.3), lineWidth: 1))
                        .shadow(color: Color.shadowBlack, radius: 10)
                    }
                    
                    // Average Consumption with neon glow
                    if let avg = appData.averageConsumption {
                        VStack {
                            Text("\(avg.formatted(to: 1))")
                                .font(.system(size: 80, weight: .black, design: .rounded))
                                .foregroundColor(.goldenNeon)
                                .shadow(color: Color.goldenNeon, radius: 10, x: 0, y: 0)
                                .shadow(color: Color.goldenNeon.opacity(0.5), radius: 20, x: 0, y: 0)
                            
                            HStack {
                                Image(systemName: (appData.consumptionTrend ?? 0) > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .font(.title)
                                    .foregroundColor((appData.consumptionTrend ?? 0) > 0 ? .red : .green)
                                Text(appData.settings.consumptionUnit)
                                    .font(.subheadline)
                                    .foregroundColor(Color.turquoiseLight)
                            }
                        }
                    }
                    
                    // Dynamics Block with actual mini-graph
                    VStack(alignment: .leading) {
                        Text("Weekly Consumption")
                            .font(.headline)
                            .foregroundColor(.turquoiseLight)
                            .shadow(color: Color.turquoiseLight.opacity(0.4), radius: 3)
                        
                        LineChart(data: appData.weeklyConsumption, color: .goldenNeon)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.shadowBlack.cornerRadius(12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.goldenNeon.opacity(0.2)))
                    }
                    .padding(.horizontal)
                    
                    // Quick Buttons with gradients and shadows
                    VStack(spacing: 16) {
                        NavigationLink(destination: AddRefuelView()) {
                            Text("Add Refuel")
                                .font(.title3.bold())
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background(LinearGradient(gradient: Gradient(colors: [.goldenNeon, .orangeGloss]), startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(15)
                                .shadow(color: Color.goldenNeon.opacity(0.6), radius: 8)
                        }
                        
                        NavigationLink(destination: RefuelsLogView()) {
                            Text("All Refuels")
                                .font(.title3.bold())
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background(LinearGradient(gradient: Gradient(colors: [.turquoiseLight, .purpleNeon]), startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(15)
                                .shadow(color: Color.turquoiseLight.opacity(0.6), radius: 8)
                        }
                        
                        NavigationLink(destination: StatisticsView()) {
                            Text("Statistics")
                                .font(.title3.bold())
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background(LinearGradient(gradient: Gradient(colors: [.orangeGloss, .goldenNeon]), startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(15)
                                .shadow(color: Color.orangeGloss.opacity(0.6), radius: 8)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Fuel Track Hero")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.purpleNeon)
                    }
                }
            }
            .background(
                LinearGradient(gradient: Gradient(colors: [.asphaltBlack, .shadowBlack]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .overlay(
                Image(systemName: "leaf.fill")
                    .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.whiteHighlight, .goldenNeon.opacity(0.5)]), startPoint: .top, endPoint: .bottom))
                    .font(.system(size: 24))
                    .offset(y: featherOffset)
                    .rotationEffect(.degrees(featherRotation))
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                            featherOffset = 50
                            featherRotation = 15
                        }
                    }
                    .position(x: 40, y: 100)
            )
            .overlay(
                Image(systemName: "pawprint.fill")
                    .foregroundColor(.purpleNeon.opacity(0.2))
                    .font(.system(size: 80))
                    .position(x: UIScreen.main.bounds.width - 60, y: UIScreen.main.bounds.height - 150)
            )
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppData())
}
