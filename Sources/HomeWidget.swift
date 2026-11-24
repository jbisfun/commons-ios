import SwiftUI

/// A home-screen widget an app offers to launcher-ios (the counterpart of an Android
/// AppWidgetProvider plus its configure activity). All apps share the launcher's process, so a
/// widget is just a SwiftUI view from the app's Kit, drawn on the launcher's home grid.
///
/// Apps list theirs as `public static let widgets: [HomeWidgetKind]` (e.g. `CalculatorWidgets.all`)
/// and the launcher registers them with its widget picker.
public struct HomeWidgetKind: Identifiable {
    /// Stable id, "<app>.<widget>", e.g. "clock.digital". Saved in the launcher's layout.
    public let id: String
    /// Name shown in the widget picker, e.g. "Digital clock".
    public let title: String
    /// Initial and minimum size in home grid cells (Android's targetCell / minResize).
    public let defaultSize: CGSize
    public let minSize: CGSize
    /// Whether the user may resize it (Android's resizeMode != none).
    public let resizable: Bool
    /// The configure activity, shown when the widget is placed (and from "Reconfigure").
    /// Call `done(true)` to keep the widget, `done(false)` to cancel placing it.
    public let configure: ((HomeWidgetContext, @escaping (Bool) -> Void) -> AnyView)?
    /// The widget itself.
    public let content: (HomeWidgetContext) -> AnyView

    public init(id: String, title: String, defaultSize: CGSize, minSize: CGSize? = nil, resizable: Bool = true,
                configure: ((HomeWidgetContext, @escaping (Bool) -> Void) -> AnyView)? = nil,
                content: @escaping (HomeWidgetContext) -> AnyView) {
        self.id = id
        self.title = title
        self.defaultSize = defaultSize
        self.minSize = minSize ?? defaultSize
        self.resizable = resizable
        self.configure = configure
        self.content = content
    }
}

/// What a placed widget gets from the launcher.
public struct HomeWidgetContext {
    /// Unique per placed widget (Android's appWidgetId): key per-widget settings with it.
    public let instanceID: String
    /// Current size in grid cells.
    public let size: CGSize
    /// Opens the widget's app (optionally handing it a URL, like the PendingIntent of a widget click).
    public let openApp: (URL?) -> Void

    public init(instanceID: String, size: CGSize, openApp: @escaping (URL?) -> Void) {
        self.instanceID = instanceID
        self.size = size
        self.openApp = openApp
    }

    /// UserDefaults key for a per-widget setting, e.g. `context.key("color")`.
    public func key(_ name: String) -> String { "widget_\(instanceID)_\(name)" }
}
