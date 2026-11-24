import SwiftUI

/// SettingsPreferenceComponent: a tappable row with an optional value line.
public struct SettingsItem: View {
    @Environment(\.palette) private var palette
    let title: String
    let value: String?
    let action: () -> Void

    public init(_ title: String, value: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.value = value
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16)).foregroundStyle(palette.textColor)
                if let value {
                    Text(value).font(.system(size: 14)).foregroundStyle(palette.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// SettingsSwitchComponent.
public struct SettingsToggle: View {
    @Environment(\.palette) private var palette
    let title: String
    @Binding var isOn: Bool

    public init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            Text(title).font(.system(size: 16)).foregroundStyle(palette.textColor)
        }
        .toggleStyle(CheckmarkSwitchStyle())
        .tint(palette.primaryColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// CustomizationActivity (theme, text/background/primary colors).
public struct CustomizeColorsView: View {
    @Environment(\.palette) private var palette
    @State private var pickTheme = false
    private let config = BaseConfig.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            TopBar(title: "Customize colors")
            ScrollView {
                VStack(spacing: 0) {
                    Button { pickTheme = true } label: {
                        row("Theme") { Text(config.theme.title).foregroundStyle(palette.secondaryText) }
                    }
                    .buttonStyle(.plain)
                    colorRow("Text color", \.customTextColor)
                    colorRow("Background color", \.customBackgroundColor)
                    colorRow("Primary color", \.customPrimaryColor)
                }
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $pickTheme) {
            RadioDialog(title: nil, items: ThemeKind.allCases.map { ($0, $0.title) }, selected: config.theme) { kind in
                if kind == .custom && config.theme != .custom {
                    // Start the custom theme from what is currently on screen.
                    adoptCurrentColors()
                }
                config.theme = kind
            }
        }
    }

    private func adoptCurrentColors() {
        config.customTextColor = palette.text
        config.customBackgroundColor = palette.background
        config.customPrimaryColor = palette.primary
    }

    private func row<V: View>(_ title: String, @ViewBuilder value: () -> V) -> some View {
        HStack {
            Text(title).font(.system(size: 16))
            Spacer()
            value()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func colorRow(_ title: String, _ key: ReferenceWritableKeyPath<BaseConfig, UInt32>) -> some View {
        let current: UInt32 = {
            switch key {
            case \BaseConfig.customTextColor: return palette.text
            case \BaseConfig.customBackgroundColor: return palette.background
            default: return palette.primary
            }
        }()
        return row(title) {
            ColorPicker("", selection: Binding(
                get: { Color(argb: current) },
                set: { c in
                    if config.theme != .custom {
                        adoptCurrentColors()
                        config.theme = .custom
                    }
                    config[keyPath: key] = c.argb | 0xFF000000
                }), supportsOpacity: false)
                .labelsHidden()
        }
    }
}

/// What AboutActivity needs to know about the app.
public struct AppInfo {
    /// App name without "Fossify", e.g. "Calculator".
    public var name: String
    /// SF Symbol drawn on the primary-colored app badge.
    public var icon: String
    /// Upstream Android repo name under FossifyOrg, e.g. "Calculator".
    public var upstream: String
    /// iOS port repo name under jbisfun, e.g. "calculator-ios".
    public var port: String
    /// fossify.org/policy/<slug>.
    public var policy: String
    /// App-specific FAQ entries (title, text).
    public var faq: [(String, String)]

    public init(name: String, icon: String, upstream: String, port: String, policy: String, faq: [(String, String)] = []) {
        self.name = name
        self.icon = icon
        self.upstream = upstream
        self.port = port
        self.policy = policy
        self.faq = faq
    }
}

/// AboutActivity (trimmed to what applies on iOS).
public struct AboutView: View {
    @Environment(\.palette) private var palette
    let app: AppInfo

    public init(app: AppInfo) {
        self.app = app
    }

    public var body: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        VStack(spacing: 0) {
            TopBar(title: "About")
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Circle().fill(palette.primaryColor).frame(width: 80, height: 80)
                            .overlay(Image(systemName: app.icon).font(.system(size: 34)).foregroundStyle(palette.onPrimary))
                        Text("Fossify \(app.name)").font(.system(size: 22, weight: .medium))
                        Text("Version \(version)").foregroundStyle(palette.secondaryText)
                    }
                    .padding(.vertical, 24)
                    Text(app.faq.isEmpty ? "Support" : "Frequently asked questions").sectionHeader(palette)
                    ForEach(app.faq, id: \.0) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.0).font(.system(size: 16, weight: .medium))
                            Text(item.1).font(.system(size: 15)).foregroundStyle(palette.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    link(app.faq.isEmpty ? "Frequently asked questions" : "More questions", "https://www.fossify.org/faq")
                    Text("Help us").sectionHeader(palette)
                    link("Contribute", "https://github.com/FossifyOrg/\(app.upstream)/blob/master/CONTRIBUTING.md")
                    link("Donate", "https://fossify.org/donate")
                    Text("Social").sectionHeader(palette)
                    link("Reddit", "https://www.reddit.com/r/Fossify")
                    link("Telegram", "https://t.me/Fossify")
                    Text("Other").sectionHeader(palette)
                    link("Website", "https://www.fossify.org")
                    link("Source code (Android)", "https://github.com/FossifyOrg/\(app.upstream)")
                    link("Source code (iOS port)", "https://github.com/jbisfun/\(app.port)")
                    link("Privacy policy", "https://www.fossify.org/policy/\(app.policy)")
                    link("License (GPL-3.0)", "https://www.gnu.org/licenses/gpl-3.0.html")
                }
                .padding(.bottom, 32)
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
    }

    private func link(_ title: String, _ url: String) -> some View {
        Button { Launcher.open(URL(string: url)) } label: {
            Text(title)
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
