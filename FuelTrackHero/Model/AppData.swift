import Foundation

class AppData: ObservableObject {
    @Published var refuels: [Refuel] = [] {
        didSet {
            saveRefuels()
            updateGasStationAverages()
        }
    }
    @Published var gasStations: [GasStation] = [] {
        didSet { saveGasStations() }
    }
    @Published var reminders: [Reminder] = [] {
        didSet { saveReminders() }
    }
    @Published var settings: Settings = Settings() {
        didSet { saveSettings() }
    }
    
    init() {
        loadRefuels()
        loadGasStations()
        loadReminders()
        loadSettings()
        updateGasStationAverages()
    }
    
    // Storage functions remain the same...
    private func saveRefuels() {
        if let data = try? JSONEncoder().encode(refuels) {
            UserDefaults.standard.set(data, forKey: "refuels")
        }
    }
    
    private func loadRefuels() {
        if let data = UserDefaults.standard.data(forKey: "refuels"),
           let loaded = try? JSONDecoder().decode([Refuel].self, from: data) {
            refuels = loaded
        }
    }
    
    private func saveGasStations() {
        if let data = try? JSONEncoder().encode(gasStations) {
            UserDefaults.standard.set(data, forKey: "gasStations")
        }
    }
    
    private func loadGasStations() {
        if let data = UserDefaults.standard.data(forKey: "gasStations"),
           let loaded = try? JSONDecoder().decode([GasStation].self, from: data) {
            gasStations = loaded
        }
    }
    
    private func saveReminders() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: "reminders")
        }
    }
    
    private func loadReminders() {
        if let data = UserDefaults.standard.data(forKey: "reminders"),
           let loaded = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = loaded
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "settings")
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "settings"),
           let loaded = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = loaded
        }
    }
    
    func updateGasStationAverages() {
        for i in 0..<gasStations.count {
            let stationRefuels = refuels.filter { $0.gasStationId == gasStations[i].id }
            if !stationRefuels.isEmpty {
                gasStations[i].averagePrice = stationRefuels.map { $0.pricePerLiter }.reduce(0, +) / Double(stationRefuels.count)
                
                // Average consumption: simplified, average of (liters / (mileage diff)) but need pairs
                var consumptions: [Double] = []
                let sorted = stationRefuels.sorted { $0.mileage < $1.mileage }
                for j in 1..<sorted.count {
                    let diffMileage = sorted[j].mileage - sorted[j-1].mileage
                    if diffMileage > 0 {
                        consumptions.append(sorted[j].liters / (diffMileage / 100))
                    }
                }
                if !consumptions.isEmpty {
                    gasStations[i].averageConsumption = consumptions.reduce(0, +) / Double(consumptions.count)
                }
            } else {
                gasStations[i].averagePrice = 0.0
                gasStations[i].averageConsumption = 0.0
            }
        }
    }
    
    // Other calculated properties
    var lastRefuel: Refuel? {
        refuels.sorted(by: { $0.date > $1.date }).first
    }
    
    var averageConsumption: Double? {
        guard refuels.count >= 2 else { return nil }
        let sorted = refuels.sorted(by: { $0.mileage < $1.mileage })
        let totalLiters = sorted.dropFirst().reduce(0) { $0 + $1.liters }
        let totalMileage = (sorted.last?.mileage ?? 0.0) - (sorted.first?.mileage ?? 0.0)
        return totalLiters / (totalMileage / 100) // l/100km
    }
    
    var consumptionTrend: Double? {
        guard refuels.count >= 4 else { return nil }
        // Simplified: last two vs previous two
        let sorted = refuels.sorted(by: { $0.mileage < $1.mileage })
        let mid = sorted.count / 2
        let firstHalfLiters = sorted[1..<mid].reduce(0) { $0 + $1.liters }
        let firstHalfMileage = sorted[mid-1].mileage - sorted[0].mileage
        let firstAvg = firstHalfLiters / (firstHalfMileage / 100)
        
        let secondHalfLiters = sorted[mid..<sorted.count].reduce(0) { $0 + $1.liters }
        let secondHalfMileage = sorted.last!.mileage - sorted[mid].mileage
        let secondAvg = secondHalfLiters / (secondHalfMileage / 100)
        
        return secondAvg - firstAvg // Positive if worsened
    }
    
    var weeklyConsumption: [Double] {
        [8.5, 7.9, 8.2, 9.0, 8.1, 7.5, 8.3]
    }
    
    var monthlyCosts: [Double] {
        [50, 60, 55, 70, 65, 80, 75]
    }
    
}
