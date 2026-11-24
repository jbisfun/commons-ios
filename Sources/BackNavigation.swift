import SwiftUI

/// OnBackPressedDispatcher for apps hosted by launcher-ios, whose navigation bar Back first dismisses
/// the topmost sheet/alert, then pops the topmost navigation stack, then asks the app's
/// `onBackPressed` callbacks (last registered enabled one wins) before closing the app.
/// Standalone apps have no navigation bar: their callbacks are never called.
@MainActor
public final class BackPressedDispatcher {
    private var callbacks: [(id: UUID, enabled: Bool, action: () -> Void)] = []

    public init() {}

    /// Runs the newest enabled callback; false if there is none (the host then closes the app).
    public func onBackPressed() -> Bool {
        guard let callback = callbacks.last(where: \.enabled) else { return false }
        callback.action()
        return true
    }

    public var hasEnabledCallbacks: Bool { callbacks.contains(where: \.enabled) }

    fileprivate func set(_ id: UUID, enabled: Bool, action: @escaping () -> Void) {
        if let i = callbacks.firstIndex(where: { $0.id == id }) {
            callbacks[i].enabled = enabled
            callbacks[i].action = action
        } else {
            callbacks.append((id, enabled, action))
        }
    }

    fileprivate func remove(_ id: UUID) { callbacks.removeAll { $0.id == id } }
}

private struct BackPressedDispatcherKey: EnvironmentKey {
    static let defaultValue: BackPressedDispatcher? = nil
}

private struct FinishAppKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Set by the launcher for each hosted app.
    public var backPressedDispatcher: BackPressedDispatcher? {
        get { self[BackPressedDispatcherKey.self] }
        set { self[BackPressedDispatcherKey.self] = newValue }
    }

    /// Activity.finish(): closes the hosted app and removes it from recents (e.g. after an
    /// unsaved-changes prompt). Nil when standalone.
    public var finishApp: (() -> Void)? {
        get { self[FinishAppKey.self] }
        set { self[FinishAppKey.self] = newValue }
    }
}

private struct OnBackPressedModifier: ViewModifier {
    @Environment(\.backPressedDispatcher) private var dispatcher
    @State private var id = UUID()
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        // Refreshed on every evaluation so the callback sees the current state.
        let _ = dispatcher?.set(id, enabled: enabled, action: action)
        content
            .onAppear { dispatcher?.set(id, enabled: enabled, action: action) }
            .onDisappear { dispatcher?.remove(id) }
    }
}

extension View {
    /// OnBackPressedCallback: handles the launcher's Back while this view is shown and no sheet or
    /// pushed screen is above it.
    public func onBackPressed(enabled: Bool = true, perform action: @escaping () -> Void) -> some View {
        modifier(OnBackPressedModifier(enabled: enabled, action: action))
    }
}
