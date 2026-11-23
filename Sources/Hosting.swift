import SwiftUI

private struct CloseAppKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Set when an app runs inside the launcher: returns to the launcher's home
    /// screen. Standalone apps leave it nil and show no home button.
    public var closeApp: (() -> Void)? {
        get { self[CloseAppKey.self] }
        set { self[CloseAppKey.self] = newValue }
    }
}

/// Home button an app's main screen shows when hosted by the launcher.
public struct CloseAppButton: View {
    @Environment(\.closeApp) private var closeApp

    public init() {}

    public var body: some View {
        if let closeApp {
            IconButton(icon: "square.grid.2x2", action: closeApp)
        }
    }
}
