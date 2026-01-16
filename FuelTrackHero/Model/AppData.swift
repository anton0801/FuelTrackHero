import Foundation
import Firebase
import FirebaseAuth
import FirebaseDatabase
import Combine
import AppsFlyerLib
import Foundation


// MARK: - UserDefaults Storage
final class UserDefaultsStorage: StorageService {
    
    private let defaults = UserDefaults.standard
    private var attributionCache: [String: Any] = [:]
    private var deeplinkCache: [String: Any] = [:]
    
    private enum Keys {
        static let endpoint = "cached_endpoint"
        static let mode = "app_status"
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
    
    func getAttribution() -> [String: Any] {
        return attributionCache
    }
    
    func getDeeplink() -> [String: Any] {
        return deeplinkCache
    }
    
    func saveEndpoint(_ endpoint: String) {
        defaults.set(endpoint, forKey: Keys.endpoint)
    }
    
    func getCachedEndpoint() -> String? {
        return defaults.string(forKey: Keys.endpoint)
    }
    
    func setAppMode(_ mode: String) {
        defaults.set(mode, forKey: Keys.mode)
    }
    
    func getAppMode() -> String? {
        return defaults.string(forKey: Keys.mode)
    }
    
    func isFirstLaunch() -> Bool {
        return !defaults.bool(forKey: Keys.firstLaunch)
    }
    
    func markLaunchComplete() {
        defaults.set(true, forKey: Keys.firstLaunch)
    }
    
    func recordPermissionRequest(_ date: Date) {
        defaults.set(date, forKey: Keys.permissionRequest)
    }
    
    func getLastPermissionRequest() -> Date? {
        return defaults.object(forKey: Keys.permissionRequest) as? Date
    }
    
    func savePermissionStatus(granted: Bool, denied: Bool) {
        defaults.set(granted, forKey: Keys.permissionGranted)
        defaults.set(denied, forKey: Keys.permissionDenied)
    }
    
    func wasPermissionGranted() -> Bool {
        return defaults.bool(forKey: Keys.permissionGranted)
    }
    
    func wasPermissionDenied() -> Bool {
        return defaults.bool(forKey: Keys.permissionDenied)
    }
}

// MARK: - Network Service Protocol
protocol NetworkService {
    func fetchAttribution(deviceID: String) async throws -> [String: Any]
    func resolveEndpoint(attribution: [String: Any]) async throws -> String
}

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

final class TokenStore {
    
    static let shared = TokenStore()
    
    private init() {}
    
    func save(_ token: String) {
        let storage = UserDefaults.standard
        storage.set(token, forKey: "fcm_token")
        storage.set(token, forKey: "push_token")
    }
    
    func retrieve() -> String? {
        return UserDefaults.standard.string(forKey: "push_token")
    }
}


final class LaunchMiddleware: Middleware {
    
    func process(
        action: Action,
        context: AppContext,
        dispatch: @escaping (Action) -> Void
    ) async -> AppContext? {
        guard action is LaunchAction, context == .idle else {
            return nil
        }
        
        return .initializing
    }
}

final class ValidationMiddleware: Middleware {
    
    private let validator: GateValidator
    
    init(validator: GateValidator = FirebaseGateValidator()) {
        self.validator = validator
    }
    
    func process(
        action: Action,
        context: AppContext,
        dispatch: @escaping (Action) -> Void
    ) async -> AppContext? {
        guard action is DataReceivedAction, context == .initializing else {
            return nil
        }
        
        do {
            let isValid = try await validator.validate()
            
            if isValid {
                dispatch(ValidationSuccessAction())
                return .authenticating
            } else {
                dispatch(ValidationFailureAction(error: GateError.accessDenied))
                return .suspended
            }
        } catch {
            dispatch(ValidationFailureAction(error: error))
            return .suspended
        }
    }
}

final class ResolutionMiddleware: Middleware {
    
    func process(
        action: Action,
        context: AppContext,
        dispatch: @escaping (Action) -> Void
    ) async -> AppContext? {
        guard action is ValidationSuccessAction, context == .authenticating else {
            return nil
        }
        
        return .validated
    }
}

final class ActivationMiddleware: Middleware {
    
    func process(
        action: Action,
        context: AppContext,
        dispatch: @escaping (Action) -> Void
    ) async -> AppContext? {
        guard let resolved = action as? EndpointResolvedAction else {
            return nil
        }
        
        return .operational(endpoint: resolved.endpoint)
    }
}

final class HTTPNetworkService: NetworkService {
    
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchAttribution(deviceID: String) async throws -> [String: Any] {
        let url = try buildAttributionURL(deviceID: deviceID)
        let request = URLRequest(url: url, timeoutInterval: 30)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    func resolveEndpoint(attribution: [String: Any]) async throws -> String {
        let url = URL(string: "https://fueltrackhero.com/config.php")!
        let payload = buildPayload(from: attribution)
        let request = try buildPOSTRequest(url: url, payload: payload)
        
        let (data, _) = try await session.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        guard let success = json["ok"] as? Bool, success,
              let endpoint = json["url"] as? String else {
            throw NetworkError.invalidEndpoint
        }
        
        return endpoint
    }
    
    // MARK: - Private Helpers
    
    private func buildAttributionURL(deviceID: String) throws -> URL {
        let base = "https://gcdsdk.appsflyer.com/install_data/v4.0/"
        let appID = "id\(Config.appsFlyerId)"
        
        guard var components = URLComponents(string: base + appID) else {
            throw NetworkError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "devkey", value: Config.appsFlyerKey),
            URLQueryItem(name: "device_id", value: deviceID)
        ]
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        return url
    }
    
    private func buildPayload(from data: [String: Any]) -> [String: Any] {
        var payload = data
        
        payload["os"] = "iOS"
        payload["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        payload["bundle_id"] = DeviceInfo.bundleID
        payload["firebase_project_id"] = DeviceInfo.firebaseProject
        payload["store_id"] = DeviceInfo.storeID
        payload["push_token"] = DeviceInfo.pushToken
        payload["locale"] = DeviceInfo.locale
        
        return payload
    }
    
    private func buildPOSTRequest(url: URL, payload: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        return request
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NetworkError.badResponse
        }
    }
}

// MARK: - Network Error
enum NetworkError: Error {
    case invalidURL
    case badResponse
    case invalidEndpoint
}

// MARK: - Device Info
struct DeviceInfo {
    
    static var bundleID: String {
        return "com.ctrackheroapp.FuelTrackHero"
    }
    
    static var firebaseProject: String? {
        return FirebaseApp.app()?.options.gcmSenderID
    }
    
    static var storeID: String {
        return "id\(Config.appsFlyerId)"
    }
    
    static var pushToken: String? {
        if let saved = UserDefaults.standard.string(forKey: "push_token") {
            return saved
        }
        return Messaging.messaging().fcmToken
    }
    
    static var locale: String {
        return Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"
    }
}

final class NetworkMiddleware: Middleware {
    
    func process(
        action: Action,
        context: AppContext,
        dispatch: @escaping (Action) -> Void
    ) async -> AppContext? {
        guard let networkAction = action as? NetworkStatusAction else {
            return nil
        }
        
        if !networkAction.connected && !context.isTerminal {
            return .disconnected
        } else if networkAction.connected && context == .disconnected {
            return .suspended
        }
        
        return nil
    }
}

final class TimeoutMiddleware: Middleware {
    
    func process(
        action: Action,
        context: AppContext,
        dispatch: @escaping (Action) -> Void
    ) async -> AppContext? {
        guard action is TimeoutAction, !context.isTerminal else {
            return nil
        }
        
        return .suspended
    }
}

protocol GateValidator {
    func validate() async throws -> Bool
}

// MARK: - Firebase Gate Validator
final class FirebaseGateValidator: GateValidator {
    
    func validate() async throws -> Bool {
        let path = "users/log/data"
        
        return try await withCheckedThrowingContinuation { continuation in
            Database.database().reference().child(path)
                .observeSingleEvent(of: .value) { snapshot in
                    if let url = snapshot.value as? String,
                       !url.isEmpty,
                       URL(string: url) != nil {
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
