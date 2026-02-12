import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var providers: [ProviderData] = ProviderData.mockData
    @Published var dailyBudget: Double = 10.0
    @Published var alertThreshold: Double = 0.8
    @Published var pollIntervalMinutes: Int = 5
    @Published var launchAtLogin: Bool = true
    @Published var alwaysOnTop: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date? = nil
    @Published var weeklyData: [DailySpend] = DailySpend.mockWeek
    
    private var pollTimer: Timer?
    private let keychain = KeychainHelper.shared
    private let notifications = NotificationService.shared
    
    var todayTotal: Double {
        providers.reduce(0) { $0 + $1.todaySpend }
    }
    
    var todaySpendFormatted: String {
        String(format: "$%.2f", todayTotal)
    }
    
    var budgetUsage: Double {
        guard dailyBudget > 0 else { return 0 }
        return todayTotal / dailyBudget
    }
    
    var budgetColor: Color {
        if budgetUsage >= 1.0 { return .red }
        if budgetUsage >= alertThreshold { return .yellow }
        return .green
    }
    
    var budgetRemaining: Double {
        max(0, dailyBudget - todayTotal)
    }
    
    var weeklyTotal: Double {
        weeklyData.reduce(0) { $0 + $1.spend }
    }
    
    var monthlyPace: Double {
        let daysWithData = weeklyData.filter { $0.spend > 0 }.count
        guard daysWithData > 0 else { return 0 }
        return (weeklyTotal / Double(daysWithData)) * 30
    }
    
    init() {
        notifications.requestPermission()
        startPolling()
    }
    
    func startPolling() {
        pollTimer?.invalidate()
        // Initial fetch
        Task { await fetchAllUsage() }
        // Recurring
        pollTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(pollIntervalMinutes * 60), repeats: true) { [weak self] _ in
            Task { await self?.fetchAllUsage() }
        }
    }
    
    @MainActor
    func fetchAllUsage() async {
        isLoading = true
        defer { 
            isLoading = false
            lastUpdated = Date()
        }
        
        // Fetch from each provider with a saved API key
        await withTaskGroup(of: (String, [ModelCost], RateLimitInfo?).self) { group in
            if let key = keychain.get(key: "anthropic") {
                group.addTask {
                    let service = AnthropicService(apiKey: key)
                    let usage = (try? await service.fetchUsage()) ?? []
                    let rateLimit = try? await service.checkRateLimits()
                    return ("Anthropic", usage, rateLimit)
                }
            }
            
            if let key = keychain.get(key: "openai") {
                group.addTask {
                    let service = OpenAIService(apiKey: key)
                    let usage = (try? await service.fetchUsage()) ?? []
                    return ("OpenAI", usage, nil)
                }
            }
            
            for await (providerName, costs, rateLimit) in group {
                if let idx = providers.firstIndex(where: { $0.name == providerName }) {
                    providers[idx].models = costs.map { ModelUsage(name: $0.displayName, spend: $0.cost, tokens: $0.inputTokens + $0.outputTokens) }
                    providers[idx].todaySpend = costs.reduce(0) { $0 + $1.cost }
                    
                    if let rl = rateLimit, let remaining = rl.requestsRemaining, let limit = rl.requestsLimit {
                        providers[idx].subscription?.rateLimitRemaining = remaining
                        providers[idx].subscription?.rateLimitTotal = limit
                        if let mins = rl.resetsInMinutes {
                            providers[idx].subscription?.rateLimitResetsIn = mins * 60
                        }
                    }
                }
            }
        }
        
        // Check budget alerts
        checkBudgetAlert()
    }
    
    private func checkBudgetAlert() {
        let usage = budgetUsage
        if usage >= alertThreshold {
            if let top = providers.max(by: { $0.todaySpend < $1.todaySpend }) {
                notifications.sendBudgetAlert(
                    spent: todayTotal,
                    budget: dailyBudget,
                    topProvider: top.name,
                    topSpend: top.todaySpend
                )
            }
        }
        
        // Check rate limits
        for provider in providers {
            if let sub = provider.subscription,
               let remaining = sub.rateLimitRemaining,
               let total = sub.rateLimitTotal,
               total > 0 {
                let usage = 1.0 - (Double(remaining) / Double(total))
                if usage >= 0.9, let resets = sub.resetsInFormatted {
                    notifications.sendRateLimitWarning(
                        provider: provider.name,
                        remaining: remaining,
                        resetsIn: resets
                    )
                }
            }
        }
    }
    
    func saveApiKey(provider: String, key: String) {
        try? keychain.save(key: provider.lowercased(), value: key)
        Task { await fetchAllUsage() }
    }
    
    func getApiKey(provider: String) -> String {
        keychain.get(key: provider.lowercased()) ?? ""
    }
    
    func hasApiKey(provider: String) -> Bool {
        keychain.get(key: provider.lowercased()) != nil
    }
}

// MARK: - Data Models

struct ProviderData: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    var todaySpend: Double
    var models: [ModelUsage]
    var subscription: SubscriptionData?
    var isExpanded: Bool = false
    
    static let mockData: [ProviderData] = [
        ProviderData(
            name: "Anthropic",
            icon: "brain.head.profile",
            color: Color(red: 0.83, green: 0.65, blue: 0.45),
            todaySpend: 3.41,
            models: [
                ModelUsage(name: "Claude Opus", spend: 2.80, tokens: 45_200),
                ModelUsage(name: "Claude Sonnet", spend: 0.61, tokens: 28_400),
            ],
            subscription: SubscriptionData(
                name: "Claude Max",
                price: 100,
                isActive: true,
                rateLimitRemaining: 38,
                rateLimitTotal: 100,
                rateLimitResetsIn: 28 * 60
            )
        ),
        ProviderData(
            name: "OpenAI",
            icon: "sparkle",
            color: Color(red: 0.45, green: 0.73, blue: 1.0),
            todaySpend: 1.22,
            models: [
                ModelUsage(name: "GPT-4o", spend: 0.98, tokens: 32_100),
                ModelUsage(name: "Whisper", spend: 0.24, tokens: 0),
            ],
            subscription: SubscriptionData(
                name: "ChatGPT Plus",
                price: 20,
                isActive: true,
                rateLimitRemaining: nil,
                rateLimitTotal: nil,
                rateLimitResetsIn: nil
            )
        ),
        ProviderData(
            name: "Google AI",
            icon: "g.circle",
            color: Color(red: 0.51, green: 0.78, blue: 0.52),
            todaySpend: 0.19,
            models: [
                ModelUsage(name: "Gemini Flash", spend: 0.19, tokens: 52_000),
            ],
            subscription: nil
        ),
        ProviderData(
            name: "xAI",
            icon: "xmark.circle",
            color: Color(red: 0.70, green: 0.62, blue: 0.86),
            todaySpend: 0.00,
            models: [],
            subscription: nil
        ),
    ]
}

struct ModelUsage: Identifiable {
    let id = UUID()
    let name: String
    let spend: Double
    let tokens: Int
}

struct SubscriptionData: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
    let isActive: Bool
    var rateLimitRemaining: Int?
    var rateLimitTotal: Int?
    var rateLimitResetsIn: Int?
    
    var rateLimitUsage: Double? {
        guard let remaining = rateLimitRemaining, let total = rateLimitTotal, total > 0 else { return nil }
        return 1.0 - (Double(remaining) / Double(total))
    }
    
    var resetsInFormatted: String? {
        guard let seconds = rateLimitResetsIn else { return nil }
        let mins = seconds / 60
        if mins < 1 { return "< 1 min" }
        return "\(mins) min"
    }
}

struct DailySpend: Identifiable {
    let id = UUID()
    let day: String
    let spend: Double
    let isToday: Bool
    
    static let mockWeek: [DailySpend] = [
        DailySpend(day: "M", spend: 6.20, isToday: false),
        DailySpend(day: "T", spend: 11.40, isToday: false),
        DailySpend(day: "W", spend: 4.82, isToday: true),
        DailySpend(day: "T", spend: 0, isToday: false),
        DailySpend(day: "F", spend: 0, isToday: false),
        DailySpend(day: "S", spend: 0, isToday: false),
        DailySpend(day: "S", spend: 0, isToday: false),
    ]
}
