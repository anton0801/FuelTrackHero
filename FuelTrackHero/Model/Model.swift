import Foundation
import FirebaseDatabase
import Combine

struct Refueling: Identifiable, Codable {
    var id: String
    var date: Date
    var liters: Double
    var pricePerLiter: Double
    var totalCost: Double
    var odometer: Double
    var fuelType: FuelType
    var gasStationId: String?
    var comment: String
    
    var consumption: Double?
    
    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        liters: Double,
        pricePerLiter: Double,
        totalCost: Double,
        odometer: Double,
        fuelType: FuelType,
        gasStationId: String? = nil,
        comment: String = ""
    ) {
        self.id = id
        self.date = date
        self.liters = liters
        self.pricePerLiter = pricePerLiter
        self.totalCost = totalCost
        self.odometer = odometer
        self.fuelType = fuelType
        self.gasStationId = gasStationId
        self.comment = comment
    }
    
    // Firebase dictionary representation
    var dictionary: [String: Any] {
        return [
            "id": id,
            "date": date.timeIntervalSince1970,
            "liters": liters,
            "pricePerLiter": pricePerLiter,
            "totalCost": totalCost,
            "odometer": odometer,
            "fuelType": fuelType.rawValue,
            "gasStationId": gasStationId ?? "",
            "comment": comment
        ]
    }
    
    // Initialize from Firebase snapshot
    init?(snapshot: DataSnapshot) {
        guard let value = snapshot.value as? [String: Any],
              let id = value["id"] as? String,
              let timestamp = value["date"] as? TimeInterval,
              let liters = value["liters"] as? Double,
              let pricePerLiter = value["pricePerLiter"] as? Double,
              let totalCost = value["totalCost"] as? Double,
              let odometer = value["odometer"] as? Double,
              let fuelTypeRaw = value["fuelType"] as? String,
              let fuelType = FuelType(rawValue: fuelTypeRaw)
        else {
            return nil
        }
        
        self.id = id
        self.date = Date(timeIntervalSince1970: timestamp)
        self.liters = liters
        self.pricePerLiter = pricePerLiter
        self.totalCost = totalCost
        self.odometer = odometer
        self.fuelType = fuelType
        self.gasStationId = value["gasStationId"] as? String
        self.comment = value["comment"] as? String ?? ""
    }
}

// MARK: - Fuel Type
enum FuelType: String, Codable, CaseIterable {
    case gasoline95 = "Gasoline 95"
    case gasoline98 = "Gasoline 98"
    case diesel = "Diesel"
    case electric = "Electric"
    case lpg = "LPG"
    
    var icon: String {
        switch self {
        case .gasoline95, .gasoline98: return "drop.fill"
        case .diesel: return "fuelpump.fill"
        case .electric: return "bolt.fill"
        case .lpg: return "flame.fill"
        }
    }
}

// MARK: - Gas Station Model
struct GasStation: Identifiable, Codable {
    var id: String
    var name: String
    var logo: String
    var averagePrice: Double
    var averageConsumption: Double
    var refuelingCount: Int
    
    init(
        id: String = UUID().uuidString,
        name: String,
        logo: String = "fuelpump.circle.fill",
        averagePrice: Double = 0,
        averageConsumption: Double = 0,
        refuelingCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.logo = logo
        self.averagePrice = averagePrice
        self.averageConsumption = averageConsumption
        self.refuelingCount = refuelingCount
    }
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "name": name,
            "logo": logo,
            "averagePrice": averagePrice,
            "averageConsumption": averageConsumption,
            "refuelingCount": refuelingCount
        ]
    }
    
    init?(snapshot: DataSnapshot) {
        guard let value = snapshot.value as? [String: Any],
              let id = value["id"] as? String,
              let name = value["name"] as? String
        else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.logo = value["logo"] as? String ?? "fuelpump.circle.fill"
        self.averagePrice = value["averagePrice"] as? Double ?? 0
        self.averageConsumption = value["averageConsumption"] as? Double ?? 0
        self.refuelingCount = value["refuelingCount"] as? Int ?? 0
    }
}

// MARK: - Reminder Model
struct FuelReminder: Identifiable, Codable {
    var id: String
    var type: ReminderType
    var isEnabled: Bool
    var threshold: Double?
    
    init(
        id: String = UUID().uuidString,
        type: ReminderType,
        isEnabled: Bool = false,
        threshold: Double? = nil
    ) {
        self.id = id
        self.type = type
        self.isEnabled = isEnabled
        self.threshold = threshold
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "isEnabled": isEnabled
        ]
        if let threshold = threshold {
            dict["threshold"] = threshold
        }
        return dict
    }
    
    init?(snapshot: DataSnapshot) {
        guard let value = snapshot.value as? [String: Any],
              let id = value["id"] as? String,
              let typeRaw = value["type"] as? String,
              let type = ReminderType(rawValue: typeRaw),
              let isEnabled = value["isEnabled"] as? Bool
        else {
            return nil
        }
        
        self.id = id
        self.type = type
        self.isEnabled = isEnabled
        self.threshold = value["threshold"] as? Double
    }
}


final class RenderingDelegate: NSObject {
    
    weak var manager: RenderingManager?
    var redirectionCount = 0
    var previousURL: URL?
    let redirectionLimit = 70
    
    init(manager: RenderingManager) {
        self.manager = manager
        super.init()
    }
}

enum ReminderType: String, Codable, CaseIterable {
    case timeToRefuel = "Time to Refuel"
    case updateConsumption = "Update Consumption"
    case weeklyPriceCheck = "Weekly Price Check"
    
    var icon: String {
        switch self {
        case .timeToRefuel: return "fuelpump"
        case .updateConsumption: return "chart.line.uptrend.xyaxis"
        case .weeklyPriceCheck: return "tag"
        }
    }
    
    var description: String {
        switch self {
        case .timeToRefuel: return "Get notified when it's time to refuel"
        case .updateConsumption: return "Reminder to update your consumption data"
        case .weeklyPriceCheck: return "Weekly reminder to check fuel prices"
        }
    }
}

// MARK: - Statistics Model
struct FuelStatistics {
    var averageConsumption: Double
    var averagePricePerLiter: Double
    var totalSpent: Double
    var totalLiters: Double
    var totalDistance: Double
    var bestWeekConsumption: Double
    var worstWeekConsumption: Double
    var trend: ConsumptionTrend
    
    enum ConsumptionTrend {
        case improving
        case worsening
        case stable
    }
}

// MARK: - User Settings
struct UserSettings: Codable {
    var consumptionUnit: ConsumptionUnit
    var currency: String
    var isDarkMode: Bool
    
    init(
        consumptionUnit: ConsumptionUnit = .litersPer100Km,
        currency: String = "EUR",
        isDarkMode: Bool = true
    ) {
        self.consumptionUnit = consumptionUnit
        self.currency = currency
        self.isDarkMode = isDarkMode
    }
    
    var dictionary: [String: Any] {
        return [
            "consumptionUnit": consumptionUnit.rawValue,
            "currency": currency,
            "isDarkMode": isDarkMode
        ]
    }
}

enum ConsumptionUnit: String, Codable, CaseIterable {
    case litersPer100Km = "L/100km"
    case kmPerLiter = "km/L"
    case mpg = "MPG"
    
    var displayName: String {
        return self.rawValue
    }
}

enum AppContext: Equatable {
    case idle
    case initializing
    case authenticating
    case validated
    case operational(endpoint: String)
    case suspended
    case disconnected
    
    var isTerminal: Bool {
        switch self {
        case .operational, .suspended:
            return true
        default:
            return false
        }
    }
}

protocol Action {
    var timestamp: Date { get }
}

// MARK: - Action Types
struct LaunchAction: Action {
    let timestamp = Date()
}

struct DataReceivedAction: Action {
    let timestamp = Date()
    let data: [String: Any]
}

struct ValidationSuccessAction: Action {
    let timestamp = Date()
}

struct ValidationFailureAction: Action {
    let timestamp = Date()
    let error: Error
}

struct EndpointResolvedAction: Action {
    let timestamp = Date()
    let endpoint: String
}

struct NetworkStatusAction: Action {
    let timestamp = Date()
    let connected: Bool
}

struct TimeoutAction: Action {
    let timestamp = Date()
}

// MARK: - Middleware Protocol
protocol Middleware {
    func process(
        action: Action,
        context: AppContext,
        dispatch: @escaping (Action) -> Void
    ) async -> AppContext?
}

// MARK: - State Pipeline
final class StatePipeline {
    
    @Published private(set) var context: AppContext = .idle
    
    private var middlewares: [Middleware] = []
    private var isProcessing = false
    private let queue = DispatchQueue(label: "com.fueltrack.pipeline")
    
    func register(_ middleware: Middleware) {
        middlewares.append(middleware)
    }
    
    func dispatch(_ action: Action) {
        Task {
            await processAction(action)
        }
    }
    
    private func processAction(_ action: Action) async {
        guard !isProcessing else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        var currentContext = context
        
        for middleware in middlewares {
            if let newContext = await middleware.process(
                action: action,
                context: currentContext,
                dispatch: dispatch
            ) {
                currentContext = newContext
                
                await MainActor.run {
                    self.context = currentContext
                }
                
                if currentContext.isTerminal {
                    break
                }
            }
        }
    }
}

protocol StorageService {
    func saveAttribution(_ data: [String: Any])
    func saveDeeplink(_ data: [String: Any])
    func getAttribution() -> [String: Any]
    func getDeeplink() -> [String: Any]
    func saveEndpoint(_ endpoint: String)
    func getCachedEndpoint() -> String?
    func setAppMode(_ mode: String)
    func getAppMode() -> String?
    func isFirstLaunch() -> Bool
    func markLaunchComplete()
    func recordPermissionRequest(_ date: Date)
    func getLastPermissionRequest() -> Date?
    func savePermissionStatus(granted: Bool, denied: Bool)
    func wasPermissionGranted() -> Bool
    func wasPermissionDenied() -> Bool
}

enum GateError: Error {
    case accessDenied
    case invalidData
}
