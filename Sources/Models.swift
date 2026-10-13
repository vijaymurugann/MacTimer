import Foundation

// ─── Core Data Models ─────────────────────────────────────────────────────────

struct AppSession: Codable {
    let appName: String
    let bundleIdentifier: String
    var domain: String?
    var pageTitle: String?
    let startTime: Date
    var endTime: Date?

    init(
        appName: String,
        bundleIdentifier: String,
        domain: String? = nil,
        pageTitle: String? = nil,
        startTime: Date,
        endTime: Date? = nil
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.domain = domain
        self.pageTitle = pageTitle
        self.startTime = startTime
        self.endTime = endTime
    }

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    /// Calculates seconds of overlap with a specific time window [windowStart, windowEnd]
    func overlap(withStart windowStart: Date, end windowEnd: Date) -> TimeInterval {
        let sEnd = endTime ?? Date()
        let start = max(startTime, windowStart)
        let finish = min(sEnd, windowEnd)
        let diff = finish.timeIntervalSince(start)
        return max(0, diff)
    }
}

// ─── Summary Models for SwiftUI ───────────────────────────────────────────────

struct WebsiteSubItem: Identifiable, Equatable {
    var id: String { domain }
    let domain: String
    let duration: TimeInterval
    let sessionCount: Int
    let percentage: Double // 0.0 ... 1.0 of the parent browser's total duration
    let isCurrentlyActive: Bool

    static func == (lhs: WebsiteSubItem, rhs: WebsiteSubItem) -> Bool {
        lhs.domain == rhs.domain &&
        lhs.duration == rhs.duration &&
        lhs.percentage == rhs.percentage &&
        lhs.isCurrentlyActive == rhs.isCurrentlyActive
    }
}

struct AppSummary: Identifiable, Equatable {
    var id: String { bundleIdentifier.isEmpty ? name : bundleIdentifier }
    let name: String
    let bundleIdentifier: String
    let duration: TimeInterval
    let sessionCount: Int
    let percentage: Double // 0.0 ... 1.0 of the day's total
    var topDomain: String? = nil
    var domainsCount: Int = 0
    var websites: [WebsiteSubItem] = []

    static func == (lhs: AppSummary, rhs: AppSummary) -> Bool {
        lhs.id == rhs.id &&
        lhs.duration == rhs.duration &&
        lhs.percentage == rhs.percentage &&
        lhs.topDomain == rhs.topDomain &&
        lhs.websites == rhs.websites
    }
}

struct WebsiteSummary: Identifiable, Equatable {
    var id: String { "\(browserBundle):\(domain)" }
    let domain: String
    let browserName: String
    let browserBundle: String
    let duration: TimeInterval
    let sessionCount: Int
    let percentage: Double // 0.0 ... 1.0 of total website time

    static func == (lhs: WebsiteSummary, rhs: WebsiteSummary) -> Bool {
        lhs.id == rhs.id && lhs.duration == rhs.duration && lhs.percentage == rhs.percentage
    }
}

struct DaySummary: Identifiable, Equatable {
    var id: String { dateString }
    let dateString: String // yyyy-MM-dd
    let date: Date
    let dayOfWeek: String // "M", "T", "W", "T", "F", "S", "S"
    let dayNumber: String // "8", "9"
    let totalDuration: TimeInterval
    let isToday: Bool
    let topAppName: String?
}

struct HourlyActivity: Identifiable {
    let id: Int // Hour 0...23
    let hourLabel: String // "9A", "12P", "3P"
    let duration: TimeInterval
    let intensity: Double // 0.0 ... 1.0 relative to peak hour
    let isCurrentHour: Bool
}

// ─── Formatting Helpers ───────────────────────────────────────────────────────

func formatDuration(_ interval: TimeInterval) -> String {
    let secs = Int(max(0, interval))
    let h = secs / 3600
    let m = (secs % 3600) / 60
    let s = secs % 60
    if h > 0 { return "\(h)h \(m)m" }
    if m > 0 { return "\(m)m \(s)s" }
    return "\(s)s"
}

func formatDurationShort(_ interval: TimeInterval) -> String {
    let secs = Int(max(0, interval))
    let h = secs / 3600
    let m = (secs % 3600) / 60
    if h > 0 {
        let decimal = Double(m) / 60.0
        return String(format: "%.1fh", Double(h) + decimal)
    }
    if m > 0 { return "\(m)m" }
    return "\(secs)s"
}

func formatStopwatch(_ interval: TimeInterval) -> String {
    let secs = Int(max(0, interval))
    let h = secs / 3600
    let m = (secs % 3600) / 60
    let s = secs % 60
    if h > 0 {
        return String(format: "%02d:%02d:%02d", h, m, s)
    } else {
        return String(format: "%02d:%02d", m, s)
    }
}

let dateFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
}()

let displayDateFmt: DateFormatter = {
    let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
}()

let monthYearFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "MMM yyyy"; return f
}()

// ─── User Preferences (stored in UserDefaults) ────────────────────────────────

enum Prefs {
    static var idleThresholdMinutes: Int {
        get {
            guard UserDefaults.standard.object(forKey: "idleMinutes") != nil else { return 5 }
            return UserDefaults.standard.integer(forKey: "idleMinutes")
        }
        set { UserDefaults.standard.set(newValue, forKey: "idleMinutes") }
    }

    static var alertThresholdHours: Int {
        get {
            guard UserDefaults.standard.object(forKey: "alertHours") != nil else { return 2 }
            return UserDefaults.standard.integer(forKey: "alertHours")
        }
        set { UserDefaults.standard.set(newValue, forKey: "alertHours") }
    }

    static var alertsEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: "alertsEnabled") != nil else { return true }
            return UserDefaults.standard.bool(forKey: "alertsEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "alertsEnabled") }
    }

    static var dailyGoalHours: Int {
        get {
            guard UserDefaults.standard.object(forKey: "dailyGoalHours") != nil else { return 6 }
            return UserDefaults.standard.integer(forKey: "dailyGoalHours")
        }
        set { UserDefaults.standard.set(newValue, forKey: "dailyGoalHours") }
    }

    // ── 20-20-20 Eye Health Rule ──────────────────────────────────────────────
    static var eyeCareEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: "eyeCareEnabled") != nil else { return true }
            return UserDefaults.standard.bool(forKey: "eyeCareEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "eyeCareEnabled") }
    }

    static var eyeCareIntervalMinutes: Int {
        get {
            guard UserDefaults.standard.object(forKey: "eyeCareIntervalMinutes") != nil else { return 20 }
            return UserDefaults.standard.integer(forKey: "eyeCareIntervalMinutes")
        }
        set { UserDefaults.standard.set(newValue, forKey: "eyeCareIntervalMinutes") }
    }

    static var eyeCareDurationSeconds: Int {
        get {
            guard UserDefaults.standard.object(forKey: "eyeCareDurationSeconds") != nil else { return 20 }
            return UserDefaults.standard.integer(forKey: "eyeCareDurationSeconds")
        }
        set { UserDefaults.standard.set(newValue, forKey: "eyeCareDurationSeconds") }
    }

    static var eyeCareSoundEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: "eyeCareSoundEnabled") != nil else { return true }
            return UserDefaults.standard.bool(forKey: "eyeCareSoundEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "eyeCareSoundEnabled") }
    }

    // ── Browser Website Tracking ──────────────────────────────────────────────
    static var trackWebsitesEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: "trackWebsitesEnabled") != nil else { return true }
            return UserDefaults.standard.bool(forKey: "trackWebsitesEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "trackWebsitesEnabled") }
    }
}
