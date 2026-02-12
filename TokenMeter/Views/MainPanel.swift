import SwiftUI

struct MainPanel: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
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
                
                // Refresh button
                Button(action: { Task { await appState.fetchAllUsage() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Refresh now")
                
                // Settings
                Button(action: { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)
            
            // Today's total
            TodaySection(appState: appState)
            
            Divider()
                .padding(.vertical, 12)
            
            // Provider list
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
            
            // Weekly chart
            Divider()
                .padding(.vertical, 12)
            
            WeeklyChart(data: appState.weeklyData, weeklyTotal: appState.weeklyTotal, monthlyPace: appState.monthlyPace)
            
            // Smart insight
            if let insight = topInsight {
                InsightBadge(text: insight)
                    .padding(.top, 12)
            }
            
            // Last updated
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
        .padding(16)
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
}

// MARK: - Today Section

struct TodaySection: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appState.todaySpendFormatted)
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
            
            Text("Today")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            // Budget bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(appState.budgetColor)
                        .frame(width: geo.size.width * min(appState.budgetUsage, 1.0), height: 4)
                        .animation(.easeInOut(duration: 0.5), value: appState.budgetUsage)
                }
            }
            .frame(height: 4)
            .padding(.top, 6)
            
            HStack {
                Text("\(Int(appState.budgetUsage * 100))% of $\(String(format: "%.0f", appState.dailyBudget))/day")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
                Text("$\(String(format: "%.2f", appState.budgetRemaining)) left")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
    }
}

// MARK: - Provider Row

struct ProviderRow: View {
    @Binding var provider: ProviderData
    let maxSpend: Double
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { provider.isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: provider.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                        .frame(width: 12)
                    
                    Text(provider.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if provider.todaySpend == 0 && provider.models.isEmpty {
                        Text("—")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    
                    Spacer()
                    
                    Text(String(format: "$%.2f", provider.todaySpend))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(provider.todaySpend > 0 ? .primary : .secondary.opacity(0.3))
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            
            // Spend bar
            if maxSpend > 0 && provider.todaySpend > 0 {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(provider.color)
                        .frame(width: geo.size.width * (provider.todaySpend / maxSpend), height: 3)
                        .animation(.easeInOut(duration: 0.4), value: provider.todaySpend)
                }
                .frame(height: 3)
                .padding(.leading, 12)
            }
            
            // Expanded detail
            if provider.isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let sub = provider.subscription {
                        SubscriptionDetail(subscription: sub)
                            .padding(.top, 8)
                    }
                    
                    if !provider.models.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("API USAGE")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                                .tracking(0.8)
                            
                            ForEach(provider.models) { model in
                                HStack {
                                    Text(model.name)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if model.tokens > 0 {
                                        Text(formatTokens(model.tokens))
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary.opacity(0.4))
                                    }
                                    Text(String(format: "$%.2f", model.spend))
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(.primary.opacity(0.8))
                                        .monospacedDigit()
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    if provider.models.isEmpty && provider.subscription == nil {
                        Text("No API key configured")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.4))
                            .padding(.top, 4)
                    }
                }
                .padding(.leading, 12)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM tok", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK tok", Double(count) / 1_000) }
        return "\(count) tok"
    }
}

// MARK: - Subscription Detail

struct SubscriptionDetail: View {
    let subscription: SubscriptionData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(subscription.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("$\(String(format: "%.0f", subscription.price))/mo")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                if subscription.isActive {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
            }
            
            if let usage = subscription.rateLimitUsage {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(rateLimitColor(usage))
                            .frame(width: geo.size.width * usage, height: 4)
                            .animation(.easeInOut(duration: 0.5), value: usage)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    if let remaining = subscription.rateLimitRemaining {
                        Text("~\(remaining) msgs left")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Spacer()
                    if let resets = subscription.resetsInFormatted {
                        Text("Resets in \(resets)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }
    
    func rateLimitColor(_ usage: Double) -> Color {
        if usage >= 0.9 { return .red }
        if usage >= 0.7 { return .yellow }
        return .blue
    }
}

// MARK: - Weekly Chart

struct WeeklyChart: View {
    let data: [DailySpend]
    let weeklyTotal: Double
    let monthlyPace: Double
    
    var maxValue: Double { data.map(\.spend).max() ?? 1 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("THIS WEEK")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.6))
                .tracking(1.2)
            
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(data) { day in
                    VStack(spacing: 3) {
                        if day.spend > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(day.isToday ? Color.blue : Color.blue.opacity(0.3))
                                .frame(height: max(2, 40 * day.spend / maxValue))
                        } else {
                            Spacer()
                                .frame(height: 2)
                        }
                        Text(day.day)
                            .font(.system(size: 9))
                            .foregroundColor(day.isToday ? .primary : .secondary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 50)
            
            HStack {
                Text(String(format: "Week: $%.2f", weeklyTotal))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
                Text(String(format: "Monthly pace: $%.0f", monthlyPace))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
    }
}

// MARK: - Insight Badge

struct InsightBadge: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.yellow.opacity(0.08))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.yellow.opacity(0.15), lineWidth: 1)
        )
    }
}
