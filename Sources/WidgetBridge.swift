import Foundation
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Resolves an app group identifier to the one the running binary is actually entitled to.
///
/// Sideloading re-signs with the user's team and renames groups: Jimpactor (plume and xkit
/// signers) registers `group.X` as `group.X.<TEAMID>` and rewrites bundle ids to
/// `<id>.<TEAMID>` (extensions: `<app id>.<TEAMID>.<suffix>`). A paid team or Xcode keeps the
/// name as written. The code can't know which, so it tries every candidate and keeps the
/// first one `containerURL(forSecurityApplicationGroupIdentifier:)` accepts (iOS returns nil
/// for groups the binary isn't entitled to).
public enum AppGroup {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: String?] = [:]

    /// The entitled identifier for `base`, or nil (no entitlement, e.g. a standalone app or the
    /// launcher built without the group).
    public static func resolve(_ base: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[base] { return hit }
        let found = candidates(base).first { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil }
        cache[base] = .some(found)
        return found
    }

    /// `base`, the groups listed in the embedded provisioning profiles that extend it, then
    /// `base.<TEAMID>` for the profile's team and every team-id-looking bundle id component.
    static func candidates(_ base: String) -> [String] {
        var out = [base]
        func add(_ s: String) { if !out.contains(s) { out.append(s) } }
        for profile in profiles() {
            for g in profile.groups where g == base || g.hasPrefix(base + ".") { add(g) }
            for team in profile.teams { add("\(base).\(team)") }
        }
        for id in [Bundle.main.bundleIdentifier, containingAppBundle?.bundleIdentifier].compactMap({ $0 }) {
            for part in id.split(separator: ".") where isTeamID(part) { add("\(base).\(part)") }
        }
        return out
    }

    static func isTeamID<S: StringProtocol>(_ s: S) -> Bool {
        s.count == 10 && s.allSatisfy { ($0.isASCII && $0.isUppercase) || $0.isNumber }
    }

    /// The app bundle around an extension (`App.app/PlugIns/X.appex`), else nil.
    private static var containingAppBundle: Bundle? {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "appex" else { return nil }
        return Bundle(url: url.deletingLastPathComponent().deletingLastPathComponent())
    }

    private struct Profile { var groups: [String]; var teams: [String] }

    /// embedded.mobileprovision is CMS-signed with the XML plist in the clear.
    private static func profiles() -> [Profile] {
        [Bundle.main, containingAppBundle].compactMap { bundle -> Profile? in
            guard let url = bundle?.url(forResource: "embedded", withExtension: "mobileprovision"),
                  let data = try? Data(contentsOf: url),
                  let start = data.range(of: Data("<?xml".utf8)),
                  let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
                  let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any]
            else { return nil }
            let entitlements = plist["Entitlements"] as? [String: Any]
            return Profile(groups: entitlements?["com.apple.security.application-groups"] as? [String] ?? [],
                           teams: plist["TeamIdentifier"] as? [String] ?? [])
        }
    }
}

/// Data shared between the apps (inside launcher-ios) and the home-screen widget extension
/// (fossify-ios/widgets-ios), which runs in its own process: Codable snapshots in the launcher's
/// app group, reloads through WidgetCenter, widget tap URLs and in-app actions for intents.
public enum WidgetBridge {
    /// Shared by launcher-ios and its widget extension (renamed by re-signing, see AppGroup).
    public static let appGroup = "group.org.fossify.launcher.ios"
    /// URL scheme of widget taps: `fossify://open/<app>?key=value`.
    public static let scheme = "fossify"

    /// The resolved group, nil when the process isn't entitled (standalone apps): then
    /// publishing does nothing and widgets show their empty state.
    public static var groupIdentifier: String? { AppGroup.resolve(appGroup) }

    public static var containerURL: URL? {
        groupIdentifier.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
    }

    /// Small shared settings (calculator state, month offset, ...).
    public static var defaults: UserDefaults? { groupIdentifier.flatMap { UserDefaults(suiteName: $0) } }

    /// `<group>/Widgets/<relative>`, with its directory created.
    public static func fileURL(_ relative: String) -> URL? {
        guard let url = containerURL?.appendingPathComponent("Widgets", isDirectory: true).appendingPathComponent(relative) else { return nil }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return url
    }

    // MARK: Snapshots

    public static func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let url = fileURL("\(name).json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Writes the snapshot and reloads `kinds` when it changed.
    @discardableResult
    public static func save<T: Encodable>(_ value: T, _ name: String, reload kinds: [String] = []) -> Bool {
        guard let url = fileURL("\(name).json"), let data = try? JSONEncoder().encode(value) else { return false }
        if (try? Data(contentsOf: url)) == data { return false }
        try? data.write(to: url, options: .atomic)
        reload(kinds)
        return true
    }

    public static func reload(_ kinds: [String]) {
        #if canImport(WidgetKit)
        for kind in kinds { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
        #endif
    }

    public static func reloadAll() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: Publishing from the apps

    /// Calls `publish` now and whenever an observable value read by it changes (Observation
    /// tracking, re-armed after every change), debounced by half a second so bursts of edits
    /// (and a publish that touches what it reads) cost one snapshot.
    /// Apps use it from `<App>WidgetData.install()` so their stores need no widget hooks.
    @MainActor
    public static func track(_ publish: @escaping @MainActor () -> Void) {
        Tracker(publish).arm()
    }

    @MainActor
    private final class Tracker {
        let publish: @MainActor () -> Void
        var pending = false
        init(_ publish: @escaping @MainActor () -> Void) { self.publish = publish }

        func arm() {
            withObservationTracking { publish() } onChange: { [self] in
                DispatchQueue.main.async { MainActor.assumeIsolated { self.fire() } }
            }
        }

        private func fire() {
            guard !pending else { return }
            pending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MainActor.assumeIsolated {
                    self.pending = false
                    self.arm()
                }
            }
        }
    }

    /// The Fossify colors widgets fall back to ("theme" color choice): BaseConfig's palette.
    @MainActor
    public static func publishTheme() {
        let c = BaseConfig.shared
        save(WidgetTheme(primary: c.customPrimaryColor, text: c.customTextColor, background: c.customBackgroundColor),
             "theme", reload: [])
    }

    // MARK: Taps

    /// `fossify://open/<app>?key=value`, opened by the launcher (see launcher-ios BundledApp).
    public static func url(_ app: String, _ query: [String: String] = [:]) -> URL {
        var c = URLComponents()
        c.scheme = scheme
        c.host = "open"
        c.path = "/" + app
        if !query.isEmpty { c.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        return c.url!
    }

    /// The app and query of a widget URL, or nil for other URLs.
    public static func parse(_ url: URL) -> (app: String, query: [String: String])? {
        guard url.scheme == scheme, url.host == "open" else { return nil }
        let app = url.pathComponents.dropFirst().first ?? ""
        guard !app.isEmpty else { return nil }
        var query: [String: String] = [:]
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] { query[item.name] = item.value ?? "" }
        return (app, query)
    }

    // MARK: Actions run in the app process

    nonisolated(unsafe) private static var handlers: [String: @MainActor () -> Void] = [:]

    /// Registers an in-app action for widget intents that run in the app process
    /// (AudioPlaybackIntent / openAppWhenRun), e.g. "musicplayer.toggle".
    @MainActor
    public static func register(_ action: String, _ handler: @escaping @MainActor () -> Void) {
        handlers[action] = handler
    }

    /// Runs a registered action; false when this process has none (e.g. the extension).
    @MainActor
    @discardableResult
    public static func perform(_ action: String) -> Bool {
        guard let handler = handlers[action] else { return false }
        handler()
        return true
    }
}
