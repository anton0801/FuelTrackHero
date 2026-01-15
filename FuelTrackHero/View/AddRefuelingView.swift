import SwiftUI

struct AddRefuelingView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var firebaseService: FirebaseService
    
    @State private var liters: String = ""
    @State private var pricePerLiter: String = ""
    @State private var totalCost: String = ""
    @State private var odometer: String = ""
    @State private var selectedFuelType: FuelType = .gasoline95
    @State private var selectedStation: GasStation?
    @State private var comment: String = ""
    @State private var date: Date = Date()
    
    @State private var showingStationPicker = false
    @State private var canTilt: Double = 0
    @State private var canFillLevel: Double = 0
    @State private var showingSaveAnimation = false
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var isFormValid: Bool {
        guard let litersVal = Double(liters), litersVal > 0,
              let priceVal = Double(pricePerLiter), priceVal > 0,
              let odometerVal = Double(odometer), odometerVal > 0 else {
            return false
        }
        
        // Check if odometer is greater than last refueling
        if let lastRefueling = firebaseService.refuelings.first {
            return odometerVal > lastRefueling.odometer
        }
        
        return true
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Animated fuel can
                    AnimatedFuelCan(
                        canTilt: $canTilt,
                        fillLevel: $canFillLevel,
                        showingSaveAnimation: showingSaveAnimation
                    )
                    .frame(height: 150)
                    .padding(.top, 20)
                    
                    // Form fields
                    VStack(spacing: 16) {
                        // Date picker
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "#FFD84A"))
                                .frame(width: 24)
                            
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .accentColor(Color(hex: "#FFD84A"))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "#2A2A2A"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "#FFD84A").opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        // Liters
                        NeonTextField(
                            icon: "drop.fill",
                            placeholder: "Liters",
                            text: $liters,
                            keyboardType: .decimalPad,
                            color: Color(hex: "#FFD84A")
                        )
                        .onChange(of: liters) { _ in
                            updateFillLevel()
                            calculateTotal()
                        }
                        
                        // Price per liter
                        NeonTextField(
                            icon: "eurosign.circle.fill",
                            placeholder: "Price per Liter (€)",
                            text: $pricePerLiter,
                            keyboardType: .decimalPad,
                            color: Color(hex: "#FF8A1F")
                        )
                        .onChange(of: pricePerLiter) { _ in
                            calculateTotal()
                        }
                        
                        // Total cost
                        NeonTextField(
                            icon: "banknote.fill",
                            placeholder: "Total Cost (€)",
                            text: $totalCost,
                            keyboardType: .decimalPad,
                            color: Color(hex: "#6B4CFF")
                        )
                        .onChange(of: totalCost) { _ in
                            if totalCost != calculatedTotal {
                                // User manually edited total
                            }
                        }
                        
                        // Odometer
                        NeonTextField(
                            icon: "speedometer",
                            placeholder: "Odometer (km)",
                            text: $odometer,
                            keyboardType: .decimalPad,
                            color: Color(hex: "#3ED4C9")
                        )
                        
                        // Fuel type picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fuel Type")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(FuelType.allCases, id: \.self) { type in
                                        FuelTypeButton(
                                            type: type,
                                            isSelected: selectedFuelType == type
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedFuelType = type
                                                HapticFeedback.selection()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Gas station selector
                        Button(action: { showingStationPicker = true }) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hex: "#C7C7C7"))
                                    .frame(width: 24)
                                
                                Text(selectedStation?.name ?? "Select Gas Station (Optional)")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(selectedStation == nil ? .white.opacity(0.5) : .white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#2A2A2A"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "#C7C7C7").opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Comment
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Comment (Optional)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            
                            TextEditor(text: $comment)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .frame(height: 80)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: "#2A2A2A"))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Save button
                    Button(action: saveRefueling) {
                        HStack {
                            if isSaving {
                                LoadingView(color: Color(hex: "#1E1E1E"))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                
                                Text("Save Refueling")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundColor(Color(hex: "#1E1E1E"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: isFormValid ? [Color(hex: "#FFD84A"), Color(hex: "#FF8A1F")] : [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: isFormValid ? Color(hex: "#FFD84A").opacity(0.4) : .clear, radius: 15, x: 0, y: 8)
                    }
                    .disabled(!isFormValid || isSaving)
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .background(AsphaltBackground())
            .navigationTitle("Add Refueling")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingStationPicker) {
                GasStationPickerView(selectedStation: $selectedStation)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var calculatedTotal: String {
        if let litersVal = Double(liters), let priceVal = Double(pricePerLiter) {
            return String(format: "%.2f", litersVal * priceVal)
        }
        return ""
    }
    
    private func calculateTotal() {
        if let litersVal = Double(liters), let priceVal = Double(pricePerLiter) {
            totalCost = String(format: "%.2f", litersVal * priceVal)
        }
    }
    
    private func updateFillLevel() {
        if let litersVal = Double(liters) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                canFillLevel = min(litersVal / 100.0, 1.0)
                canTilt = litersVal > 0 ? 5 : 0
            }
        }
    }
    
    private func saveRefueling() {
        guard isFormValid else { return }
        
        guard let litersVal = Double(liters),
              let priceVal = Double(pricePerLiter),
              let totalVal = Double(totalCost),
              let odometerVal = Double(odometer) else {
            return
        }
        
        isSaving = true
        HapticFeedback.impact()
        
        let refueling = Refueling(
            date: date,
            liters: litersVal,
            pricePerLiter: priceVal,
            totalCost: totalVal,
            odometer: odometerVal,
            fuelType: selectedFuelType,
            gasStationId: selectedStation?.id,
            comment: comment
        )
        
        // Show save animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            showingSaveAnimation = true
        }
        
        firebaseService.addRefueling(refueling) { success in
            isSaving = false
            
            if success {
                HapticFeedback.notification(type: .success)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    presentationMode.wrappedValue.dismiss()
                }
            } else {
                showingSaveAnimation = false
                errorMessage = "Failed to save refueling. Please try again."
                showingError = true
                HapticFeedback.notification(type: .error)
            }
        }
    }
}

// MARK: - Animated Fuel Can
struct AnimatedFuelCan: View {
    @Binding var canTilt: Double
    @Binding var fillLevel: Double
    let showingSaveAnimation: Bool
    
    @State private var rotation: Double = 0
    @State private var featherOffset: CGFloat = 0
    @State private var featherOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#FFD84A").opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 20)
            
            // Fuel can
            ZStack {
                // Can body
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FFD84A"), Color(hex: "#FF8A1F")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                    )
                
                // Fill level indicator
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        
                        Rectangle()
                            .fill(Color(hex: "#FF8A1F").opacity(0.6))
                            .frame(height: geometry.size.height * CGFloat(fillLevel))
                    }
                }
                .frame(width: 54, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .shadow(color: Color(hex: "#FFD84A").opacity(0.6), radius: 20)
            .rotation3DEffect(
                .degrees(canTilt),
                axis: (x: 0, y: 0, z: 1)
            )
            .rotationEffect(.degrees(rotation))
            
            // Flying feather on save
            if showingSaveAnimation {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#3ED4C9"))
                    .offset(y: featherOffset)
                    .opacity(featherOpacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.0)) {
                            featherOffset = -200
                            featherOpacity = 0
                        }
                    }
            }
        }
    }
}

// MARK: - Fuel Type Button
struct FuelTypeButton: View {
    let type: FuelType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(type.rawValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? Color(hex: "#1E1E1E") : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(hex: "#FFD84A") : Color(hex: "#2A2A2A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: isSelected ? Color(hex: "#FFD84A").opacity(0.4) : .clear, radius: 10)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Gas Station Picker
struct GasStationPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var firebaseService: FirebaseService
    @Binding var selectedStation: GasStation?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(firebaseService.gasStations) { station in
                    Button(action: {
                        selectedStation = station
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: station.logo)
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "#3ED4C9"))
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.name)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                if station.averagePrice > 0 {
                                    Text("Avg: €\(station.averagePrice.formatted(digits: 2))/L")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            
                            Spacer()
                            
                            if selectedStation?.id == station.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "#FFD84A"))
                            }
                        }
                    }
                }
                .listRowBackground(Color(hex: "#2A2A2A"))
            }
            .listStyle(InsetGroupedListStyle())
            .background(AsphaltBackground())
            .navigationTitle("Select Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFD84A"))
                }
            }
        }
    }
}
