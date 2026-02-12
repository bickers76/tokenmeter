# TokenMeter — AI Usage Monitor for Mac

*See what your AI is costing you. One glance.*

---

## Product
- macOS menubar app
- $5 one-off purchase
- Polls provider APIs directly for real-time accuracy
- Shows BOTH consumer subscriptions (Claude Pro/Max, ChatGPT Plus) AND API platform usage

## Supported Providers (v1)

| Provider | API Usage | Consumer Usage | How |
|----------|-----------|----------------|-----|
| Anthropic | ✅ Token spend via `/v1/usage` | ⚠️ Rate limit status only (no billing API for subscriptions) | API key |
| OpenAI | ✅ `/dashboard/billing/usage` + `/v1/usage` | ✅ Subscription info via `/dashboard/billing/subscription` | API key |
| Google AI | ✅ via Google Cloud billing API | ❌ Gemini Pro sub has no API | API key |
| xAI | ✅ if they expose usage endpoint | ❌ | API key |

### Honest Limitation
Claude Max/Pro subscriptions don't expose usage data via API. We can show:
- Rate limit status (are you hitting limits?)
- Session count / message estimates (by reading local OpenClaw logs if installed)
- But NOT "you've used 80% of your allowance" — Anthropic doesn't expose that

For API key users, we get full granularity: tokens in/out, cost per model, daily/weekly/monthly.

## Design Language

### Menubar
```
┌─────────────────────────────┐
│  ◉ $4.82 today              │  ← menubar icon + daily spend
└─────────────────────────────┘
```

When clicked, drops down a panel:

### Main Panel (Expanded)
```
┌──────────────────────────────────────┐
│  TokenMeter                    ⚙️    │
│                                      │
│  Today          $4.82                │
│  ░░░░░░░░░░░░░░░░░░░▓▓▓▓▓ 48%      │
│  Budget: $10/day                     │
│                                      │
│  ── By Provider ──────────────────   │
│                                      │
│  Anthropic API        $3.41          │
│  ████████████████░░░░░░░░░░          │
│  Opus: $2.80 · Sonnet: $0.61        │
│                                      │
│  OpenAI API           $1.22          │
│  ████████░░░░░░░░░░░░░░░░░░          │
│  GPT-4o: $0.98 · Whisper: $0.24     │
│                                      │
│  Google AI            $0.19          │
│  ██░░░░░░░░░░░░░░░░░░░░░░░░          │
│  Flash: $0.19                        │
│                                      │
│  ── Subscriptions ────────────────   │
│                                      │
│  Claude Max           $100/mo  ✓     │
│  Rate limit resets in 28 min         │
│                                      │
│  ChatGPT Plus         $20/mo   ✓     │
│  Active · Renews Mar 8               │
│                                      │
│  ── This Week ────────────────────   │
│                                      │
│  Mon ██████░░ $6.20                  │
│  Tue █████████████ $11.40            │
│  Wed ████░░░░ $4.82 (today)          │
│                                      │
│  Weekly total: $22.42                │
│  Monthly pace: $89.68                │
│                                      │
│  ─────────────────────────────────   │
│  ⚠️ Alert: Daily budget 48% used     │
│                                      │
└──────────────────────────────────────┘
```

### Design Principles
- **SF Pro font** (system default — feels native)
- **Monochrome with accent** — dark panel, white text, one accent colour for bars (blue or green)
- **No chrome** — borderless panel, vibrancy/blur background (like macOS native)
- **Bars not charts** — horizontal bars are instantly readable
- **Colour coding:** Green (under 50%), Yellow (50-80%), Red (over 80% of budget)
- **Hover for detail** — hover any bar to see token breakdown (input/output/cache)

### Settings Panel
```
┌──────────────────────────────────────┐
│  ⚙️ Settings                         │
│                                      │
│  ── API Keys ─────────────────────   │
│  Anthropic    sk-ant-...4f2k  ✓      │
│  OpenAI       sk-...8jKl      ✓      │
│  Google AI    AIza...          ✓      │
│  xAI          xai-...         ○      │
│                                      │
│  ── Subscriptions ────────────────   │
│  Claude Max   $100/mo         ✓      │
│  ChatGPT Plus $20/mo          ✓      │
│                                      │
│  ── Alerts ───────────────────────   │
│  Daily budget        $10             │
│  Alert at            80%             │
│  Notification        ✓ Banner        │
│                                      │
│  ── Refresh ──────────────────────   │
│  Poll interval       5 min           │
│  Launch at login     ✓               │
│                                      │
└──────────────────────────────────────┘
```

### Notification
```
┌─────────────────────────────────┐
│ 🔴 TokenMeter                   │
│ Daily budget alert: $8.40/$10   │
│ Anthropic Opus is 70% of spend  │
└─────────────────────────────────┘
```

## Tech Stack
- **SwiftUI** — native macOS, menubar app
- **MenuBarExtra** (macOS 13+) — built-in menubar API
- **Keychain** — secure API key storage (NOT plaintext)
- **UserDefaults** — settings, budget thresholds
- **URLSession** — async API polling
- **UserNotifications** — budget alerts
- **No Electron, no web views** — pure native

## API Integration

### Anthropic
```
GET https://api.anthropic.com/v1/usage
Headers: x-api-key: {key}, anthropic-version: 2023-06-01
```

### OpenAI
```
GET https://api.openai.com/dashboard/billing/usage?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
GET https://api.openai.com/dashboard/billing/subscription
Headers: Authorization: Bearer {key}
```

### Rate Limit Detection (Claude Max)
- Parse `x-ratelimit-*` headers from recent OpenClaw gateway logs
- Or: make a lightweight API call and read the response headers
- Show: requests remaining, reset time

## Distribution
- **v1:** Direct download (.dmg) from landing page — no App Store
- **Payment:** Gumroad or Lemon Squeezy ($5 one-off)
- **Future:** Mac App Store if volume justifies the 30% cut

## File Structure
```
TokenMeter/
├── TokenMeter.xcodeproj
├── TokenMeter/
│   ├── TokenMeterApp.swift        # App entry + MenuBarExtra
│   ├── Views/
│   │   ├── MainPanel.swift        # The dropdown panel
│   │   ├── ProviderRow.swift      # Individual provider bar
│   │   ├── WeeklyChart.swift      # Weekly bar chart
│   │   ├── SettingsView.swift     # Settings panel
│   │   └── SubscriptionRow.swift  # Consumer sub display
│   ├── Models/
│   │   ├── Provider.swift         # Provider data model
│   │   ├── UsageData.swift        # Token/cost data
│   │   └── Settings.swift         # User settings
│   ├── Services/
│   │   ├── AnthropicService.swift # Anthropic API polling
│   │   ├── OpenAIService.swift    # OpenAI API polling
│   │   ├── GoogleAIService.swift  # Google AI polling
│   │   └── KeychainHelper.swift   # Secure key storage
│   └── Assets.xcassets/
└── README.md
```

## Name Options
1. **TokenMeter** — clear, descriptive
2. **BurnRate** — edgier, implies cost awareness
3. **APIWatch** — generic but clear
4. **CostBar** — describes the UI literally

## Landing Page
- Hero: animated menubar mockup showing live spend
- One-liner: "See what your AI costs. One glance."
- Three feature blocks: Real-time tracking / Budget alerts / All providers
- $5 button → Gumroad/Lemon Squeezy
- FAQ: "Does it work with Claude Max?" (honest answer about limitations)
