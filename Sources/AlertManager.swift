import AppKit

/// Shows an alert panel when any app exceeds the configured daily usage threshold.
/// Uses NSAlert (no app bundle required, unlike UserNotifications).
final class AlertManager {

    private var notifiedApps: Set<String> = []
    private var currentDay: String = ""

    init() {
        currentDay = dateFmt.string(from: Date())
    }

    func checkAlerts(for summary: [(name: String, duration: TimeInterval)]) {
        guard Prefs.alertsEnabled else { return }

        // Reset on day rollover
        let today = dateFmt.string(from: Date())
        if today != currentDay { currentDay = today; notifiedApps.removeAll() }

        let threshold = TimeInterval(Prefs.alertThresholdHours * 3600)
        for entry in summary {
            guard entry.duration >= threshold,
                  !notifiedApps.contains(entry.name) else { continue }
            notifiedApps.insert(entry.name)
            showAlert(app: entry.name, duration: entry.duration)
        }
    }

    func reset() { notifiedApps.removeAll() }

    private func showAlert(app: String, duration: TimeInterval) {
        DispatchQueue.main.async {
            let alert             = NSAlert()
            alert.messageText     = "MacTimer — Time Check 🕐"
            alert.informativeText = "You've used \(app) for \(formatDuration(duration)) today."
            alert.alertStyle      = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
