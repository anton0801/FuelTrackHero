import Foundation
import Firebase
import FirebaseAuth
import FirebaseDatabase
import Combine
import AppsFlyerLib
import Foundation

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    private let database = Database.database().reference()
    private var userId: String = ""
    
    @Published var refuelings: [Refueling] = []
    @Published var gasStations: [GasStation] = []
    @Published var reminders: [FuelReminder] = []
    @Published var settings: UserSettings = UserSettings()
    
    private var refuelingsHandle: DatabaseHandle?
    private var gasStationsHandle: DatabaseHandle?
    private var remindersHandle: DatabaseHandle?
    
    private init() {
        authenticateAnonymously()
    }
    
    // MARK: - Authentication
    private func authenticateAnonymously() {
        Auth.auth().signInAnonymously { [weak self] result, error in
            if let error = error {
                print("Anonymous auth failed: \(error.localizedDescription)")
                return
            }
            
            if let userId = result?.user.uid {
                self?.userId = userId
                self?.observeData()
            }
        }
    }
    
    // MARK: - Observe Data
    private func observeData() {
        observeRefuelings()
        observeGasStations()
        observeReminders()
        loadSettings()
    }
    
    // MARK: - Refuelings
    private func observeRefuelings() {
        let ref = database.child("users").child(userId).child("refuelings")
        
        refuelingsHandle = ref.observe(.value) { [weak self] snapshot in
            var newRefuelings: [Refueling] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let refueling = Refueling(snapshot: childSnapshot) {
                    newRefuelings.append(refueling)
                }
            }
            
            // Sort by date descending
            newRefuelings.sort { $0.date > $1.date }
            
            // Calculate consumption
            newRefuelings = self?.calculateConsumption(for: newRefuelings) ?? []
            
            DispatchQueue.main.async {
                self?.refuelings = newRefuelings
            }
        }
    }
    
    func addRefueling(_ refueling: Refueling, completion: @escaping (Bool) -> Void) {
        let ref = database.child("users").child(userId).child("refuelings").child(refueling.id)
        
        // Validate data before saving to prevent NaN errors
        let validatedDict = validateDictionary(refueling.dictionary)
        
        ref.setValue(validatedDict) { error, _ in
            if let error = error {
                print("Error adding refueling: \(error.localizedDescription)")
                completion(false)
            } else {
                // Update gas station statistics
                if let stationId = refueling.gasStationId {
                    self.updateGasStationStats(stationId: stationId)
                }
                completion(true)
            }
        }
    }
    
    // Validate dictionary to remove NaN and Infinity values
    private func validateDictionary(_ dict: [String: Any]) -> [String: Any] {
        var validatedDict: [String: Any] = [:]
        
        for (key, value) in dict {
            if let doubleValue = value as? Double {
                // Check for NaN or Infinity
                if doubleValue.isNaN || doubleValue.isInfinite {
                    validatedDict[key] = 0.0
                } else {
                    validatedDict[key] = doubleValue
                }
            } else {
                validatedDict[key] = value
            }
        }
        
        return validatedDict
    }
    
    func updateRefueling(_ refueling: Refueling, completion: @escaping (Bool) -> Void) {
        let ref = database.child("users").child(userId).child("refuelings").child(refueling.id)
        
        ref.updateChildValues(refueling.dictionary) { error, _ in
            completion(error == nil)
        }
    }
    
    func deleteRefueling(_ refueling: Refueling, completion: @escaping (Bool) -> Void) {
        let ref = database.child("users").child(userId).child("refuelings").child(refueling.id)
        
        ref.removeValue { error, _ in
            if error == nil, let stationId = refueling.gasStationId {
                self.updateGasStationStats(stationId: stationId)
            }
            completion(error == nil)
        }
    }
    
    private func calculateConsumption(for refuelings: [Refueling]) -> [Refueling] {
        var updatedRefuelings = refuelings
        
        for i in 0..<updatedRefuelings.count {
            if i < updatedRefuelings.count - 1 {
                let current = updatedRefuelings[i]
                let previous = updatedRefuelings[i + 1]
                
                let distance = current.odometer - previous.odometer
                if distance > 0 {
                    // L/100km
                    let consumption = (previous.liters / distance) * 100
                    updatedRefuelings[i].consumption = consumption
                }
            }
        }
        
        return updatedRefuelings
    }
    
    // MARK: - Gas Stations
    private func observeGasStations() {
        let ref = database.child("users").child(userId).child("gasStations")
        
        gasStationsHandle = ref.observe(.value) { [weak self] snapshot in
            var stations: [GasStation] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let station = GasStation(snapshot: childSnapshot) {
                    stations.append(station)
                }
            }
            
            DispatchQueue.main.async {
                self?.gasStations = stations.sorted { $0.name < $1.name }
            }
        }
    }
    
    func addGasStation(_ station: GasStation, completion: @escaping (Bool) -> Void) {
        let ref = database.child("users").child(userId).child("gasStations").child(station.id)
        
        ref.setValue(station.dictionary) { error, _ in
            completion(error == nil)
        }
    }
    
    func updateGasStation(_ station: GasStation, completion: @escaping (Bool) -> Void) {
        let ref = database.child("users").child(userId).child("gasStations").child(station.id)
        
        let validatedDict = validateDictionary(station.dictionary)
        
        ref.updateChildValues(validatedDict) { error, _ in
            completion(error == nil)
        }
    }
    
    func deleteGasStation(_ station: GasStation, completion: @escaping (Bool) -> Void) {
        let ref = database.child("users").child(userId).child("gasStations").child(station.id)
        
        ref.removeValue { error, _ in
            completion(error == nil)
        }
    }
    
    private func updateGasStationStats(stationId: String) {
        let stationRefuelings = refuelings.filter { $0.gasStationId == stationId }
        
        guard !stationRefuelings.isEmpty else { return }
        
        let avgPrice = stationRefuelings.map { $0.pricePerLiter }.reduce(0, +) / Double(stationRefuelings.count)
        let consumptions = stationRefuelings.compactMap { $0.consumption }
        let avgConsumption = consumptions.isEmpty ? 0.0 : consumptions.reduce(0, +) / Double(consumptions.count)
        
        // Validate values before updating
        let validAvgPrice = avgPrice.isNaN || avgPrice.isInfinite ? 0.0 : avgPrice
        let validAvgConsumption = avgConsumption.isNaN || avgConsumption.isInfinite ? 0.0 : avgConsumption
        
        let ref = database.child("users").child(userId).child("gasStations").child(stationId)
        ref.updateChildValues([
            "averagePrice": validAvgPrice,
            "averageConsumption": validAvgConsumption,
            "refuelingCount": stationRefuelings.count
        ])
    }
    
    // MARK: - Reminders
    private func observeReminders() {
        let ref = database.child("users").child(userId).child("reminders")
        
        remindersHandle = ref.observe(.value) { [weak self] snapshot in
            var newReminders: [FuelReminder] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let reminder = FuelReminder(snapshot: childSnapshot) {
                    newReminders.append(reminder)
                }
            }
            
            // If no reminders exist, create defaults
            if newReminders.isEmpty {
                self?.createDefaultReminders()
            } else {
                DispatchQueue.main.async {
                    self?.reminders = newReminders
                }
            }
        }
    }
    
    private func createDefaultReminders() {
        let defaultReminders = ReminderType.allCases.map { type in
            FuelReminder(type: type, isEnabled: false, threshold: type == .timeToRefuel ? 50 : nil)
        }
        
        for reminder in defaultReminders {
            let ref = database.child("users").child(userId).child("reminders").child(reminder.id)
            ref.setValue(reminder.dictionary)
        }
    }
    
    func updateReminder(_ reminder: FuelReminder, completion: @escaping (Bool) -> Void) {
        let ref = database.child("users").child(userId).child("reminders").child(reminder.id)
        
        ref.updateChildValues(reminder.dictionary) { error, _ in
            completion(error == nil)
        }
    }
    
    // MARK: - Settings
    private func loadSettings() {
        let ref = database.child("users").child(userId).child("settings")
        
        ref.observeSingleEvent(of: .value) { [weak self] snapshot in
            if let value = snapshot.value as? [String: Any] {
                if let unitRaw = value["consumptionUnit"] as? String,
                   let unit = ConsumptionUnit(rawValue: unitRaw) {
                    self?.settings.consumptionUnit = unit
                }
                if let currency = value["currency"] as? String {
                    self?.settings.currency = currency
                }
                if let isDark = value["isDarkMode"] as? Bool {
                    self?.settings.isDarkMode = isDark
                }
            } else {
                // Save default settings
                self?.saveSettings(self?.settings ?? UserSettings())
            }
        }
    }
    
    func saveSettings(_ settings: UserSettings) {
        let ref = database.child("users").child(userId).child("settings")
        
        ref.setValue(settings.dictionary) { [weak self] error, _ in
            if error == nil {
                DispatchQueue.main.async {
                    self?.settings = settings
                }
            }
        }
    }
    
    // MARK: - Statistics
    func getStatistics() -> FuelStatistics {
        guard !refuelings.isEmpty else {
            return FuelStatistics(
                averageConsumption: 0,
                averagePricePerLiter: 0,
                totalSpent: 0,
                totalLiters: 0,
                totalDistance: 0,
                bestWeekConsumption: 0,
                worstWeekConsumption: 0,
                trend: .stable
            )
        }
        
        let consumptions = refuelings.compactMap { $0.consumption }
        let avgConsumption = consumptions.isEmpty ? 0 : consumptions.reduce(0, +) / Double(consumptions.count)
        
        let avgPrice = refuelings.map { $0.pricePerLiter }.reduce(0, +) / Double(refuelings.count)
        let totalSpent = refuelings.map { $0.totalCost }.reduce(0, +)
        let totalLiters = refuelings.map { $0.liters }.reduce(0, +)
        
        let odometerValues = refuelings.map { $0.odometer }.sorted()
        let totalDistance = odometerValues.last ?? 0 - (odometerValues.first ?? 0)
        
        // Calculate trend
        let recentConsumptions = Array(consumptions.prefix(5))
        let olderConsumptions = Array(consumptions.suffix(5))
        
        let recentAvg = recentConsumptions.isEmpty ? 0 : recentConsumptions.reduce(0, +) / Double(recentConsumptions.count)
        let olderAvg = olderConsumptions.isEmpty ? 0 : olderConsumptions.reduce(0, +) / Double(olderConsumptions.count)
        
        let trend: FuelStatistics.ConsumptionTrend
        if recentAvg < olderAvg - 0.5 {
            trend = .improving
        } else if recentAvg > olderAvg + 0.5 {
            trend = .worsening
        } else {
            trend = .stable
        }
        
        let bestWeek = consumptions.min() ?? 0
        let worstWeek = consumptions.max() ?? 0
        
        return FuelStatistics(
            averageConsumption: avgConsumption,
            averagePricePerLiter: avgPrice,
            totalSpent: totalSpent,
            totalLiters: totalLiters,
            totalDistance: totalDistance,
            bestWeekConsumption: bestWeek,
            worstWeekConsumption: worstWeek,
            trend: trend
        )
    }
    
    // MARK: - Cleanup
    deinit {
        if let handle = refuelingsHandle {
            database.child("users").child(userId).child("refuelings").removeObserver(withHandle: handle)
        }
        if let handle = gasStationsHandle {
            database.child("users").child(userId).child("gasStations").removeObserver(withHandle: handle)
        }
        if let handle = remindersHandle {
            database.child("users").child(userId).child("reminders").removeObserver(withHandle: handle)
        }
    }
}

enum ApplicationPhase: Equatable {
    case idle
    case launching
    case validating
    case verified
    case running(url: String)
    case halted
    case offline
}

protocol PhaseCommand {
    func execute(current: ApplicationPhase, machine: PhaseMachine) async -> ApplicationPhase?
}

final class PhaseMachine: ObservableObject {
    
    @Published private(set) var currentPhase: ApplicationPhase = .idle
    @Published private(set) var snapshots: [PhaseSnapshot] = []
    
    private var commandQueue: [PhaseCommand] = []
    private var isSealed = false
    
    func enqueue(_ command: PhaseCommand) {
        Task {
            await processCommand(command)
        }
    }
    
    private func processCommand(_ command: PhaseCommand) async {
        guard !isSealed else { return }
        
        if let nextPhase = await command.execute(current: currentPhase, machine: self) {
            createSnapshot(from: currentPhase, to: nextPhase, command: command)
            currentPhase = nextPhase
            
            if nextPhase.isSealed {
                isSealed = true
            }
        }
    }
    
    private func createSnapshot(from: ApplicationPhase, to: ApplicationPhase, command: PhaseCommand) {
        let snapshot = PhaseSnapshot(
            from: from,
            to: to,
            commandType: String(describing: type(of: command)),
            timestamp: Date()
        )
        snapshots.append(snapshot)
    }
}

struct PhaseSnapshot {
    let from: ApplicationPhase
    let to: ApplicationPhase
    let commandType: String
    let timestamp: Date
}

extension ApplicationPhase {
    var isSealed: Bool {
        switch self {
        case .running, .halted:
            return true
        default:
            return false
        }
    }
}

struct LaunchCommand: PhaseCommand {
    
    func execute(current: ApplicationPhase, machine: PhaseMachine) async -> ApplicationPhase? {
        guard current == .idle else { return nil }
        return .launching
    }
}

struct ValidateCommand: PhaseCommand {
    
    let validator: GateValidator
    
    init(validator: GateValidator = FirebaseGate()) {
        self.validator = validator
    }
    
    func execute(current: ApplicationPhase, machine: PhaseMachine) async -> ApplicationPhase? {
        guard current == .launching else { return nil }
        
        do {
            let isValid = try await validator.validate()
            return isValid ? .verified : .halted
        } catch {
            return .halted
        }
    }
}

struct ActivateCommand: PhaseCommand {
    
    let url: String
    
    func execute(current: ApplicationPhase, machine: PhaseMachine) async -> ApplicationPhase? {
        guard current == .verified || current == .launching else {
            return nil
        }
        return .running(url: url)
    }
}

struct DisconnectCommand: PhaseCommand {
    
    func execute(current: ApplicationPhase, machine: PhaseMachine) async -> ApplicationPhase? {
        guard !current.isSealed else { return nil }
        return .offline
    }
}

struct ReconnectCommand: PhaseCommand {
    
    func execute(current: ApplicationPhase, machine: PhaseMachine) async -> ApplicationPhase? {
        guard current == .offline else { return nil }
        return .halted
    }
}

struct ExpireCommand: PhaseCommand {
    
    func execute(current: ApplicationPhase, machine: PhaseMachine) async -> ApplicationPhase? {
        guard !current.isSealed else { return nil }
        return .halted
    }
}

protocol GateValidator {
    func validate() async throws -> Bool
}

final class FirebaseGate: GateValidator {
    
    private let path = "users/log/data"
    
    func validate() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            Database.database().reference().child(path)
                .observeSingleEvent(of: .value) { snapshot in
                    if let urlString = snapshot.value as? String,
                       !urlString.isEmpty,
                       URL(string: urlString) != nil {
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                } withCancel: { error in
                    continuation.resume(throwing: error)
                }
        }
    }
}

enum ValidationError: Error {
    case gateClosed
    case gateFailure
}
