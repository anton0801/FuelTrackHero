import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    
    var body: some View {
        NavigationView {
            Form {
                Picker("Consumption Unit", selection: $appData.settings.consumptionUnit) {
                    Text("l/100km").tag("l/100km")
                    Text("km/l").tag("km/l")
                    Text("mpg").tag("mpg")
                }
                
                TextField("Currency", text: $appData.settings.currency)
                
                Picker("Theme", selection: $appData.settings.theme) {
                    Text("Neon").tag("neon")
                    Text("Dark").tag("dark")
                }
                
                NavigationLink(destination: StatisticsView().environmentObject(appData)) {
                    Text("Statistics")
                }
                
                NavigationLink(destination: RemindersView().environmentObject(appData)) {
                    Text("Reminders")
                }
                
                Button("Reset Data") {
                    appData.refuels = []
                    appData.gasStations = []
                    appData.reminders = []
                }
                .foregroundColor(.red)
            }
            .navigationTitle("Settings")
        }
        .background(Color.asphaltBlack)
        .overlay(
            Image(systemName: "pawprint")
                .foregroundColor(.whiteHighlight)
                .font(.system(size: 30))
                .position(x: UIScreen.main.bounds.width - 30, y: UIScreen.main.bounds.height - 100)
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppData())
}
