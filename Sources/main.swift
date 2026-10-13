import AppKit

// Prevent duplicate instances of MacTimer from running concurrently.
let currentPID = ProcessInfo.processInfo.processIdentifier
let currentBundleId = Bundle.main.bundleIdentifier ?? "com.vijay.mactimer"

let isAlreadyRunning = NSWorkspace.shared.runningApplications.contains { app in
    guard app.processIdentifier != currentPID else { return false }
    if let id = app.bundleIdentifier, id == currentBundleId || id == "com.mactimer.app" {
        return true
    }
    return app.localizedName == "MacTimer" || app.executableURL?.lastPathComponent == "MacTimer"
}

if isAlreadyRunning {
    exit(0)
}

// Wire up the delegate and hand control to NSApplication.
// NSApp.run() starts the main RunLoop — everything else happens in AppDelegate.
let app      = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
