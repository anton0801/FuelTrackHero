import SwiftUI

struct GasStationsView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingAddSheet = false
    @State private var newName: String = ""
    @State private var newLogo: String = "fuelpump.circle"
    @State private var editingStation: GasStation?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(appData.gasStations) { station in
                    HStack(spacing: 16) {
                        Image(systemName: station.logo)
                            .font(.title)
                            .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.metalGray, .whiteHighlight]), startPoint: .top, endPoint: .bottom))
                            .shadow(color: Color.shadowBlack, radius: 3)
                        
                        VStack(alignment: .leading) {
                            Text(station.name)
                                .font(.headline)
                                .foregroundColor(.purpleNeon)
                            Text("Avg Price: \(station.averagePrice.formatted(to: 2)) \(appData.settings.currency)")
                                .font(.subheadline)
                                .foregroundColor(.orangeGloss)
                            Text("Avg Cons: \(station.averageConsumption.formatted(to: 1)) \(appData.settings.consumptionUnit)")
                                .font(.subheadline)
                                .foregroundColor(.goldenNeon)
                        }
                    }
                    .padding(12)
                    .background(Color.shadowBlack.cornerRadius(15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.turquoiseLight.opacity(0.2)))
                    .onTapGesture {
                        editingStation = station
                        newName = station.name
                        newLogo = station.logo
                        showingAddSheet = true
                    }
                }
                .onDelete { indices in
                    appData.gasStations.remove(atOffsets: indices)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Gas Stations")
            .toolbar {
                            Button("Add") {
                                editingStation = nil
                                newName = ""
                                newLogo = "fuelpump.circle"
                                showingAddSheet = true
                            }
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(LinearGradient(gradient: Gradient(colors: [.turquoiseLight, .purpleNeon]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(10)
                            .shadow(color: .turquoiseLight.opacity(0.7), radius: 6)
                        }
            .background(Color.asphaltBlack.ignoresSafeArea())
            .sheet(isPresented: $showingAddSheet) {
                VStack(spacing: 20) {
                    Text(editingStation == nil ? "Add Gas Station" : "Edit Gas Station")
                        .font(.title2)
                        .foregroundColor(.purpleNeon)
                    
                    TextField("Name", text: $newName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Logo", selection: $newLogo) {
                        Image(systemName: "fuelpump.circle").tag("fuelpump.circle")
                        Image(systemName: "fuelpump.fill").tag("fuelpump.fill")
                        Image(systemName: "bolt.car.fill").tag("bolt.car.fill")
                        // Add more SF symbols
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                    
                    Button(editingStation == nil ? "Add" : "Save") {
                        if let editing = editingStation,
                           let index = appData.gasStations.firstIndex(where: { $0.id == editing.id }) {
                            appData.gasStations[index].name = newName
                            appData.gasStations[index].logo = newLogo
                        } else {
                            appData.gasStations.append(GasStation(name: newName, logo: newLogo))
                        }
                        showingAddSheet = false
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.turquoiseLight)
                    .cornerRadius(10)
                    .shadow(color: .turquoiseLight.opacity(0.5), radius: 5)
                }
                .padding()
                .background(Color.asphaltBlack)
            }
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    GasStationsView()
}
