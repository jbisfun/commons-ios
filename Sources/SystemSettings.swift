import SwiftUI
import UIKit

/// Settings that a component outside the Settings app owns (the counterpart of Android's injected
/// settings / Settings.ACTION_* entry points). launcher-ios registers its own (wallpaper, home
/// screen, navigation bar, ...) and the bundled apps' system-wide ones at startup; settings-ios
/// shows every registered entry inside the matching AOSP category.
public struct SystemSettingsEntry: Identifiable {
    /// AOSP top-level categories that entries can join.
    public enum Category: String, CaseIterable {
        case apps, notifications, storage, display, wallpaper, accessibility, security, system
    }

    /// Stable id, e.g. "launcher.wallpaper".
    public let id: String
    public let category: Category
    public let title: String
    public let summary: String?
    /// SF Symbol.
    public let icon: String
    /// Words the settings search matches besides the title.
    public let keywords: [String]
    /// The screen pushed when the entry is tapped.
    public let destination: () -> AnyView

    public init(id: String, category: Category, title: String, summary: String? = nil, icon: String,
                keywords: [String] = [], destination: @escaping () -> AnyView) {
        self.id = id
        self.category = category
        self.title = title
        self.summary = summary
        self.icon = icon
        self.keywords = keywords
        self.destination = destination
    }
}

/// An app the host knows about (launcher-ios registers its bundled apps), for Settings > Apps.
public struct SystemAppEntry: Identifiable {
    public var id: String { info.port }
    public let info: AppInfo
    public let icon: UIImage?
    /// Opens the app.
    public let open: () -> Void
    /// The app's own settings screen, if it can be shown outside the app (nil = open the app).
    public let settings: (() -> AnyView)?

    public init(info: AppInfo, icon: UIImage?, open: @escaping () -> Void, settings: (() -> AnyView)? = nil) {
        self.info = info
        self.icon = icon
        self.open = open
        self.settings = settings
    }
}

@MainActor
public enum SystemSettingsRegistry {
    public private(set) static var entries: [SystemSettingsEntry] = []
    /// Set by the host at startup.
    public static var apps: [SystemAppEntry] = []

    /// Adds or replaces (same id) an entry.
    public static func register(_ entry: SystemSettingsEntry) {
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
    }

    public static func entries(in category: SystemSettingsEntry.Category) -> [SystemSettingsEntry] {
        entries.filter { $0.category == category }
    }
}
