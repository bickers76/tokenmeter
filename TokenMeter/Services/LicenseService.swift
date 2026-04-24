import Foundation
import IOKit

class LicenseService: ObservableObject {
    static let shared = LicenseService()
    
    @Published var isLicensed: Bool = false
    @Published var isTrialActive: Bool = false
    @Published var trialDaysRemaining: Int = 0
    @Published var licenseError: String? = nil
    
    let keychain = KeychainHelper.shared
    private let licenseKey = "license_key"
    private let trialStartKey = "trial_start_date"
    private let trialDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    // Gumroad product ID (for products created after Jan 9 2023, use product_id not product_permalink)
    private let productId = "MBbhPgH7BJSLNDBPbFmbKQ=="
    
    /// Whether the user can use the app (licensed OR active trial)
    var canUseApp: Bool {
        isLicensed || isTrialActive
    }
    
    /// Whether this is the user's first ever launch (no trial started, no license)
    var isFirstLaunch: Bool {
        keychain.get(key: trialStartKey) == nil && keychain.get(key: licenseKey) == nil
    }
    
    /// Whether the trial has expired (started but past 7 days, and not licensed)
    var isTrialExpired: Bool {
        !isLicensed && !isTrialActive && keychain.get(key: trialStartKey) != nil
    }
    
    init() {
        // Check if already licensed
        if let key = keychain.get(key: licenseKey) {
            isLicensed = !key.isEmpty
        }
        
        // Check trial status
        refreshTrialStatus()
    }
    
    /// Start the 7-day free trial
    func startTrial() {
        let now = Date()
        let timestamp = String(now.timeIntervalSince1970)
        try? keychain.save(key: trialStartKey, value: timestamp)
        NotificationService.shared.scheduleTrialNotifications(trialStartDate: now)
        refreshTrialStatus()
    }
    
    /// Recalculate trial state from stored start date
    func refreshTrialStatus() {
        guard !isLicensed else {
            isTrialActive = false
            trialDaysRemaining = 0
            return
        }
        
        guard let startString = keychain.get(key: trialStartKey),
              let startTimestamp = Double(startString) else {
            isTrialActive = false
            trialDaysRemaining = 0
            return
        }
        
        let startDate = Date(timeIntervalSince1970: startTimestamp)
        let elapsed = Date().timeIntervalSince(startDate)
        let remaining = trialDuration - elapsed
        
        if remaining > 0 {
            isTrialActive = true
            trialDaysRemaining = max(1, Int(ceil(remaining / (24 * 60 * 60))))
        } else {
            isTrialActive = false
            trialDaysRemaining = 0
        }
    }
    
    /// Validate a license key against Gumroad's API
    func activate(key: String) async -> Bool {
        licenseError = nil
        
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            await MainActor.run { licenseError = "Please enter a license key" }
            return false
        }
        
        // Call Gumroad license verification API
        let url = URL(string: "https://api.gumroad.com/v2/licenses/verify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let machineId = getMachineId()
        let body = "product_id=\(productId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? productId)&license_key=\(trimmedKey)&increment_uses_count=true"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run { licenseError = "Network error" }
                return false
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let success = json?["success"] as? Bool ?? false
            
            if success {
                // Check if purchase was refunded
                if let purchase = json?["purchase"] as? [String: Any],
                   let refunded = purchase["refunded"] as? Bool, refunded {
                    await MainActor.run { licenseError = "This license has been refunded" }
                    return false
                }
                
                // Valid! Save to keychain
                try? keychain.save(key: licenseKey, value: trimmedKey)
                try? keychain.save(key: "machine_id", value: machineId)
                
                await MainActor.run { isLicensed = true }
                return true
            } else {
                let message = json?["message"] as? String ?? "Invalid license key"
                await MainActor.run { licenseError = message }
                return false
            }
        } catch {
            await MainActor.run { licenseError = "Could not verify license. Check your internet connection." }
            return false
        }
    }
    
    /// Get unique machine identifier
    func getMachineId() -> String {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        
        defer { IOObjectRelease(platformExpert) }
        
        guard platformExpert != 0,
              let serialNumberAsCFString = IORegistryEntryCreateCFProperty(
                platformExpert,
                kIOPlatformUUIDKey as CFString,
                kCFAllocatorDefault, 0
              ) else {
            return UUID().uuidString // fallback
        }
        
        return (serialNumberAsCFString.takeUnretainedValue() as? String) ?? UUID().uuidString
    }
    
    /// Remove license (for testing/support)
    func deactivate() {
        keychain.delete(key: licenseKey)
        keychain.delete(key: "machine_id")
        isLicensed = false
    }
}
