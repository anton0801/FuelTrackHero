import SwiftUI

struct RefuelsLogView: View {
    @EnvironmentObject var appData: AppData
    @State private var filterMonth: String = ""
    
    var filteredRefuels: [Refuel] {
        appData.refuels // Add real filtering if needed
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredRefuels) { refuel in
                    HStack(spacing: 16) {
                        if let station = appData.gasStations.first(where: { $0.id == refuel.gasStationId }) {
                            Image(systemName: station.logo)
                                .font(.title2)
                                .foregroundColor(.metalGray)
                                .frame(width: 40)
                        } else {
                            Image(systemName: "questionmark.circle")
                                .font(.title2)
                                .foregroundColor(.metalGray)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(refuel.liters.formatted(to: 1)) L at \(refuel.pricePerLiter.formatted(to: 2)) \(appData.settings.currency)/L")
                                .font(.headline)
                                .foregroundColor(.goldenNeon)
                            Text("Total: \(refuel.totalAmount.formatted(to: 2)) \(appData.settings.currency)")
                                .font(.subheadline)
                                .foregroundColor(.turquoiseLight)
                            Text("Mileage: \(refuel.mileage.formatted(to: 0)) km")
                                .font(.subheadline)
                                .foregroundColor(.turquoiseLight)
                            Text(refuel.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.whiteHighlight)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.purpleNeon)
                            .shadow(color: .purpleNeon, radius: 2)
                    }
                    .padding(12)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [.asphaltBlack, .shadowBlack]), startPoint: .top, endPoint: .bottom)
                            .cornerRadius(15)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.metalGray.opacity(0.2)))
                    .shadow(color: Color.shadowBlack, radius: 5)
                }
                .onDelete { indices in
                    appData.refuels.remove(atOffsets: indices)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Duplicate") {
                        // Implement duplicate logic
                        if let firstRefuel = filteredRefuels.first {
                            if let index = appData.refuels.firstIndex(where: { $0.id == firstRefuel.id }) {
                                let dup = appData.refuels[index]
                                appData.refuels.append(Refuel(liters: dup.liters, pricePerLiter: dup.pricePerLiter, totalAmount: dup.totalAmount, mileage: dup.mileage, fuelType: dup.fuelType, gasStationId: dup.gasStationId, comment: dup.comment, date: Date()))
                            }
                        }
                    }
                    .tint(.orangeGloss)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Refuels Log")
            .toolbar {
                NavigationLink(destination: AddRefuelView()) {
                    Text("Add")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(LinearGradient(gradient: Gradient(colors: [.goldenNeon, .orangeGloss]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .cornerRadius(10)
                        .shadow(color: .goldenNeon.opacity(0.5), radius: 5)
                }
            }
            .searchable(text: $filterMonth, prompt: "Filter by month, price, etc.")
            .background(Color.asphaltBlack.ignoresSafeArea())
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    RefuelsLogView()
}
