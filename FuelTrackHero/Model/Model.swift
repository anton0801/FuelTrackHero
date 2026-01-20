import Foundation
import FirebaseDatabase
import Combine
import Firebase
import FirebaseMessaging
import AppsFlyerLib

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

final class LocalStorage: StorageMediator {
    
    private let defaults = UserDefaults.standard
    private var attributionCache: [String: Any] = [:]
    private var deeplinkCache: [String: Any] = [:]
    
    private enum Key {
        static let url = "cached_endpoint"
        static let status = "app_status"
        static let firstLaunch = "launchedBefore"
        static let permissionRequest = "permission_request_time"
        static let permissionGranted = "permissions_accepted"
        static let permissionDenied = "permissions_denied"
    }
    
    func saveAttribution(_ data: [String: Any]) {
        attributionCache = data
    }
    
    func saveDeeplink(_ data: [String: Any]) {
        deeplinkCache = data
    }
    
    func loadAttribution() -> [String: Any] {
        return attributionCache
    }
    
    func loadDeeplink() -> [String: Any] {
        return deeplinkCache
    }
    
    func cacheURL(_ url: String) {
        defaults.set(url, forKey: Key.url)
    }
    
    func loadCachedURL() -> String? {
        return defaults.string(forKey: Key.url)
    }
    
    func saveStatus(_ status: String) {
        defaults.set(status, forKey: Key.status)
    }
    
    func loadStatus() -> String? {
        return defaults.string(forKey: Key.status)
    }
    
    func isFirstLaunch() -> Bool {
        return !defaults.bool(forKey: Key.firstLaunch)
    }
    
    func markFirstLaunchComplete() {
        defaults.set(true, forKey: Key.firstLaunch)
    }
    
    func recordPermissionDismissal(_ date: Date) {
        defaults.set(date, forKey: Key.permissionRequest)
    }
    
    func loadLastPermissionRequest() -> Date? {
        return defaults.object(forKey: Key.permissionRequest) as? Date
    }
    
    func updatePermissionState(granted: Bool, denied: Bool) {
        defaults.set(granted, forKey: Key.permissionGranted)
        defaults.set(denied, forKey: Key.permissionDenied)
    }
    
    func wasPermissionGranted() -> Bool {
        return defaults.bool(forKey: Key.permissionGranted)
    }
    
    func wasPermissionDenied() -> Bool {
        return defaults.bool(forKey: Key.permissionDenied)
    }
}

// MARK: - HTTP Network
final class HTTPNetwork: NetworkMediator {
    
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func getAttribution(deviceID: String) async throws -> [String: Any] {
        let url = try buildAttributionURL(deviceID: deviceID)
        let request = URLRequest(url: url, timeoutInterval: 30)
        
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)
        
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func getURL(attribution: [String: Any]) async throws -> String {
        let endpoint = URL(string: "https://fueltrackhero.com/config.php")!
        let payload = buildPayload(from: attribution)
        let request = try buildPOSTRequest(url: endpoint, payload: payload)
        
        let (data, _) = try await session.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        guard let success = json["ok"] as? Bool, success,
              let url = json["url"] as? String else {
            throw NetworkError.invalidResponse
        }
        
        return url
    }
    
    // MARK: - Private Helpers
    
    private func buildAttributionURL(deviceID: String) throws -> URL {
        let base = "https://gcdsdk.appsflyer.com/install_data/v4.0/"
        let appID = "id\(Config.appsFlyerId)"
        
        guard var components = URLComponents(string: base + appID) else {
            throw NetworkError.badURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "devkey", value: Config.appsFlyerKey),
            URLQueryItem(name: "device_id", value: deviceID)
        ]
        
        guard let url = components.url else {
            throw NetworkError.badURL
        }
        
        return url
    }
    
    private func buildPayload(from data: [String: Any]) -> [String: Any] {
        var payload = data
        
        payload["os"] = "iOS"
        payload["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        payload["bundle_id"] = SystemInfo.bundleID
        payload["firebase_project_id"] = SystemInfo.firebaseProjectID
        payload["store_id"] = SystemInfo.appStoreID
        payload["push_token"] = SystemInfo.pushToken
        payload["locale"] = SystemInfo.localeCode
        
        return payload
    }
    
    private func buildPOSTRequest(url: URL, payload: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        return request
    }
    
    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NetworkError.httpError
        }
    }
}

// MARK: - Network Error
enum NetworkError: Error {
    case badURL
    case httpError
    case invalidResponse
}

// MARK: - System Info
struct SystemInfo {
    
    static var bundleID: String {
        return "com.ctrackheroapp.FuelTrackHero"
    }
    
    static var firebaseProjectID: String? {
        return FirebaseApp.app()?.options.gcmSenderID
    }
    
    static var appStoreID: String {
        return "id\(Config.appsFlyerId)"
    }
    
    static var pushToken: String? {
        if let saved = UserDefaults.standard.string(forKey: "push_token") {
            return saved
        }
        return Messaging.messaging().fcmToken
    }
    
    static var localeCode: String {
        return Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"
    }
}
