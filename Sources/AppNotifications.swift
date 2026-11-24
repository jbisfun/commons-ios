import Foundation
import UIKit
import UserNotifications

/// Per-app "Notifications" switches of Settings (settings-ios). `NotificationHub` hides foreground
/// notifications of blocked apps, and blocked apps' pending/delivered notifications are removed
/// when blocking and whenever the process becomes active or leaves the foreground.
/// App ids are the `NotificationHub` names: the port without "-ios" ("calendar", "clock", ...).
@MainActor
public enum AppNotifications {
    public static let disabledAppsKey = "notifications_disabled_apps"

    /// Request identifier prefixes of the ports' notifications, for apps that schedule without a
    /// hub handler and for removing a blocked app's pending notifications.
    public static var identifierPrefixes: [String: [String]] = [
        "calendar": ["fossify-calendar-"],
        "clock": ["alarm-", "timer-", "upcoming-", "missed-"],
        "messages": ["org.fossify.messages."],
    ]

    public nonisolated static var disabledApps: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: disabledAppsKey) ?? [])
    }

    public nonisolated static func isEnabled(_ app: String) -> Bool { !disabledApps.contains(app) }

    public static func setEnabled(_ app: String, _ on: Bool) {
        var set = disabledApps
        if on { set.remove(app) } else { set.insert(app) }
        UserDefaults.standard.set(set.sorted(), forKey: disabledAppsKey)
        purgeDisabled()
    }

    /// Re-enables every app (Reset app preferences).
    public static func enableAll() {
        UserDefaults.standard.removeObject(forKey: disabledAppsKey)
    }

    /// The app that scheduled a request, from its identifier.
    public static func owner(ofIdentifier id: String) -> String? {
        identifierPrefixes.first { $0.value.contains { id.hasPrefix($0) } }?.key
    }

    /// Removes the pending and delivered notifications of blocked apps.
    public static func purgeDisabled() {
        let disabled = disabledApps
        guard !disabled.isEmpty else { return }
        let prefixes = disabled.flatMap { identifierPrefixes[$0] ?? [] }
        guard !prefixes.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        let blocked: @Sendable (String) -> Bool = { id in prefixes.contains { id.hasPrefix($0) } }
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter(blocked)
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
        center.getDeliveredNotifications { delivered in
            let ids = delivered.map(\.request.identifier).filter(blocked)
            if !ids.isEmpty { center.removeDeliveredNotifications(withIdentifiers: ids) }
        }
    }

    private static var observers: [NSObjectProtocol] = []

    /// Purges whenever the process becomes active or resigns active (apps schedule while in front).
    public static func install() {
        guard observers.isEmpty else { return }
        let nc = NotificationCenter.default
        for name in [UIApplication.didBecomeActiveNotification, UIApplication.willResignActiveNotification] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { purgeDisabled() }
            })
        }
    }
}
