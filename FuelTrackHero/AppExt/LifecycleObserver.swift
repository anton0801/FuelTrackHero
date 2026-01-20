import UIKit
import FirebaseCore
import FirebaseMessaging
import FirebaseAuth
import AppTrackingTransparency
import UserNotifications
import AppsFlyerLib

final class LifecycleObserver: UIResponder, UIApplicationDelegate {
    
    private let broadcaster = EventBroadcaster()
    private let notificationHandler = NotificationHandler()
    private let trackingAdapter = TrackingAdapter()
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        initializeServices()
        assignDelegates()
        activatePushNotifications()
        
        if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            notificationHandler.process(notification)
        }
        
        trackingAdapter.setup(
            onAttributionReceived: { [weak self] data in
                self?.broadcaster.emitAttribution(data)
            },
            onDeeplinkReceived: { [weak self] data in
                self?.broadcaster.emitDeeplink(data)
            },
            onError: { [weak self] in
                self?.broadcaster.emitAttribution([:])
            }
        )
        
        monitorLifecycle()
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    private func initializeServices() {
        FirebaseApp.configure()
        authAnonym()
    }
    
    private func authAnonym() {
        Auth.auth().signInAnonymously { _, error in
            if let e = error {
                print("Error log in \(e.localizedDescription)")
            }
        }
    }
    
    private func assignDelegates() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }
    
    private func activatePushNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    private func monitorLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppActivation),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppActivation() {
        trackingAdapter.initiate()
    }
}

// MARK: - MessagingDelegate
extension LifecycleObserver: MessagingDelegate {
    
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        messaging.token { token, error in
            guard error == nil, let token = token else { return }
            UserDefaults.standard.set(token, forKey: "push_token")
            UserDefaults.standard.set(token, forKey: "fcm_token")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension LifecycleObserver: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        notificationHandler.process(notification.request.content.userInfo)
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        notificationHandler.process(response.notification.request.content.userInfo)
        completionHandler()
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        notificationHandler.process(userInfo)
        completionHandler(.newData)
    }
}

// MARK: - Event Broadcaster
final class EventBroadcaster {
    
    private var attributionStorage: [AnyHashable: Any] = [:]
    private var deeplinkStorage: [AnyHashable: Any] = [:]
    private var consolidationTimer: Timer?
    private let transmittedFlag = "trackingDataSent"
    
    func emitAttribution(_ data: [AnyHashable: Any]) {
        attributionStorage = data
        scheduleConsolidation()
        
        if !deeplinkStorage.isEmpty {
            consolidateAndBroadcast()
        }
    }
    
    func emitDeeplink(_ data: [AnyHashable: Any]) {
        guard !hasBeenTransmitted() else { return }
        
        deeplinkStorage = data
        broadcastDeeplink(data)
        cancelConsolidation()
        
        if !attributionStorage.isEmpty {
            consolidateAndBroadcast()
        }
    }
    
    // MARK: - Private Methods
    
    private func scheduleConsolidation() {
        consolidationTimer?.invalidate()
        consolidationTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: false
        ) { [weak self] _ in
            self?.consolidateAndBroadcast()
        }
    }
    
    private func cancelConsolidation() {
        consolidationTimer?.invalidate()
    }
    
    private func consolidateAndBroadcast() {
        var consolidated = attributionStorage
        
        deeplinkStorage.forEach { key, value in
            if consolidated[key] == nil {
                consolidated[key] = value
            }
        }
        
        broadcastAttribution(consolidated)
        markTransmitted()
    }
    
    private func broadcastAttribution(_ data: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: Notification.Name("ConversionDataReceived"),
            object: nil,
            userInfo: ["conversionData": data]
        )
    }
    
    private func broadcastDeeplink(_ data: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: Notification.Name("deeplink_values"),
            object: nil,
            userInfo: ["deeplinksData": data]
        )
    }
    
    private func hasBeenTransmitted() -> Bool {
        return UserDefaults.standard.bool(forKey: transmittedFlag)
    }
    
    private func markTransmitted() {
        UserDefaults.standard.set(true, forKey: transmittedFlag)
    }
}

// MARK: - Tracking Adapter
final class TrackingAdapter: NSObject {
    
    private var onAttributionReceived: (([AnyHashable: Any]) -> Void)?
    private var onDeeplinkReceived: (([AnyHashable: Any]) -> Void)?
    private var onError: (() -> Void)?
    
    func setup(
        onAttributionReceived: @escaping ([AnyHashable: Any]) -> Void,
        onDeeplinkReceived: @escaping ([AnyHashable: Any]) -> Void,
        onError: @escaping () -> Void
    ) {
        self.onAttributionReceived = onAttributionReceived
        self.onDeeplinkReceived = onDeeplinkReceived
        self.onError = onError
        
        configureSDK()
    }
    
    private func configureSDK() {
        let sdk = AppsFlyerLib.shared()
        sdk.appsFlyerDevKey = Config.appsFlyerKey
        sdk.appleAppID = Config.appsFlyerId
        sdk.delegate = self
        sdk.deepLinkDelegate = self
    }
    
    func initiate() {
        if #available(iOS 14.0, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                }
            }
        } else {
            AppsFlyerLib.shared().start()
        }
    }
}

// MARK: - AppsFlyerLibDelegate
extension TrackingAdapter: AppsFlyerLibDelegate {
    
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        onAttributionReceived?(data)
    }
    
    func onConversionDataFail(_ error: Error) {
        onError?()
    }
}

// MARK: - DeepLinkDelegate
extension TrackingAdapter: DeepLinkDelegate {
    
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status,
              let link = result.deepLink else {
            return
        }
        
        onDeeplinkReceived?(link.clickEvent)
    }
}
