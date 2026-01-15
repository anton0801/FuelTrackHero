import SwiftUI

struct GasStationsView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @State private var showingAddStation = false
    @State private var newStationName = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AsphaltBackground()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(firebaseService.gasStations) { station in
                            GasStationCard(station: station)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Gas Stations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddStation = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#3ED4C9"))
                    }
                }
            }
            .sheet(isPresented: $showingAddStation) {
                AddGasStationView()
            }
        }
    }
}

struct GasStationCard: View {
    let station: GasStation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: station.logo)
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "#3ED4C9"))
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(Color(hex: "#2A2A2A"))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(station.refuelingCount) refuelings")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg. Price")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("€\(station.averagePrice.formatted(digits: 2))/L")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#FFD84A"))
                }
                
                if station.averageConsumption > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avg. Consumption")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("\(station.averageConsumption.formatted(digits: 1)) L/100km")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#3ED4C9"))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#2A2A2A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#3ED4C9").opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct AddGasStationView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var firebaseService: FirebaseService
    @State private var stationName = ""
    @State private var selectedIcon = "fuelpump.circle.fill"
    
    let availableIcons = [
        "fuelpump.circle.fill",
        "mappin.circle.fill",
        "flag.circle.fill",
        "star.circle.fill",
        "bolt.circle.fill"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Station Details")) {
                    TextField("Station Name", text: $stationName)
                }
                
                Section(header: Text("Icon")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 32))
                                        .foregroundColor(selectedIcon == icon ? Color(hex: "#3ED4C9") : .gray)
                                        .frame(width: 50, height: 50)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Add Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveStation()
                    }
                    .disabled(stationName.isEmpty)
                }
            }
        }
    }
    
    private func saveStation() {
        let station = GasStation(name: stationName, logo: selectedIcon)
        firebaseService.addGasStation(station) { success in
            if success {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
