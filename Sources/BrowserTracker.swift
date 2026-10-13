import Foundation
import AppKit

/// Information regarding the currently active browser tab
struct ActiveTabInfo: Equatable, Sendable {
    let rawUrl: String
    let domain: String
    let title: String
}

/// Identifies supported browser engines and formats the required AppleScript
enum SupportedBrowser: String, CaseIterable, Sendable {
    case chrome
    case brave
    case safari
    case arc
    case edge

    static func detect(bundleId: String) -> SupportedBrowser? {
        switch bundleId.lowercased() {
        case "com.google.chrome",
             "com.google.chrome.canary",
             "com.google.chrome.dev",
             "com.google.chrome.beta":
            return .chrome

        case "com.brave.browser",
             "com.brave.browser.beta",
             "com.brave.browser.nightly":
            return .brave

        case "com.apple.safari",
             "com.apple.safaritechnologypreview":
            return .safari

        case "company.thebrowser.browser":
            return .arc

        case "com.microsoft.edgemac",
             "com.microsoft.edgemac.beta",
             "com.microsoft.edgemac.dev":
            return .edge

        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .chrome: return "Chrome"
        case .brave:  return "Brave"
        case .safari: return "Safari"
        case .arc:    return "Arc"
        case .edge:   return "Edge"
        }
    }

    /// Constructs the AppleScript targeted to this browser's bundle identifier
    func appleScript(for bundleId: String) -> String {
        switch self {
        case .chrome, .brave, .arc, .edge:
            return """
            tell application id "\(bundleId)"
                if (count of windows) > 0 then
                    set aTab to active tab of front window
                    return {URL of aTab, title of aTab}
                end if
            end tell
            """
        case .safari:
            return """
            tell application id "\(bundleId)"
                if (count of windows) > 0 then
                    set aTab to current tab of front window
                    return {URL of aTab, name of aTab}
                end if
            end tell
            """
        }
    }
}

/// Service that queries frontmost browser tab information safely and asynchronously
final class BrowserTracker: @unchecked Sendable {
    static let shared = BrowserTracker()

    private let queue = DispatchQueue(label: "com.vijay.mactimer.browserTracker", qos: .userInitiated)
    private var isQuerying = false

    init() {}

    /// Checks if a bundle identifier corresponds to a supported browser
    func isSupportedBrowser(bundleId: String) -> Bool {
        SupportedBrowser.detect(bundleId: bundleId) != nil
    }

    /// Asynchronously fetches the active tab for the frontmost browser
    func queryActiveTab(bundleId: String, completion: @escaping (ActiveTabInfo?) -> Void) {
        guard let browser = SupportedBrowser.detect(bundleId: bundleId) else {
            completion(nil)
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isQuerying else {
                // Skip if an AppleScript query is already in-flight
                return
            }

            self.isQuerying = true
            defer { self.isQuerying = false }

            let scriptSource = browser.appleScript(for: bundleId)
            guard let script = NSAppleScript(source: scriptSource) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            var errorInfo: NSDictionary?
            let descriptor = script.executeAndReturnError(&errorInfo)

            if errorInfo != nil {
                // Error (e.g. permission not granted, window minimized, or app launching)
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Parse list returned by AppleScript: {URL, Title}
            var rawUrl = ""
            var title = ""

            if descriptor.numberOfItems >= 2 {
                rawUrl = descriptor.atIndex(1)?.stringValue ?? ""
                title  = descriptor.atIndex(2)?.stringValue ?? ""
            } else if descriptor.numberOfItems == 1 {
                rawUrl = descriptor.atIndex(1)?.stringValue ?? ""
            }

            guard let domain = Self.extractDomain(from: rawUrl), !domain.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let tabInfo = ActiveTabInfo(rawUrl: rawUrl, domain: domain, title: title)
            DispatchQueue.main.async { completion(tabInfo) }
        }
    }

    /// Normalizes and extracts domain / host from a raw URL string
    static func extractDomain(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Handle internal browser URLs
        let lower = trimmed.lowercased()
        if lower.hasPrefix("chrome://") || lower.hasPrefix("brave://") || lower.hasPrefix("edge://") {
            if lower.contains("newtab") {
                return "New Tab"
            } else if lower.contains("settings") {
                return "Settings"
            } else if lower.contains("extensions") {
                return "Extensions"
            } else if lower.contains("history") {
                return "History"
            } else if lower.contains("bookmarks") {
                return "Bookmarks"
            }
            return "Internal Page"
        }

        if lower == "about:blank" || lower.hasPrefix("about:") {
            return "New Tab"
        }

        if lower.hasPrefix("safari-resource:") || lower.hasPrefix("safari-extension:") {
            return "Safari Start Page"
        }

        // Parse standard Web URL
        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else {
            return nil
        }

        // Clean up common prefixes
        var cleanHost = host
        if cleanHost.hasPrefix("www.") {
            cleanHost = String(cleanHost.dropFirst(4))
        }

        // Retain port for local web development servers
        if let port = url.port, (cleanHost == "localhost" || cleanHost == "127.0.0.1") {
            return "\(cleanHost):\(port)"
        }

        return cleanHost
    }
}
