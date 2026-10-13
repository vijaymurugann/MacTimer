import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem:     NSStatusItem!
    private var tracker:        ScreenTimeTracker!
    private var eyeCareManager: EyeCareManager!
    private var viewModel:      TrackerViewModel!
    private var alertManager:   AlertManager!
    private var popover:        NSPopover!
    private var refreshTimer:   Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // ── Tracker & ViewModel ───────────────────────────────────────────────
        tracker         = ScreenTimeTracker()
        eyeCareManager  = EyeCareManager(tracker: tracker)
        viewModel       = TrackerViewModel(tracker: tracker, eyeCareManager: eyeCareManager)
        alertManager    = AlertManager()

        tracker.onChange = { [weak self] in
            DispatchQueue.main.async {
                self?.viewModel.refreshAll()
                if let summary = self?.tracker.todaySummary() {
                    self?.alertManager.checkAlerts(for: summary.map { ($0.name, $0.duration) })
                }
                self?.refreshButtonTitle()
            }
        }

        // ── Status Bar Item ───────────────────────────────────────────────────
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image         = NSImage(systemSymbolName: "timer", accessibilityDescription: "MacTimer")
            button.imagePosition = .imageLeft
            button.action        = #selector(togglePopover(_:))
            button.target        = self
        }
        refreshButtonTitle()

        // ── Modern Bento Popover ──────────────────────────────────────────────
        let hostingVC = NSHostingController(
            rootView: MenuBarView(viewModel: viewModel)
        )
        hostingVC.view.frame = NSRect(x: 0, y: 0, width: 380, height: 560)

        popover = NSPopover()
        popover.contentSize           = NSSize(width: 380, height: 560)
        popover.behavior              = .transient
        popover.animates              = true
        popover.contentViewController = hostingVC

        // ── 1-second button title refresh ─────────────────────────────────────
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshButtonTitle()
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }

    // ── Toggle Popover ────────────────────────────────────────────────────────

    @objc private func togglePopover(_ sender: AnyObject) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            viewModel.refreshAll()
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // ── Status Bar Label ──────────────────────────────────────────────────────

    private func refreshButtonTitle() {
        guard let button = statusItem?.button else { return }
        let total = formatDuration(tracker.todayTotalDuration())
        button.toolTip = "MacTimer — Today: \(total)"
        if tracker.isPaused {
            button.title = "  ☕ Break"
        } else if tracker.isIdle {
            button.title = "  💤 Idle"
        } else {
            button.title = "  \(total)"
        }
    }
}
