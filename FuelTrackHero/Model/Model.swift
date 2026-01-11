import SwiftUI

struct Refuel: Codable, Identifiable {
    let id: UUID = UUID()
    var liters: Double
    var pricePerLiter: Double
    var totalAmount: Double
    var mileage: Double
    var fuelType: String
    var gasStationId: UUID? // Link to GasStation ID
    var comment: String?
    var date: Date
}

struct GasStation: Codable, Identifiable, Hashable, Equatable {
    let id: UUID = UUID()
    var name: String
    var logo: String // SF Symbol
    var averagePrice: Double = 0.0
    var averageConsumption: Double = 0.0
    
    static func == (lhs: GasStation, rhs: GasStation) -> Bool {
        lhs.id == rhs.id
    }
    
    
}

struct Reminder: Codable, Identifiable {
    let id: UUID = UUID()
    var type: String
    var threshold: Double?
    var isEnabled: Bool
}

struct Settings: Codable {
    var consumptionUnit: String = "l/100km"
    var currency: String = "USD"
    var theme: String = "neon"
}
