import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var appData: AppData
    @State private var showFlash = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach($appData.reminders) { $reminder in
                    Toggle(reminder.type, isOn: $reminder.isEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .turquoiseLight))
                        .onChange(of: reminder.isEnabled) { _ in
                            withAnimation {
                                showFlash = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showFlash = false
                            }
                        }
                }
                .listRowBackground(Color.shadowBlack)
            }
            .listStyle(.plain)
            .navigationTitle("Reminders")
            .background(Color.asphaltBlack.ignoresSafeArea())
            .overlay(
                Group {
                    if showFlash {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.goldenNeon)
                            .shadow(color: .goldenNeon, radius: 10)
                            .transition(.opacity)
                    }
                },
                alignment: .center
            )
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    RemindersView()
}
