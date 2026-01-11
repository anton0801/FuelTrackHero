import SwiftUI

struct AddRefuelView: View {
    @EnvironmentObject var appData: AppData
    @Environment(\.presentationMode) var presentationMode
    @State private var liters: String = ""
    @State private var pricePerLiter: String = ""
    @State private var totalAmount: String = ""
    @State private var mileage: String = ""
    @State private var fuelType: String = "Gasoline"
    @State private var gasStationId: UUID?
    @State private var comment: String = ""
    @State private var canisterRotation: Double = 0
    @State private var canisterTilt: Double = 0
    @State private var showFeather: Bool = false
    @State private var errorMessage: String?
    
    var calculatedTotal: Double {
        (Double(liters) ?? 0) * (Double(pricePerLiter) ?? 0)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Refuel Details").font(.headline).foregroundColor(.purpleNeon)) {
                    HStack {
                        Text("Liters")
                        TextField("0.0", text: $liters)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: liters) { _ in animateCanister() }
                    }
                    HStack {
                        Text("Price per Liter")
                        TextField("0.00", text: $pricePerLiter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: pricePerLiter) { _ in animateCanister() }
                    }
                    HStack {
                        Text("Total Amount")
                        TextField("0.00", text: $totalAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .background(calculatedTotal != (Double(totalAmount) ?? 0) ? Color.red.opacity(0.3) : Color.clear)
                            .cornerRadius(8)
                    }
                    HStack {
                        Text("Mileage")
                        TextField("0", text: $mileage)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Fuel Type", selection: $fuelType) {
                        Text("Gasoline").tag("Gasoline")
                        Text("Diesel").tag("Diesel")
                        Text("Electric").tag("Electric")
                    }
                    Picker("Gas Station", selection: $gasStationId) {
                        Text("Select Station").tag(UUID?.none)
                        ForEach(appData.gasStations) { station in
                            Text(station.name).tag(station.id as UUID?)
                        }
                    }
                    TextField("Comment (optional)", text: $comment)
                }
                .listRowBackground(Color.shadowBlack)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
            }
            .navigationTitle("Add Refuel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveRefuel()
                    }
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.goldenNeon, Color.orangeGloss]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(10)
                    .shadow(color: Color.goldenNeon.opacity(0.7), radius: 6)
                }
            }
            .background(Color.asphaltBlack.ignoresSafeArea())
            .overlay(
                            Image(systemName: "fuelpump.circle.fill")
                                .resizable()
                                .frame(width: 80, height: 80)
                                .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.metalGray, Color.whiteHighlight]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .rotationEffect(.degrees(canisterRotation))
                                .rotation3DEffect(.degrees(canisterTilt), axis: (x: 0, y: 1, z: 0))
                                .shadow(color: Color.shadowBlack, radius: 10)
                                .position(x: UIScreen.main.bounds.width / 2, y: 80)
                                .onAppear {
                                    withAnimation(Animation.easeInOut(duration: 5).repeatForever(autoreverses: false)) {
                                        canisterRotation += 360
                                    }
                                }
                        )
                        .overlay(
                            Group {
                                if showFeather {
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.goldenNeon)
                                        .shadow(color: .goldenNeon, radius: 5)
                                        .offset(y: -200)
                                        .transition(.scale.combined(with: .opacity))
                                        .animation(.easeOut(duration: 1))
                                }
                            },
                            alignment: .center
                        )
        }
        .navigationViewStyle(.stack)
    }
    
    private func animateCanister() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            canisterTilt = 15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                canisterTilt = -15
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                canisterTilt = 0
            }
        }
    }
    
    private func saveRefuel() {
        guard let litersD = Double(liters), let priceD = Double(pricePerLiter),
              let totalD = Double(totalAmount), let mileageD = Double(mileage) else {
            errorMessage = "Invalid input"
            return
        }
        
        if let lastMileage = appData.lastRefuel?.mileage, mileageD < lastMileage {
            errorMessage = "Mileage cannot be less than previous"
            return
        }
        
        let newRefuel = Refuel(liters: litersD, pricePerLiter: priceD, totalAmount: totalD, mileage: mileageD, fuelType: fuelType, gasStationId: gasStationId, comment: comment, date: Date())
        appData.refuels.append(newRefuel)
        
        withAnimation {
            showFeather = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    AddRefuelView()
}
