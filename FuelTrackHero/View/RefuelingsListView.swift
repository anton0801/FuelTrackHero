import SwiftUI
import WebKit

struct RefuelingsListView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @State private var showingAddRefueling = false
    @State private var selectedRefueling: Refueling?
    
    var body: some View {
        NavigationView {
            ZStack {
                AsphaltBackground()
                
                if firebaseService.refuelings.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.circle")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "#FF8A1F").opacity(0.5))
                        
                        Text("No Refuelings Yet")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Add your first refueling to start tracking")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        
                        Button(action: { showingAddRefueling = true }) {
                            Text("Add Refueling")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#1E1E1E"))
                                .padding(.horizontal, 30)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#FFD84A"), Color(hex: "#FF8A1F")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(firebaseService.refuelings) { refueling in
                                RefuelingCard(refueling: refueling)
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        selectedRefueling = refueling
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteRefueling(refueling)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Refuelings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRefueling = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#FFD84A"))
                    }
                }
            }
            .sheet(isPresented: $showingAddRefueling) {
                AddRefuelingView()
            }
        }
    }
    
    private func deleteRefueling(_ refueling: Refueling) {
        firebaseService.deleteRefueling(refueling) { success in
            if success {
                HapticFeedback.notification(type: .success)
            }
        }
    }
}

struct RefuelingCard: View {
    let refueling: Refueling
    @EnvironmentObject var firebaseService: FirebaseService
    
    var gasStation: GasStation? {
        guard let stationId = refueling.gasStationId else { return nil }
        return firebaseService.gasStations.first { $0.id == stationId }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Date badge
            VStack(spacing: 4) {
                Text(Calendar.current.component(.day, from: refueling.date), format: .number)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#FFD84A"))
                
                Text(refueling.date, format: .dateTime.month(.abbreviated))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#2A2A2A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#FFD84A").opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(refueling.liters.formatted(digits: 1)) L")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let consumption = refueling.consumption {
                        Text("• \(consumption.formatted(digits: 1)) L/100km")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "#3ED4C9"))
                    }
                }
                
                HStack {
                    Text("€\(refueling.pricePerLiter.formatted(digits: 2))/L")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("• €\(refueling.totalCost.formatted(digits: 2))")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let station = gasStation {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#C7C7C7"))
                        
                        Text(station.name)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            Spacer()
            
            // Small paw print
            PawPrintView(opacity: 0.15, size: 24)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#2A2A2A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}


struct InterfaceRenderer: UIViewRepresentable {
    
    let targetURL: URL
    
    @StateObject private var manager = RenderingManager()
    
    func makeCoordinator() -> RenderingDelegate {
        RenderingDelegate(manager: manager)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        manager.createPrimaryInterface()
        manager.primaryInterface.uiDelegate = context.coordinator
        manager.primaryInterface.navigationDelegate = context.coordinator
        
        manager.persistenceManager.loadSessions()
        manager.primaryInterface.load(URLRequest(url: targetURL))
        
        return manager.primaryInterface
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
