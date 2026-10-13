import AppKit

final class AppIconProvider: @unchecked Sendable {
    static let shared = AppIconProvider()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 150
    }

    func icon(for bundleId: String, appName: String) -> NSImage {
        let key = "\(bundleId):\(appName)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        var resolvedImage: NSImage?

        // 1. Try URL for bundle identifier
        if !bundleId.isEmpty,
           let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            resolvedImage = NSWorkspace.shared.icon(forFile: appUrl.path)
        }

        // 2. Try running applications
        if resolvedImage == nil && !bundleId.isEmpty {
            if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
               let icon = running.icon {
                resolvedImage = icon
            }
        }

        // 3. Try matching running app by localized name
        if resolvedImage == nil {
            if let running = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }),
               let icon = running.icon {
                resolvedImage = icon
            }
        }

        // 4. Default macOS application icon fallback
        let finalImage = resolvedImage ?? NSWorkspace.shared.icon(for: .application)
        finalImage.size = NSSize(width: 64, height: 64)
        cache.setObject(finalImage, forKey: key)
        return finalImage
    }
}
