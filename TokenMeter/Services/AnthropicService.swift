import Foundation

// MARK: - Anthropic

class AnthropicService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Fetch usage data — tries the admin API first, falls back to header-based rate limits
    func fetchUsage(for date: Date = Date()) async throws -> [ModelCost] {
        // Anthropic's admin usage API requires org-level admin key
        // For most users, we'll estimate from response headers + local tracking
        // Try the usage endpoint first
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/organizations/usage?start_date=\(dateStr)&end_date=\(dateStr)")!)
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
            
            if http.statusCode == 200 {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                return parseAnthropicUsage(json)
            }
            // If 401/403, admin endpoint not available — return empty, rely on rate limits
            return []
        } catch {
            return []
        }
    }
    
    /// Check rate limits via response headers
    func checkRateLimits() async throws -> RateLimitInfo {
        // Use a count_tokens endpoint (cheaper than a real message)
        var request = URLRequest(url: URL(string: "\(baseURL)/v1/messages/count_tokens")!)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        
        let headers = http.allHeaderFields
        
        return RateLimitInfo(
            requestsLimit: (headers["x-ratelimit-limit-requests"] as? String).flatMap(Int.init),
            requestsRemaining: (headers["x-ratelimit-remaining-requests"] as? String).flatMap(Int.init),
            tokensLimit: (headers["x-ratelimit-limit-tokens"] as? String).flatMap(Int.init),
            tokensRemaining: (headers["x-ratelimit-remaining-tokens"] as? String).flatMap(Int.init),
            resetsAt: headers["x-ratelimit-reset-requests"] as? String
        )
    }
    
    private func parseAnthropicUsage(_ json: [String: Any]?) -> [ModelCost] {
        // Parse based on actual API response structure
        guard let data = json?["data"] as? [[String: Any]] else { return [] }
        return data.compactMap { entry in
            guard let model = entry["model"] as? String,
                  let inputTokens = entry["input_tokens"] as? Int,
                  let outputTokens = entry["output_tokens"] as? Int else { return nil }
            let cost = estimateAnthropicCost(model: model, input: inputTokens, output: outputTokens)
            return ModelCost(model: model, inputTokens: inputTokens, outputTokens: outputTokens, cost: cost)
        }
    }
    
    private func estimateAnthropicCost(model: String, input: Int, output: Int) -> Double {
        // Pricing per 1M tokens (Feb 2026)
        let pricing: (input: Double, output: Double)
        if model.contains("opus") {
            pricing = (15.0, 75.0)
        } else if model.contains("sonnet") {
            pricing = (3.0, 15.0)
        } else if model.contains("haiku") {
            pricing = (0.25, 1.25)
        } else {
            pricing = (3.0, 15.0) // default to sonnet
        }
        return (Double(input) / 1_000_000 * pricing.input) + (Double(output) / 1_000_000 * pricing.output)
    }
}

// MARK: - OpenAI

class OpenAIService {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Fetch usage for a specific date
    func fetchUsage(for date: Date = Date()) async throws -> [ModelCost] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/usage?date=\(dateStr)")!)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return parseOpenAIUsage(json)
    }
    
    /// Fetch subscription / billing info
    func fetchBilling() async throws -> BillingInfo {
        var request = URLRequest(url: URL(string: "https://api.openai.com/dashboard/billing/subscription")!)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return BillingInfo(
            plan: json?["plan"] as? [String: Any],
            hardLimit: json?["hard_limit_usd"] as? Double,
            softLimit: json?["soft_limit_usd"] as? Double
        )
    }
    
    private func parseOpenAIUsage(_ json: [String: Any]?) -> [ModelCost] {
        guard let data = json?["data"] as? [[String: Any]] else { return [] }
        
        var modelTotals: [String: (input: Int, output: Int)] = [:]
        
        for entry in data {
            let model = entry["snapshot_id"] as? String ?? "unknown"
            let context = entry["n_context_tokens_total"] as? Int ?? 0
            let generated = entry["n_generated_tokens_total"] as? Int ?? 0
            
            var current = modelTotals[model] ?? (0, 0)
            current.input += context
            current.output += generated
            modelTotals[model] = current
        }
        
        return modelTotals.map { model, tokens in
            let cost = estimateOpenAICost(model: model, input: tokens.input, output: tokens.output)
            return ModelCost(model: model, inputTokens: tokens.input, outputTokens: tokens.output, cost: cost)
        }.sorted { $0.cost > $1.cost }
    }
    
    private func estimateOpenAICost(model: String, input: Int, output: Int) -> Double {
        let pricing: (input: Double, output: Double)
        if model.contains("gpt-4o-mini") {
            pricing = (0.15, 0.60)
        } else if model.contains("gpt-4o") {
            pricing = (2.50, 10.0)
        } else if model.contains("o1") || model.contains("o3") {
            pricing = (10.0, 40.0)
        } else if model.contains("whisper") {
            return Double(input + output) / 1_000_000 * 0.006 // per second approximation
        } else {
            pricing = (2.50, 10.0) // default
        }
        return (Double(input) / 1_000_000 * pricing.input) + (Double(output) / 1_000_000 * pricing.output)
    }
}

// MARK: - Google AI

class GoogleAIService {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Google AI Studio doesn't have a direct usage API
    /// We'd need to use Cloud Billing API for Vertex AI users
    /// For now, return empty — can track locally via OpenClaw logs
    func fetchUsage(for date: Date = Date()) async throws -> [ModelCost] {
        // Google AI Studio free tier has no billing API
        // Vertex AI users would use Cloud Billing
        return []
    }
}

// MARK: - Shared Types

struct ModelCost: Identifiable {
    let id = UUID()
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cost: Double
    
    var displayName: String {
        // Clean up model names for display
        let name = model
            .replacingOccurrences(of: "claude-", with: "Claude ")
            .replacingOccurrences(of: "gpt-", with: "GPT-")
            .replacingOccurrences(of: "gemini-", with: "Gemini ")
        // Capitalize first letter of each word
        return name.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

struct RateLimitInfo {
    let requestsLimit: Int?
    let requestsRemaining: Int?
    let tokensLimit: Int?
    let tokensRemaining: Int?
    let resetsAt: String?
    
    var usagePercentage: Double? {
        guard let limit = requestsLimit, let remaining = requestsRemaining, limit > 0 else { return nil }
        return 1.0 - (Double(remaining) / Double(limit))
    }
    
    var resetsInMinutes: Int? {
        guard let resets = resetsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        guard let resetDate = formatter.date(from: resets) else { return nil }
        return max(0, Int(resetDate.timeIntervalSinceNow / 60))
    }
}

struct BillingInfo {
    let plan: [String: Any]?
    let hardLimit: Double?
    let softLimit: Double?
}

enum ServiceError: Error {
    case invalidResponse
    case apiError(String)
    case unauthorized
}
