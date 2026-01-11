import SwiftUI

@main
struct FuelTrackHeroApp: App {
    @StateObject var appData = AppData()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
                .preferredColorScheme(.dark)
        }
    }
}
