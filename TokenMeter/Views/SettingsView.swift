import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var anthropicKey: String = ""
    @State private var openaiKey: String = ""
    @State private var googleKey: String = ""
    @State private var xaiKey: String = ""
    @State private var showSaved = false
    
    var body: some View {
        TabView {
            // API Keys tab
            Form {
                Section("API Keys") {
                    KeyRow(label: "Anthropic", key: $anthropicKey, isSet: appState.hasApiKey(provider: "anthropic"))
                    KeyRow(label: "OpenAI", key: $openaiKey, isSet: appState.hasApiKey(provider: "openai"))
                    KeyRow(label: "Google AI", key: $googleKey, isSet: appState.hasApiKey(provider: "google"))
                    KeyRow(label: "xAI", key: $xaiKey, isSet: appState.hasApiKey(provider: "xai"))
                }
                
                Section("Subscriptions") {
                    SubscriptionToggle(name: "Claude Max", price: "$100/mo")
                    SubscriptionToggle(name: "Claude Pro", price: "$20/mo")
                    SubscriptionToggle(name: "ChatGPT Plus", price: "$20/mo")
                    SubscriptionToggle(name: "ChatGPT Pro", price: "$200/mo")
                }
                
                HStack {
                    Spacer()
                    Button("Save") {
                        saveKeys()
                        showSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSaved = false }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if showSaved {
                        Text("✓ Saved")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                }
            }
            .tabItem {
                Label("Accounts", systemImage: "key")
            }
            .onAppear { loadKeys() }
            
            // Budget tab
            Form {
                Section("Daily Budget") {
                    HStack {
                        Text("Limit")
                        Spacer()
                        TextField("", value: $appState.dailyBudget, format: .currency(code: "USD"))
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Alert at")
                        Spacer()
                        Text("\(Int(appState.alertThreshold * 100))%")
                            .monospacedDigit()
                            .frame(width: 35)
                        Slider(value: $appState.alertThreshold, in: 0.5...1.0, step: 0.05)
                            .frame(width: 120)
                    }
                }
                
                Section("Notifications") {
                    Toggle("Budget alerts", isOn: .constant(true))
                    Toggle("Rate limit warnings", isOn: .constant(true))
                    Picker("Sound", selection: .constant("Default")) {
                        Text("None").tag("None")
                        Text("Default").tag("Default")
                    }
                }
            }
            .tabItem {
                Label("Budget", systemImage: "chart.bar")
            }
            
            // General tab
            Form {
                Section("Polling") {
                    Picker("Refresh interval", selection: $appState.pollIntervalMinutes) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                    }
                    .onChange(of: appState.pollIntervalMinutes) { _ in
                        appState.startPolling()
                    }
                }
                
                Section("Window") {
                    Toggle("Always on top", isOn: $appState.alwaysOnTop)
                    Toggle("Launch at login", isOn: $appState.launchAtLogin)
                }
                
                Section("About") {
                    HStack {
                        Text("TokenMeter")
                        Spacer()
                        Text("v1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Built by")
                        Spacer()
                        Link("Wayne Bickerton", destination: URL(string: "https://waynebickerton.com")!)
                            .foregroundColor(.blue)
                    }
                }
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(width: 420, height: 320)
    }
    
    func saveKeys() {
        if !anthropicKey.isEmpty { appState.saveApiKey(provider: "anthropic", key: anthropicKey) }
        if !openaiKey.isEmpty { appState.saveApiKey(provider: "openai", key: openaiKey) }
        if !googleKey.isEmpty { appState.saveApiKey(provider: "google", key: googleKey) }
        if !xaiKey.isEmpty { appState.saveApiKey(provider: "xai", key: xaiKey) }
    }
    
    func loadKeys() {
        anthropicKey = appState.getApiKey(provider: "anthropic")
        openaiKey = appState.getApiKey(provider: "openai")
        googleKey = appState.getApiKey(provider: "google")
        xaiKey = appState.getApiKey(provider: "xai")
    }
}

struct KeyRow: View {
    let label: String
    @Binding var key: String
    let isSet: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            SecureField("API Key", text: $key)
                .textFieldStyle(.roundedBorder)
            if isSet && key.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                    .help("Key saved in Keychain")
            }
        }
    }
}

struct SubscriptionToggle: View {
    let name: String
    let price: String
    @State private var isEnabled = false
    
    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Text(name)
                Spacer()
                Text(price)
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
            }
        }
    }
}
