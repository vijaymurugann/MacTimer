import Foundation
import AppKit
import CoreGraphics

final class ScreenTimeTracker: NSObject, @unchecked Sendable {

    // ── Public State ──────────────────────────────────────────────────────────

    private(set) var currentAppName: String?
    private(set) var currentBundleId: String?
    private(set) var currentDomain: String?
    private(set) var currentPageTitle: String?
    private(set) var isIdle: Bool = false
    private(set) var pauseUntil: Date? = nil

    var isPaused: Bool {
        if let pauseUntil = pauseUntil {
            return Date() < pauseUntil
        }
        return false
    }

    var pauseRemaining: TimeInterval {
        guard let pauseUntil = pauseUntil else { return 0 }
        return max(0, pauseUntil.timeIntervalSince(Date()))
    }

    /// Callback whenever session changes, pause expires, or idle flips
    var onChange: (() -> Void)?

    // ── Private State ─────────────────────────────────────────────────────────

    private var sessions: [AppSession] = []
    private var currentSession: AppSession?
    private let logFileURL: URL
    private var idleTimer: Timer?
    private var pauseCheckTimer: Timer?
    private var browserPollTimer: Timer?

    // ── Init ──────────────────────────────────────────────────────────────────

    override init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        logFileURL = home.appendingPathComponent("MacTimer-log.json")
        super.init()
        loadSessions()
        setupObservers()
        startTimers()

        if let active = NSWorkspace.shared.frontmostApplication {
            startSession(for: active)
        }
    }

    // ── NSWorkspace Notifications ─────────────────────────────────────────────

    private func setupObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(appDidActivate(_:)),
                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDidTerminate(_:)),
                       name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(screenDidSleep),
                       name: NSWorkspace.screensDidSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(screenDidWake),
                       name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    @objc private func appDidActivate(_ note: Notification) {
        guard !isIdle, !isPaused else { return }
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        endCurrentSession()
        startSession(for: app)
    }

    @objc private func appDidTerminate(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              currentSession?.bundleIdentifier == (app.bundleIdentifier ?? "") else { return }
        stopBrowserTracking()
        endCurrentSession()
        currentAppName = nil
        currentBundleId = nil
        currentDomain = nil
        currentPageTitle = nil
        onChange?()
    }

    @objc private func screenDidSleep() {
        stopBrowserTracking()
        endCurrentSession()
        isIdle = true
        currentAppName = nil
        currentBundleId = nil
        currentDomain = nil
        currentPageTitle = nil
        onChange?()
    }

    @objc private func screenDidWake() {
        isIdle = false
        if !isPaused, let active = NSWorkspace.shared.frontmostApplication {
            startSession(for: active)
        }
    }

    // ── Timers & Idle Detection ───────────────────────────────────────────────

    private func startTimers() {
        // Idle checker
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }
        RunLoop.main.add(idleTimer!, forMode: .common)

        // Pause expiration checker
        pauseCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let pauseUntil = self.pauseUntil, Date() >= pauseUntil {
                self.pauseUntil = nil
                if let active = NSWorkspace.shared.frontmostApplication {
                    self.startSession(for: active)
                }
                self.onChange?()
            }
        }
        RunLoop.main.add(pauseCheckTimer!, forMode: .common)
    }

    private func checkIdleState() {
        guard !isPaused else { return }
        let threshold = Prefs.idleThresholdMinutes
        guard threshold > 0 else { return }

        let idleSec = systemIdleSeconds()
        let thresholdSec = TimeInterval(threshold * 60)

        if !isIdle && idleSec >= thresholdSec {
            isIdle = true
            stopBrowserTracking()
            endCurrentSession()
            currentAppName = nil
            currentBundleId = nil
            currentDomain = nil
            currentPageTitle = nil
            onChange?()
        } else if isIdle && idleSec < thresholdSec {
            isIdle = false
            if let active = NSWorkspace.shared.frontmostApplication {
                startSession(for: active)
            }
            onChange?()
        }
    }

    private func systemIdleSeconds() -> TimeInterval {
        let mouse  = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let scroll = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .scrollWheel)
        let key    = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let click  = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        return min(min(mouse, scroll), min(key, click))
    }

    func refreshIdleThreshold() {
        if isIdle && Prefs.idleThresholdMinutes == 0 {
            isIdle = false
            if !isPaused, let active = NSWorkspace.shared.frontmostApplication {
                startSession(for: active)
            }
            onChange?()
        }
    }

    // ── Pause / Coffee Break Mode ─────────────────────────────────────────────

    func togglePause(minutes: Int = 15) {
        if isPaused {
            // Resume
            pauseUntil = nil
            if let active = NSWorkspace.shared.frontmostApplication {
                startSession(for: active)
            }
        } else {
            // Pause
            stopBrowserTracking()
            endCurrentSession()
            pauseUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
            currentAppName = nil
            currentBundleId = nil
            currentDomain = nil
            currentPageTitle = nil
        }
        onChange?()
    }

    func resumeNow() {
        pauseUntil = nil
        if let active = NSWorkspace.shared.frontmostApplication {
            startSession(for: active)
        }
        onChange?()
    }

    // ── Session Control ───────────────────────────────────────────────────────

    private func startSession(for app: NSRunningApplication) {
        guard !isPaused else { return }
        let name   = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
        let bundle = app.bundleIdentifier ?? "unknown"
        currentSession  = AppSession(appName: name, bundleIdentifier: bundle, startTime: Date())
        currentAppName  = name
        currentBundleId = bundle
        currentDomain   = nil
        currentPageTitle = nil
        onChange?()

        if Prefs.trackWebsitesEnabled && BrowserTracker.shared.isSupportedBrowser(bundleId: bundle) {
            startBrowserTracking(for: bundle, appName: name)
        } else {
            stopBrowserTracking()
        }
    }

    private func endCurrentSession() {
        guard var s = currentSession else { return }
        s.endTime = Date()
        if let domain = currentDomain, s.domain == nil {
            s.domain = domain
            s.pageTitle = currentPageTitle
        }
        // Ignore micro sessions < 1s (like quick alt-tab glides)
        if s.duration >= 1.0 {
            sessions.append(s)
            saveSessions()
        }
        currentSession = nil
    }

    // ── Browser Tracking ──────────────────────────────────────────────────────

    private func startBrowserTracking(for bundleId: String, appName: String) {
        stopBrowserTracking()

        // Immediate tab query
        checkActiveBrowserTab(bundleId: bundleId, appName: appName)

        // Poll every 1.5 seconds while frontmost
        browserPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self,
                  !self.isPaused,
                  !self.isIdle,
                  self.currentBundleId == bundleId else { return }
            self.checkActiveBrowserTab(bundleId: bundleId, appName: appName)
        }
        if let timer = browserPollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopBrowserTracking() {
        browserPollTimer?.invalidate()
        browserPollTimer = nil
    }

    private func checkActiveBrowserTab(bundleId: String, appName: String) {
        guard Prefs.trackWebsitesEnabled else { return }
        BrowserTracker.shared.queryActiveTab(bundleId: bundleId) { [weak self] tabInfo in
            guard let self = self,
                  !self.isPaused,
                  !self.isIdle,
                  self.currentBundleId == bundleId else { return }

            let newDomain = tabInfo?.domain
            let newTitle = tabInfo?.title

            if newDomain != self.currentDomain {
                if let cur = self.currentSession, cur.domain == nil, self.currentDomain == nil {
                    // Initial domain discovered for the new browser session
                    self.currentSession?.domain = newDomain
                    self.currentSession?.pageTitle = newTitle
                    self.currentDomain = newDomain
                    self.currentPageTitle = newTitle
                    self.onChange?()
                } else {
                    // Tab or domain changed (e.g. YouTube -> Pinterest)
                    if self.currentSession != nil {
                        self.endCurrentSession()
                    }
                    self.currentSession = AppSession(
                        appName: appName,
                        bundleIdentifier: bundleId,
                        domain: newDomain,
                        pageTitle: newTitle,
                        startTime: Date()
                    )
                    self.currentDomain = newDomain
                    self.currentPageTitle = newTitle
                    self.onChange?()
                }
            } else if newTitle != self.currentPageTitle {
                self.currentPageTitle = newTitle
                self.currentSession?.pageTitle = newTitle
                self.onChange?()
            }
        }
    }

    // ── Analytics & Queries ───────────────────────────────────────────────────

    /// Today's apps with relative percentage and session counts
    func todaySummary() -> [AppSummary] {
        return summaryForDate(dateFmt.string(from: Date()), includeLive: true)
    }

    /// Today's total active duration (including live session)
    func todayTotalDuration() -> TimeInterval {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        var all = sessions
        if let cur = currentSession, !isPaused, !isIdle {
            var live = cur
            live.endTime = now
            all.append(live)
        }

        var total: TimeInterval = 0
        for s in all {
            total += s.overlap(withStart: startOfDay, end: now)
        }
        return total
    }

    /// Any day's app totals with nested browser website sub-menus
    func summaryForDate(_ dateString: String, includeLive: Bool = false) -> [AppSummary] {
        var all = sessions
        let isToday = (dateString == dateFmt.string(from: Date()))
        if isToday, includeLive, var cur = currentSession, !isPaused, !isIdle {
            cur.endTime = Date()
            all.append(cur)
        }

        let daySessions = all.filter { dateFmt.string(from: $0.startTime) == dateString }
        var appTotals: [String: (bundle: String, duration: TimeInterval, count: Int, domains: [String: (duration: TimeInterval, count: Int)])] = [:]

        for s in daySessions {
            let key = s.appName
            let existing = appTotals[key] ?? (bundle: s.bundleIdentifier, duration: 0, count: 0, domains: [:])
            let bundle = existing.bundle.isEmpty || existing.bundle == "unknown" ? s.bundleIdentifier : existing.bundle
            var domains = existing.domains
            if let dom = s.domain, !dom.isEmpty {
                let prev = domains[dom] ?? (duration: 0, count: 0)
                domains[dom] = (duration: prev.duration + s.duration, count: prev.count + 1)
            }
            appTotals[key] = (bundle: bundle, duration: existing.duration + s.duration, count: existing.count + 1, domains: domains)
        }

        let totalDaySeconds = appTotals.values.reduce(0.0) { $0 + $1.duration }
        let sorted = appTotals.sorted { $0.value.duration > $1.value.duration }

        return sorted.map { (name, info) in
            let pct = totalDaySeconds > 0 ? (info.duration / totalDaySeconds) : 0.0
            let topDom = info.domains.max(by: { $0.value.duration < $1.value.duration })?.key

            let subItems: [WebsiteSubItem] = info.domains
                .sorted { $0.value.duration > $1.value.duration }
                .map { (dom, subInfo) in
                    let sitePct = info.duration > 0 ? (subInfo.duration / info.duration) : 0.0
                    let isActive = (isToday && name == self.currentAppName && dom == self.currentDomain && !self.isIdle && !self.isPaused)
                    return WebsiteSubItem(
                        domain: dom,
                        duration: subInfo.duration,
                        sessionCount: subInfo.count,
                        percentage: sitePct,
                        isCurrentlyActive: isActive
                    )
                }

            return AppSummary(
                name: name,
                bundleIdentifier: info.bundle,
                duration: info.duration,
                sessionCount: info.count,
                percentage: pct,
                topDomain: topDom,
                domainsCount: info.domains.count,
                websites: subItems
            )
        }
    }

    /// Any day's website totals
    func websitesSummaryForDate(_ dateString: String, includeLive: Bool = false) -> [WebsiteSummary] {
        var all = sessions
        let isToday = (dateString == dateFmt.string(from: Date()))
        if isToday, includeLive, var cur = currentSession {
            cur.endTime = Date()
            all.append(cur)
        }

        let daySessions = all.filter {
            dateFmt.string(from: $0.startTime) == dateString &&
            $0.domain != nil &&
            !($0.domain!.isEmpty)
        }

        var siteTotals: [String: (browser: String, bundle: String, duration: TimeInterval, count: Int)] = [:]

        for s in daySessions {
            guard let dom = s.domain else { continue }
            let existing = siteTotals[dom] ?? (browser: s.appName, bundle: s.bundleIdentifier, duration: 0, count: 0)
            siteTotals[dom] = (
                browser: existing.browser,
                bundle: existing.bundle,
                duration: existing.duration + s.duration,
                count: existing.count + 1
            )
        }

        let totalWebSeconds = siteTotals.values.reduce(0.0) { $0 + $1.duration }
        let sorted = siteTotals.sorted { $0.value.duration > $1.value.duration }

        return sorted.map { (dom, info) in
            let pct = totalWebSeconds > 0 ? (info.duration / totalWebSeconds) : 0.0
            return WebsiteSummary(
                domain: dom,
                browserName: info.browser,
                browserBundle: info.bundle,
                duration: info.duration,
                sessionCount: info.count,
                percentage: pct
            )
        }
    }

    /// Today's websites summary
    func todayWebsitesSummary() -> [WebsiteSummary] {
        return websitesSummaryForDate(dateFmt.string(from: Date()), includeLive: true)
    }

    /// Past 7 days summary for the mini calendar strip
    func sevenDaySummaries() -> [DaySummary] {
        let calendar = Calendar.current
        let today = Date()
        let todayStr = dateFmt.string(from: today)

        var result: [DaySummary] = []

        let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

        for offset in (0...6).reversed() {
            guard let dayDate = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dStr = dateFmt.string(from: dayDate)
            let isToday = (dStr == todayStr)

            let apps = summaryForDate(dStr, includeLive: isToday)
            let dayTotal = apps.reduce(0.0) { $0 + $1.duration }

            let weekdayIndex = calendar.component(.weekday, from: dayDate) - 1
            let dayLetter = (weekdayIndex >= 0 && weekdayIndex < 7) ? dayLetters[weekdayIndex] : "•"
            let dayNum = "\(calendar.component(.day, from: dayDate))"

            result.append(DaySummary(
                dateString: dStr,
                date: dayDate,
                dayOfWeek: dayLetter,
                dayNumber: dayNum,
                totalDuration: dayTotal,
                isToday: isToday,
                topAppName: apps.first?.name
            ))
        }

        return result
    }

    /// Hourly activity distribution for the given date (24 bars or 12 active hours)
    func hourlyActivities(for dateString: String) -> [HourlyActivity] {
        let calendar = Calendar.current
        guard let targetDate = dateFmt.date(from: dateString) else { return [] }

        var all = sessions
        let isToday = (dateString == dateFmt.string(from: Date()))
        if isToday, var cur = currentSession {
            cur.endTime = Date()
            all.append(cur)
        }

        let startOfDay = calendar.startOfDay(for: targetDate)
        let currentHour = calendar.component(.hour, from: Date())

        var hourSeconds = [Double](repeating: 0.0, count: 24)

        for hour in 0..<24 {
            guard let windowStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay),
                  let windowEnd = calendar.date(byAdding: .hour, value: hour + 1, to: startOfDay) else { continue }

            for s in all {
                let overlap = s.overlap(withStart: windowStart, end: windowEnd)
                hourSeconds[hour] += overlap
            }
        }

        let maxHourDuration = max(1.0, hourSeconds.max() ?? 1.0)

        // Select sensible display range: e.g. 6:00 to 23:00 (18 hours) or 8 key buckets
        // Let's create an 8-slot grouped view or all active slots
        var result: [HourlyActivity] = []
        for h in 6...22 { // 6 AM to 10 PM
            let dur = hourSeconds[h]
            let intensity = dur / maxHourDuration

            let label: String
            switch h {
            case 6: label = "6a"
            case 9: label = "9a"
            case 12: label = "12p"
            case 15: label = "3p"
            case 18: label = "6p"
            case 21: label = "9p"
            default: label = ""
            }

            result.append(HourlyActivity(
                id: h,
                hourLabel: label,
                duration: dur,
                intensity: intensity,
                isCurrentHour: (isToday && h == currentHour)
            ))
        }

        return result
    }

    /// Current live session duration
    func currentSessionDuration() -> TimeInterval {
        guard let s = currentSession else { return 0 }
        return Date().timeIntervalSince(s.startTime)
    }

    /// Clears all recorded history
    func clearHistory() {
        sessions.removeAll()
        saveSessions()
        onChange?()
    }

    // ── Persistence ───────────────────────────────────────────────────────────

    private func loadSessions() {
        guard FileManager.default.fileExists(atPath: logFileURL.path),
              let data = try? Data(contentsOf: logFileURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        sessions = (try? dec.decode([AppSession].self, from: data)) ?? []
    }

    private func saveSessions() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(sessions) else { return }
        try? data.write(to: logFileURL, options: .atomic)
    }
}
