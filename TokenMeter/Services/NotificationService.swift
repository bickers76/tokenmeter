import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    private var lastAlertTime: Date?
    private let minAlertInterval: TimeInterval = 300 // 5 min between alerts
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func sendBudgetAlert(spent: Double, budget: Double, topProvider: String, topSpend: Double) {
        // Don't spam — minimum interval between alerts
        if let last = lastAlertTime, Date().timeIntervalSince(last) < minAlertInterval { return }
        
        let content = UNMutableNotificationContent()
        content.title = "TokenMeter — Budget Alert"
        content.body = String(format: "Daily spend: $%.2f / $%.2f (%.0f%%)\nTop: %@ ($%.2f)",
                              spent, budget, (spent / budget) * 100, topProvider, topSpend)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "budget-alert-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // fire immediately
        )
        
        UNUserNotificationCenter.current().add(request)
        lastAlertTime = Date()
    }
    
    func sendRateLimitWarning(provider: String, remaining: Int, resetsIn: String) {
        let content = UNMutableNotificationContent()
        content.title = "TokenMeter — Rate Limit"
        content.body = "\(provider): ~\(remaining) requests left. Resets in \(resetsIn)."
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: "ratelimit-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
