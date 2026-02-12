import SwiftUI
import UserNotifications

@main
struct TokenMeterApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var license = LicenseService.shared
    
    var body: some Scene {
        // Menubar icon — always present
        MenuBarExtra {
            VStack(spacing: 0) {
                if license.isLicensed {
                    MainPanel(appState: appState)
                        .frame(width: 320)
                } else {
                    VStack(spacing: 12) {
                        Text("TokenMeter")
                            .font(.system(size: 14, weight: .semibold))
                        Text("License required")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Button("Activate") {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .padding(20)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    if license.isLicensed {
                        Button("Settings") {
                            openSettings()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    }
                    
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
                    .fill(license.isLicensed ? appState.budgetColor : .gray)
                    .frame(width: 8, height: 8)
                Text(license.isLicensed ? appState.todaySpendFormatted : "—")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
        
        // Main window — activation or dashboard
        Window("TokenMeter", id: "main") {
            Group {
                if license.isLicensed {
                    FloatingWindowView(appState: appState)
                } else {
                    ActivationView(license: license)
                }
            }
            .preferredColorScheme(.dark)
            .onDisappear {
                if license.isLicensed {
                    sendMenubarNotification()
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
        
        // Settings
        Settings {
            SettingsView(appState: appState)
                .preferredColorScheme(.dark)
        }
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
