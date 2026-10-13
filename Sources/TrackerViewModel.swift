import Foundation
import Combine
import AppKit

final class TrackerViewModel: ObservableObject, @unchecked Sendable {

    // ── Published UI State ────────────────────────────────────────────────────

    @Published var selectedDateString: String = ""
    @Published var entries: [AppSummary] = []
    @Published var websiteEntries: [WebsiteSummary] = []
    @Published var isWebsitesView: Bool = false
    @Published var sevenDays: [DaySummary] = []
    @Published var hourlyBars: [HourlyActivity] = []

    @Published var currentAppName: String? = nil
    @Published var currentBundleId: String? = nil
    @Published var currentDomain: String? = nil
    @Published var currentPageTitle: String? = nil
    @Published var currentDuration: TimeInterval = 0

    @Published var isIdle: Bool = false
    @Published var isPaused: Bool = false
    @Published var pauseRemaining: TimeInterval = 0

    @Published var totalDuration: TimeInterval = 0
    @Published var appsCount: Int = 0
    @Published var topAppName: String = "—"

    @Published var eyeCareTimeRemaining: TimeInterval = 1200
    @Published var isEyeCareEnabled: Bool = Prefs.eyeCareEnabled
    @Published var isTrackWebsitesEnabled: Bool = Prefs.trackWebsitesEnabled

    let tracker: ScreenTimeTracker
    let eyeCareManager: EyeCareManager
    private var tickTimer: Timer?

    init(tracker: ScreenTimeTracker, eyeCareManager: EyeCareManager) {
        self.tracker = tracker
        self.eyeCareManager = eyeCareManager
        self.selectedDateString = dateFmt.string(from: Date())
        self.eyeCareTimeRemaining = eyeCareManager.timeUntilNextBreak
        self.isEyeCareEnabled = Prefs.eyeCareEnabled
        refreshAll()

        // 1-second pulse for real-time live clock, pause countdown, and eye care status
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(tickTimer!, forMode: .common)
    }

    /// Full refresh on app switch, day switch, or idle transition
    func refreshAll() {
        let todayStr = dateFmt.string(from: Date())
        if selectedDateString.isEmpty {
            selectedDateString = todayStr
        }

        let isSelectedToday = (selectedDateString == todayStr)

        entries = tracker.summaryForDate(selectedDateString, includeLive: isSelectedToday)
        websiteEntries = tracker.websitesSummaryForDate(selectedDateString, includeLive: isSelectedToday)
        sevenDays = tracker.sevenDaySummaries()
        hourlyBars = tracker.hourlyActivities(for: selectedDateString)

        currentAppName   = tracker.currentAppName
        currentBundleId  = tracker.currentBundleId
        currentDomain    = tracker.currentDomain
        currentPageTitle = tracker.currentPageTitle
        isIdle           = tracker.isIdle
        isPaused         = tracker.isPaused
        pauseRemaining   = tracker.pauseRemaining
        isTrackWebsitesEnabled = Prefs.trackWebsitesEnabled

        totalDuration   = entries.reduce(0.0) { $0 + $1.duration }
        appsCount       = entries.count
        topAppName      = entries.first?.name ?? "—"
        currentDuration = tracker.currentSessionDuration()
    }

    /// 1-second tick: smoothly update session stopwatch and pause countdown
    private func tick() {
        if tracker.isPaused {
            isPaused = true
            pauseRemaining = tracker.pauseRemaining
            currentDuration = 0
        } else {
            isPaused = false
            currentDuration = tracker.currentSessionDuration()

            // If viewing today, also keep the active app's row duration updated in real time
            let todayStr = dateFmt.string(from: Date())
            if selectedDateString == todayStr {
                entries = tracker.todaySummary()
                websiteEntries = tracker.todayWebsitesSummary()
                totalDuration = entries.reduce(0.0) { $0 + $1.duration }
            }
        }

        currentDomain = tracker.currentDomain
        currentPageTitle = tracker.currentPageTitle
        eyeCareTimeRemaining = eyeCareManager.timeUntilNextBreak
        isEyeCareEnabled = Prefs.eyeCareEnabled
    }

    // ── User Actions ──────────────────────────────────────────────────────────

    func toggleViewMode() {
        isWebsitesView.toggle()
    }

    func updateBrowserTrackingSettings() {
        isTrackWebsitesEnabled = Prefs.trackWebsitesEnabled
        refreshAll()
    }

    func selectDate(_ dStr: String) {
        selectedDateString = dStr
        refreshAll()
    }

    func selectToday() {
        selectedDateString = dateFmt.string(from: Date())
        refreshAll()
    }

    func togglePause(minutes: Int = 15) {
        tracker.togglePause(minutes: minutes)
        refreshAll()
    }

    func resumeNow() {
        tracker.resumeNow()
        refreshAll()
    }

    func updateIdleThreshold() {
        tracker.refreshIdleThreshold()
        refreshAll()
    }

    func triggerEyeCarePreview() {
        eyeCareManager.triggerBreak()
    }

    func skipEyeCareBreak() {
        eyeCareManager.skipBreak()
    }

    func updateEyeCareSettings() {
        isEyeCareEnabled = Prefs.eyeCareEnabled
        eyeCareManager.resetTimer()
    }

    func clearData() {
        tracker.clearHistory()
        refreshAll()
    }
}
