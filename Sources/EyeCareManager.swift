import AppKit
import SwiftUI
import Combine

/// Non-activating panel that does not steal focus from the user's active app or typing session.
final class EyeCarePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Manages the 20-20-20 rule timer and floating HUD reminder card.
final class EyeCareManager: ObservableObject, @unchecked Sendable {

    // ── Observable State ──────────────────────────────────────────────────────
    @Published var isBreakActive: Bool = false
    @Published var secondsRemaining: Int = 20
    @Published var timeUntilNextBreak: TimeInterval = 1200

    // ── Dependencies & Private State ──────────────────────────────────────────
    private let tracker: ScreenTimeTracker
    private var elapsedActiveSeconds: TimeInterval = 0
    private var panel: EyeCarePanel?
    private var heartbeatTimer: Timer?

    init(tracker: ScreenTimeTracker) {
        self.tracker = tracker
        self.timeUntilNextBreak = TimeInterval(Prefs.eyeCareIntervalMinutes * 60)
        startHeartbeat()
    }

    deinit {
        heartbeatTimer?.invalidate()
        panel?.orderOut(nil)
    }

    // ── Heartbeat Timer (1Hz) ─────────────────────────────────────────────────

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tick()
            }
        }
        if let timer = heartbeatTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func tick() {
        guard Prefs.eyeCareEnabled else {
            timeUntilNextBreak = TimeInterval(Prefs.eyeCareIntervalMinutes * 60)
            return
        }

        if isBreakActive {
            // Countdown phase
            if secondsRemaining > 1 {
                secondsRemaining -= 1
            } else {
                secondsRemaining = 0
                playBreakSound()
                dismissBreak()
            }
        } else {
            // Active accumulation phase — only increment when user is actively using Mac
            if !tracker.isIdle && !tracker.isPaused {
                elapsedActiveSeconds += 1.0
            }

            let intervalSeconds = TimeInterval(Prefs.eyeCareIntervalMinutes * 60)
            timeUntilNextBreak = max(0, intervalSeconds - elapsedActiveSeconds)

            if elapsedActiveSeconds >= intervalSeconds {
                triggerBreak()
            }
        }
    }

    // ── Break Control ─────────────────────────────────────────────────────────

    /// Triggered automatically every 20 minutes of active screen time, or manually via "Preview".
    func triggerBreak() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.elapsedActiveSeconds = 0
            self.secondsRemaining = Prefs.eyeCareDurationSeconds
            self.isBreakActive = true
            self.timeUntilNextBreak = TimeInterval(Prefs.eyeCareIntervalMinutes * 60)

            self.playBreakSound()
            self.presentPanel()
        }
    }

    /// User manually dismissed the card early via "Skip".
    func skipBreak() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissBreak()
        }
    }

    /// Reset elapsed timer back to 0.
    func resetTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.elapsedActiveSeconds = 0
            self.timeUntilNextBreak = TimeInterval(Prefs.eyeCareIntervalMinutes * 60)
        }
    }

    private func playBreakSound() {
        if Prefs.eyeCareSoundEnabled {
            NSSound(named: "Tink")?.play()
        }
    }

    // ── Panel Management ──────────────────────────────────────────────────────

    private func presentPanel() {
        if panel == nil {
            let p = EyeCarePanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 120),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.isMovableByWindowBackground = true
            panel = p
        }

        guard let panel = panel else { return }

        // Host SwiftUI card view with direct binding to this manager
        let cardView = EyeCareHostingWrapper(manager: self)
        let hostingView = NSHostingView(rootView: cardView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 380, height: 120)
        panel.contentView = hostingView

        // Position at top-right of main screen
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let width: CGFloat = 380
        let height: CGFloat = 120
        let paddingX: CGFloat = 24
        let paddingY: CGFloat = 20

        let posX = visibleFrame.maxX - width - paddingX
        let posY = visibleFrame.maxY - height - paddingY

        panel.setFrame(NSRect(x: posX, y: posY, width: width, height: height), display: true)
        panel.alphaValue = 0.0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }
    }

    private func dismissBreak() {
        guard let panel = panel else {
            isBreakActive = false
            return
        }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.panel?.orderOut(nil)
                self?.isBreakActive = false
            }
        })
    }
}

/// Small wrapper to observe EyeCareManager in SwiftUI
private struct EyeCareHostingWrapper: View {
    @ObservedObject var manager: EyeCareManager

    var body: some View {
        EyeBreakCardView(
            secondsRemaining: manager.secondsRemaining,
            totalDuration: Prefs.eyeCareDurationSeconds,
            onSkip: { [weak manager] in
                manager?.skipBreak()
            }
        )
    }
}
