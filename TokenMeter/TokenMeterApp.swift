import SwiftUI
import UserNotifications

@main
struct TokenMeterApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        // Menubar icon — always present
        MenuBarExtra {
            VStack(spacing: 0) {
                MainPanel(appState: appState)
                    .frame(width: 320)
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    Button("Open Window") {
                        openMainWindow()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button("Settings") {
                        openSettings()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .preferredColorScheme(.dark)
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
        
        // Floating desktop window
        Window("TokenMeter", id: "main") {
            FloatingWindowView(appState: appState)
                .preferredColorScheme(.dark)
                .onDisappear {
                    sendMenubarNotification()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
        
        // Settings window
        Settings {
            SettingsView(appState: appState)
                .preferredColorScheme(.dark)
        }
    }
    
    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
    
    func sendMenubarNotification() {
        let content = UNMutableNotificationContent()
        content.title = "TokenMeter"
        content.body = "Still running in your menu bar ↗"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "menubar-hint",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
