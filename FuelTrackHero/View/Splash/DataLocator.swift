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
final class ApplicationMediator: ObservableObject {
    
    @Published private(set) var renderMode: RenderMode = .loading
    @Published private(set) var targetURL: String?
    @Published private(set) var showPermissionRequest = false
    
    private let phaseMachine: PhaseMachine
    private let storage: StorageMediator
    private let network: NetworkMediator
    private var connectivity: ConnectivityMediator
    
    private var subscriptions = Set<AnyCancellable>()
    private var timeoutWork: DispatchWorkItem?
    private var sealed = false
    
    init(
        phaseMachine: PhaseMachine = PhaseMachine(),
        storage: StorageMediator = LocalStorage(),
        network: NetworkMediator = HTTPNetwork(),
        connectivity: ConnectivityMediator = PathConnectivity()
    ) {
        self.phaseMachine = phaseMachine
        self.storage = storage
        self.network = network
        self.connectivity = connectivity
        
        observePhaseChanges()
        monitorConnectivity()
        bootstrap()
    }
    
    func ingestAttribution(_ data: [String: Any]) {
        storage.saveAttribution(data)
        
        Task {
            await executeValidation()
        }
    }
    
    func ingestDeeplink(_ data: [String: Any]) {
        storage.saveDeeplink(data)
    }
    
    func rejectPermission() {
        storage.recordPermissionDismissal(Date())
        showPermissionRequest = false
        complete()
    }
    
    func grantPermission() {
        requestAuthorization { [weak self] granted in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.storage.updatePermissionState(granted: granted, denied: !granted)
                
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                self.showPermissionRequest = false
                self.complete()
            }
        }
    }
    
    // MARK: - Private Setup
    
    private func observePhaseChanges() {
        phaseMachine.$currentPhase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                self?.handlePhaseUpdate(phase)
            }
            .store(in: &subscriptions)
    }
    
    private func handlePhaseUpdate(_ phase: ApplicationPhase) {
        guard !sealed else { return }
        
        switch phase {
        case .idle, .launching, .validating, .verified:
            renderMode = .loading
            
        case .running(let url):
            targetURL = url
            renderMode = .active
            sealed = true
            timeoutWork?.cancel()
            
        case .halted:
            renderMode = .standby
            
        case .offline:
            renderMode = .disconnected
        }
    }
    
    private func monitorConnectivity() {
        connectivity.onStateChange = { [weak self] connected in
            guard let self = self, !self.sealed else { return }
            
            if connected {
                self.phaseMachine.enqueue(ReconnectCommand())
            } else {
                self.phaseMachine.enqueue(DisconnectCommand())
            }
        }
        connectivity.start()
    }
    
    private func bootstrap() {
        phaseMachine.enqueue(LaunchCommand())
        scheduleTimeout()
    }
    
    private func scheduleTimeout() {
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.sealed else { return }
            self.phaseMachine.enqueue(ExpireCommand())
        }
        
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: work)
    }
    
    // MARK: - Validation Flow
    
    private func executeValidation() async {
        let command = ValidateCommand()
        
        if let newPhase = await command.execute(current: phaseMachine.currentPhase, machine: phaseMachine) {
            phaseMachine.enqueue(ValidateCommand())
            
            if newPhase == .verified {
                await proceedFlow()
            }
        }
    }
    
    private func proceedFlow() async {
        let attribution = storage.loadAttribution()
        
        guard !attribution.isEmpty else {
            loadCachedURL()
            return
        }
        
        if storage.loadStatus() == "Inactive" {
            phaseMachine.enqueue(ExpireCommand())
            return
        }
        
        if shouldRunFirstLaunch() {
            await executeFirstLaunch()
            return
        }
        
        if let temp = loadTemporaryURL() {
            activateURL(temp)
            return
        }
        
        await resolveURL()
    }
    
    private func shouldRunFirstLaunch() -> Bool {
        return storage.isFirstLaunch() &&
               storage.loadAttribution()["af_status"] as? String == "Organic"
    }
    
    private func executeFirstLaunch() async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        
        do {
            let deviceID = AppsFlyerLib.shared().getAppsFlyerUID()
            let attribution = try await network.getAttribution(deviceID: deviceID)
            
            var combined = attribution
            let deeplink = storage.loadDeeplink()
            deeplink.forEach { key, value in
                if combined[key] == nil {
                    combined[key] = value
                }
            }
            
            storage.saveAttribution(combined)
            await resolveURL()
        } catch {
            phaseMachine.enqueue(ExpireCommand())
        }
    }
    
    private func loadTemporaryURL() -> String? {
        return UserDefaults.standard.string(forKey: "temp_url")
    }
    
    private func resolveURL() async {
        do {
            let attribution = storage.loadAttribution()
            let url = try await network.getURL(attribution: attribution)
            
            storage.cacheURL(url)
            storage.saveStatus("Active")
            storage.markFirstLaunchComplete()
            
            activateURL(url)
        } catch {
            loadCachedURL()
        }
    }
    
    private func loadCachedURL() {
        if let cached = storage.loadCachedURL() {
            activateURL(cached)
        } else {
            phaseMachine.enqueue(ExpireCommand())
        }
    }
    
    private func activateURL(_ url: String) {
        guard !sealed else { return }
        
        phaseMachine.enqueue(ActivateCommand(url: url))
        
        if shouldRequestPermission() {
            showPermissionRequest = true
        }
    }
    
    private func shouldRequestPermission() -> Bool {
        if storage.wasPermissionGranted() || storage.wasPermissionDenied() {
            return false
        }
        
        if let lastRequest = storage.loadLastPermissionRequest(),
           Date().timeIntervalSince(lastRequest) < 259200 {
            return false
        }
        
        return true
    }
    
    private func complete() {
        // Already handled by phase machine
    }
    
    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            completion(granted)
        }
    }
}

// MARK: - Render Mode
enum RenderMode {
    case loading
    case active
    case standby
    case disconnected
}

// MARK: - Storage Mediator Protocol
protocol StorageMediator {
    func saveAttribution(_ data: [String: Any])
    func saveDeeplink(_ data: [String: Any])
    func loadAttribution() -> [String: Any]
    func loadDeeplink() -> [String: Any]
    func cacheURL(_ url: String)
    func loadCachedURL() -> String?
    func saveStatus(_ status: String)
    func loadStatus() -> String?
    func isFirstLaunch() -> Bool
    func markFirstLaunchComplete()
    func recordPermissionDismissal(_ date: Date)
    func loadLastPermissionRequest() -> Date?
    func updatePermissionState(granted: Bool, denied: Bool)
    func wasPermissionGranted() -> Bool
    func wasPermissionDenied() -> Bool
}

// MARK: - Network Mediator Protocol
protocol NetworkMediator {
    func getAttribution(deviceID: String) async throws -> [String: Any]
    func getURL(attribution: [String: Any]) async throws -> String
}

// MARK: - Connectivity Mediator Protocol
protocol ConnectivityMediator {
    var onStateChange: ((Bool) -> Void)? { get set }
    func start()
    func stop()
}

// MARK: - Path Connectivity
final class PathConnectivity: ConnectivityMediator {
    
    private let pathMonitor = NWPathMonitor()
    var onStateChange: ((Bool) -> Void)?
    
    func start() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            self?.onStateChange?(connected)
        }
        pathMonitor.start(queue: .global(qos: .background))
    }
    
    func stop() {
        pathMonitor.cancel()
    }
}
