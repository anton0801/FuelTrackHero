import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appData: AppData
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            RefuelsLogView()
                .tabItem {
                    Label("Log", systemImage: "list.bullet")
                }
            
            AddRefuelView()
                .tabItem {
                    Label("Add", systemImage: "plus")
                }
            
//            StatisticsView()
//                .tabItem {
//                    Label("Stats", systemImage: "chart.bar")
//                }
            
            GasStationsView()
                .tabItem {
                    Label("Stations", systemImage: "fuelpump")
                }
            
            RemindersView()
                .tabItem {
                    Label("Reminders", systemImage: "bell")
                }
            
//            SettingsView()
//                .tabItem {
//                    Label("Settings", systemImage: "gear")
//                }
        }
        .accentColor(.goldenNeon)
        .background(Color.asphaltBlack)
    }
}

#Preview {
    ContentView()
}
