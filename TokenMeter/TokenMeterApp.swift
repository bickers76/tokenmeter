import SwiftUI

@main
struct TokenMeterApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        MenuBarExtra {
            MainPanel(appState: appState)
                .frame(width: 320)
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(appState.budgetColor)
                    .frame(width: 8, height: 8)
                Text(appState.todaySpendFormatted)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView(appState: appState)
        }
    }
}
