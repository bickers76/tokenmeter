import SwiftUI

struct FloatingWindowView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with controls
            HStack {
                Text("TOKENMETER")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                if appState.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
                
                Spacer()
                
                // Pin toggle (always on top)
                Button(action: { 
                    appState.alwaysOnTop.toggle()
                    updateWindowLevel()
                }) {
                    Image(systemName: appState.alwaysOnTop ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundColor(appState.alwaysOnTop ? .blue : .secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help(appState.alwaysOnTop ? "Unpin from top" : "Pin above all windows")
                
                Button(action: { Task { await appState.fetchAllUsage() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Refresh now")
                
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)
            
            // Today
            TodaySection(appState: appState)
            
            Divider()
                .padding(.vertical, 12)
            
            // Providers
            Text("PROVIDERS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
                .tracking(1.2)
                .padding(.bottom, 8)
            
            ForEach(appState.providers.indices, id: \.self) { index in
                ProviderRow(
                    provider: $appState.providers[index],
                    maxSpend: appState.todayTotal
                )
                if index < appState.providers.count - 1 {
                    Divider()
                        .padding(.vertical, 4)
                }
            }
            
            Divider()
                .padding(.vertical, 12)
            
            WeeklyChart(data: appState.weeklyData, weeklyTotal: appState.weeklyTotal, monthlyPace: appState.monthlyPace)
            
            if let insight = topInsight {
                InsightBadge(text: insight)
                    .padding(.top, 12)
            }
            
            if let updated = appState.lastUpdated {
                HStack {
                    Spacer()
                    Text("Updated \(updated, style: .relative) ago")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(Color(nsColor: NSColor(red: 0.07, green: 0.07, blue: 0.11, alpha: 1)))
        .onAppear {
            updateWindowLevel()
        }
    }
    
    var topInsight: String? {
        guard let top = appState.providers.max(by: { $0.todaySpend < $1.todaySpend }),
              top.todaySpend > 0, appState.todayTotal > 0 else { return nil }
        let pct = Int((top.todaySpend / appState.todayTotal) * 100)
        if pct > 40 {
            return "\(top.name) is \(pct)% of today's spend"
        }
        return nil
    }
    
    func updateWindowLevel() {
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.title == "TokenMeter" }) {
                window.level = appState.alwaysOnTop ? .floating : .normal
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
    }
}
