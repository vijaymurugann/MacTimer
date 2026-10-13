import Foundation

/// Manages automatic launch at login via a launchd LaunchAgent plist.
enum LaunchAtLogin {

    private static let label    = "com.vijay.mactimer"
    private static let plistURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/com.vijay.mactimer.plist")
    private static let legacyPlistURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/com.mactimer.app.plist")

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func enable() {
        cleanupLegacy()
        // If running from a proper .app bundle → launch via `open` (cleanest approach).
        // If running directly from binary (dev mode) → use the binary path.
        let bundlePath = Bundle.main.bundlePath
        let programArgs: [String]
        if bundlePath.hasSuffix(".app") {
            programArgs = ["/usr/bin/open", bundlePath]
        } else {
            programArgs = [ProcessInfo.processInfo.arguments[0]]
        }

        let plist: NSDictionary = [
            "Label"           : label,
            "ProgramArguments": programArgs,
            "RunAtLoad"       : true,
            "KeepAlive"       : false,
            "ProcessType"     : "Interactive"
        ]

        let dir = plistURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        plist.write(to: plistURL, atomically: true)
        runLaunchctl(["load", "-w", plistURL.path])
    }

    static func disable() {
        cleanupLegacy()
        guard isEnabled else { return }
        runLaunchctl(["unload", "-w", plistURL.path])
        try? FileManager.default.removeItem(at: plistURL)
    }

    static func toggle() { isEnabled ? disable() : enable() }

    private static func cleanupLegacy() {
        if FileManager.default.fileExists(atPath: legacyPlistURL.path) {
            runLaunchctl(["unload", "-w", legacyPlistURL.path])
            try? FileManager.default.removeItem(at: legacyPlistURL)
        }
    }

    @discardableResult
    private static func runLaunchctl(_ args: [String]) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments     = args
        task.standardOutput = FileHandle.nullDevice
        task.standardError  = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }
}
