import Foundation
import UserNotifications

/// The one `UNUserNotificationCenter` delegate of the process. iOS allows a single delegate and a
/// single category set per app, so apps sharing a process (launcher-ios) register their handlers
/// and categories here instead of setting them on the center directly.
@MainActor
public enum NotificationHub {
    public struct Handler {
        /// Presentation options for a notification in the foreground, nil if it isn't this app's.
        public var willPresent: @MainActor (UNNotification) -> UNNotificationPresentationOptions?
        /// Handles a response, false if it isn't this app's.
        public var didReceive: @MainActor (UNNotificationResponse) -> Bool

        public init(willPresent: @escaping @MainActor (UNNotification) -> UNNotificationPresentationOptions?,
                    didReceive: @escaping @MainActor (UNNotificationResponse) -> Bool) {
            self.willPresent = willPresent
            self.didReceive = didReceive
        }
    }

    private static var handlers: [(String, Handler)] = []
    private static var categories: [String: Set<UNNotificationCategory>] = [:]

    /// Installs the hub as the center's delegate and adds (or replaces) the handler of `app`.
    public static func register(_ app: String, _ handler: Handler) {
        handlers.removeAll { $0.0 == app }
        handlers.append((app, handler))
        UNUserNotificationCenter.current().delegate = HubDelegate.shared
        AppNotifications.install()
    }

    /// Apps with a registered handler.
    public static var registeredApps: [String] { handlers.map(\.0) }

    /// Replaces the categories of `app`, keeping the other apps' ones.
    public static func setCategories(_ app: String, _ set: Set<UNNotificationCategory>) {
        categories[app] = set
        UNUserNotificationCenter.current().setNotificationCategories(categories.values.reduce(into: Set()) { $0.formUnion($1) })
    }

    fileprivate static func willPresent(_ n: UNNotification) -> UNNotificationPresentationOptions {
        // Apps blocked in Settings > Notifications present nothing.
        for (app, h) in handlers { if let o = h.willPresent(n) { return AppNotifications.isEnabled(app) ? o : [] } }
        if let app = AppNotifications.owner(ofIdentifier: n.request.identifier), !AppNotifications.isEnabled(app) { return [] }
        return [.banner, .list, .sound]
    }

    fileprivate static func didReceive(_ r: UNNotificationResponse) {
        for (_, h) in handlers where h.didReceive(r) { return }
    }
}

private final class HubDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = HubDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        DispatchQueue.main.async {
            completionHandler(MainActor.assumeIsolated { NotificationHub.willPresent(notification) })
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { NotificationHub.didReceive(response) }
            completionHandler()
        }
    }
}
