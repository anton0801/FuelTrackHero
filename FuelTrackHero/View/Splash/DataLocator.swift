import Foundation
import Combine
import Network
import UIKit
import UserNotifications
import AppsFlyerLib

final class ServiceLocator {
    
    static let shared = ServiceLocator()
    
    private var services: [String: Any] = [:]
    
    private init() {}
    
    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        services[key] = service
    }
    
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return services[key] as? T
    }
}

@MainActor
final class ApplicationController: ObservableObject {
    
    @Published private(set) var displayMode: DisplayMode = .loading
    @Published private(set) var targetEndpoint: String?
    @Published private(set) var showPermissionRequest = false
    
    private let pipeline = StatePipeline()
    private let storage: StorageService
    private let network: NetworkService
    private var connectivity: ConnectivityService
    
    private var subscriptions = Set<AnyCancellable>()
    private var timeoutTask: DispatchWorkItem?
    private var isActivated = false
    
    init(
        storage: StorageService = UserDefaultsStorage(),
        network: NetworkService = HTTPNetworkService(),
        connectivity: ConnectivityService = ReachabilityService()
    ) {
        self.storage = storage
        self.network = network
        self.connectivity = connectivity
        
        ServiceLocator.shared.register(storage, for: StorageService.self)
        ServiceLocator.shared.register(network, for: NetworkService.self)
        
        setupPipeline()
        observePipeline()
        startConnectivityMonitoring()
        initiateBootSequence()
    }
    
    // MARK: - Public Interface
    
    func handleAttributionData(_ data: [String: Any]) {
        storage.saveAttribution(data)
        pipeline.dispatch(DataReceivedAction(data: data))
        
        Task {
            await processFlow()
        }
    }
    
    func handleDeeplinkData(_ data: [String: Any]) {
        storage.saveDeeplink(data)
    }
    
    func dismissPermissionRequest() {
        storage.recordPermissionRequest(Date())
        showPermissionRequest = false
        completeActivation()
    }
    
    func acceptPermissionRequest() {
        requestNotificationPermission { [weak self] granted in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.storage.savePermissionStatus(granted: granted, denied: !granted)
                
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                self.showPermissionRequest = false
                self.completeActivation()
            }
        }
    }
    
    private func setupPipeline() {
        pipeline.register(LaunchMiddleware())
        pipeline.register(ValidationMiddleware())
        pipeline.register(ResolutionMiddleware())
        pipeline.register(ActivationMiddleware())
        pipeline.register(NetworkMiddleware())
        pipeline.register(TimeoutMiddleware())
    }
    
    private func observePipeline() {
        pipeline.$context
            .receive(on: DispatchQueue.main)
            .sink { [weak self] context in
                self?.handleContextChange(context)
            }
            .store(in: &subscriptions)
    }
    
    private func handleContextChange(_ context: AppContext) {
        guard !isActivated else { return }
        
        switch context {
        case .idle, .initializing, .authenticating, .validated:
            displayMode = .loading
            
        case .operational(let endpoint):
            targetEndpoint = endpoint
            displayMode = .active
            isActivated = true
            
        case .suspended:
            displayMode = .standby
            
        case .disconnected:
            displayMode = .offline
        }
    }
    
    private func startConnectivityMonitoring() {
        connectivity.onStatusChange = { [weak self] isConnected in
            guard let self = self, !self.isActivated else { return }
            self.pipeline.dispatch(NetworkStatusAction(connected: isConnected))
        }
        connectivity.start()
    }
    
    private func initiateBootSequence() {
        pipeline.dispatch(LaunchAction())
        scheduleTimeout()
    }
    
    private func scheduleTimeout() {
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isActivated else { return }
            self.pipeline.dispatch(TimeoutAction())
        }
        
        timeoutTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
    }
    
    // MARK: - Flow Processing
    
    private func processFlow() async {
        let attribution = storage.getAttribution()
        
        guard !attribution.isEmpty else {
            loadFromCache()
            return
        }
        
        if storage.getAppMode() == "Inactive" {
            pipeline.dispatch(TimeoutAction())
            return
        }
        
        if shouldRunFirstLaunch() {
            await executeFirstLaunch()
            return
        }
        
        if let temp = loadTemporaryEndpoint() {
            activate(endpoint: temp)
            return
        }
        
        await resolveEndpoint()
    }
    
    private func shouldRunFirstLaunch() -> Bool {
        return storage.isFirstLaunch() &&
               storage.getAttribution()["af_status"] as? String == "Organic"
    }
    
    private func executeFirstLaunch() async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        
        do {
            let deviceID = AppsFlyerLib.shared().getAppsFlyerUID()
            let attribution = try await network.fetchAttribution(deviceID: deviceID)
            
            var combined = attribution
            let deeplink = storage.getDeeplink()
            deeplink.forEach { key, value in
                if combined[key] == nil {
                    combined[key] = value
                }
            }
            
            storage.saveAttribution(combined)
            await resolveEndpoint()
        } catch {
            pipeline.dispatch(TimeoutAction())
        }
    }
    
    private func loadTemporaryEndpoint() -> String? {
        return UserDefaults.standard.string(forKey: "temp_url")
    }
    
    private func resolveEndpoint() async {
        do {
            let attribution = storage.getAttribution()
            let endpoint = try await network.resolveEndpoint(attribution: attribution)
            
            storage.saveEndpoint(endpoint)
            storage.setAppMode("Active")
            storage.markLaunchComplete()
            
            activate(endpoint: endpoint)
        } catch {
            loadFromCache()
        }
    }
    
    private func loadFromCache() {
        if let cached = storage.getCachedEndpoint() {
            activate(endpoint: cached)
        } else {
            pipeline.dispatch(TimeoutAction())
        }
    }
    
    private func activate(endpoint: String) {
        guard !isActivated else { return }
        
        pipeline.dispatch(EndpointResolvedAction(endpoint: endpoint))
        
        if shouldRequestPermission() {
            showPermissionRequest = true
        }
    }
    
    private func shouldRequestPermission() -> Bool {
        if storage.wasPermissionGranted() || storage.wasPermissionDenied() {
            return false
        }
        
        if let lastRequest = storage.getLastPermissionRequest(),
           Date().timeIntervalSince(lastRequest) < 259200 {
            return false
        }
        
        return true
    }
    
    private func completeActivation() {
        // Already handled by pipeline
    }
    
    private func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            completion(granted)
        }
    }
}

// MARK: - Display Mode
enum DisplayMode {
    case loading
    case active
    case standby
    case offline
}

// MARK: - Connectivity Service Protocol
protocol ConnectivityService {
    var onStatusChange: ((Bool) -> Void)? { get set }
    func start()
    func stop()
}

// MARK: - Reachability Service
final class ReachabilityService: ConnectivityService {
    
    private let monitor = NWPathMonitor()
    var onStatusChange: ((Bool) -> Void)?
    
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            self?.onStatusChange?(connected)
        }
        monitor.start(queue: .global(qos: .background))
    }
    
    func stop() {
        monitor.cancel()
    }
}
