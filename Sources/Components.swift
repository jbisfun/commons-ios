import SwiftUI
import UIKit

/// RadioGroupDialog.
public struct RadioDialog<T: Hashable>: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let title: String?
    let items: [(T, String)]
    let selected: T
    let onPick: (T) -> Void

    public init(title: String?, items: [(T, String)], selected: T, onPick: @escaping (T) -> Void) {
        self.title = title
        self.items = items
        self.selected = selected
        self.onPick = onPick
    }

    public var body: some View {
        DialogFrame(title: title) {
            ForEach(items, id: \.0) { item in
                Button {
                    onPick(item.0)
                    dismiss()
                } label: {
                    RadioRow(title: item.1, on: item.0 == selected)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

public struct RadioRow: View {
    @Environment(\.palette) private var palette
    let title: String
    let on: Bool

    public init(title: String, on: Bool) {
        self.title = title
        self.on = on
    }

    public var body: some View {
        HStack(spacing: 16) {
            Image(systemName: on ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(on ? palette.primaryColor : palette.secondaryText)
            Text(title).foregroundStyle(palette.textColor)
            Spacer()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

public struct CheckRow: View {
    @Environment(\.palette) private var palette
    let title: String
    @Binding var on: Bool

    public init(title: String, on: Binding<Bool>) {
        self.title = title
        _on = on
    }

    public var body: some View {
        Button { on.toggle() } label: {
            HStack(spacing: 16) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(on ? palette.primaryColor : palette.secondaryText)
                Text(title).foregroundStyle(palette.textColor).multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Material-style dialog body presented as a sheet.
public struct DialogFrame<Content: View>: View {
    @Environment(\.palette) private var palette
    let title: String?
    var scroll: Bool
    let content: () -> Content

    public init(title: String?, scroll: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.scroll = scroll
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(palette.textColor)
                    .padding(.bottom, 8)
            }
            if scroll {
                ScrollView { VStack(alignment: .leading, spacing: 0, content: content) }
            } else {
                VStack(alignment: .leading, spacing: 0, content: content)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

public struct DialogButtons: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    var ok: String
    var okEnabled: Bool
    let onOK: () -> Void

    public init(ok: String = "OK", okEnabled: Bool = true, onOK: @escaping () -> Void) {
        self.ok = ok
        self.okEnabled = okEnabled
        self.onOK = onOK
    }

    public var body: some View {
        HStack(spacing: 24) {
            Spacer()
            Button("Cancel") { dismiss() }
            Button(ok) { onOK() }.disabled(!okEnabled)
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(palette.primaryColor)
        .padding(.top, 16)
    }
}

/// Toast replacement (Android Toast -> transient capsule).
struct ToastModifier: ViewModifier {
    @Binding var text: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let text {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.8)))
                    .padding(.bottom, 100)
                    .transition(.opacity)
                    .task(id: text) {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { self.text = nil }
                    }
            }
        }
        .animation(.default, value: text)
    }
}

extension View {
    public func toast(_ text: Binding<String?>) -> some View { modifier(ToastModifier(text: text)) }

    /// Fossify settings section header ("Color customization", "General", ...).
    public func sectionHeader(_ palette: Palette) -> some View {
        self.font(.system(size: 14, weight: .bold))
            .foregroundStyle(palette.primaryColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }
}

/// Top app bar with a back arrow (MaterialToolbar + NavigationIcon.Arrow).
public struct TopBar<Trailing: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let title: String
    var onBack: (() -> Void)?
    var background: Color?
    var tint: Color?
    var trailing: () -> Trailing

    public init(title: String, onBack: (() -> Void)? = nil, background: Color? = nil, tint: Color? = nil,
                @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.onBack = onBack
        self.background = background
        self.tint = tint
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 4) {
            Button {
                if let onBack { onBack() } else { dismiss() }
            } label: {
                Image(systemName: "arrow.left").font(.system(size: 20)).frame(width: 48, height: 48)
            }
            Text(title)
                .font(.system(size: 21, weight: .medium))
                .lineLimit(1)
            Spacer()
            trailing()
        }
        .foregroundStyle(tint ?? palette.textColor)
        .padding(.horizontal, 4)
        .frame(height: 56)
        .background(background ?? palette.backgroundColor)
    }
}

extension TopBar where Trailing == EmptyView {
    public init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack, background: nil, tint: nil, trailing: { EmptyView() })
    }
}

public struct IconButton: View {
    let icon: String
    let action: () -> Void

    public init(icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 19)).frame(width: 44, height: 48)
        }
    }
}

/// Ripple stand-in: dim while pressed.
public struct PressedStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Fossify's launch*Intent helpers; apps add their own (call, sms, ...) in extensions.
public enum Launcher {
    public static func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }

    /// copyToClipboard(): returns the toast text.
    public static func copy(_ value: String) -> String {
        UIPasteboard.general.string = value
        return "Value copied to clipboard"
    }
}

/// Re-enable the interactive swipe-back gesture with hidden navigation bars.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
