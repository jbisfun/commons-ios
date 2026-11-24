import SwiftUI

/// UserDefaults keys of a password protection that lives outside SecurityConfig: BaseConfig's
/// hidden items protection, per-folder locks (addFolderProtection) or app-specific ones
/// (e.g. Gallery's excluded folders).
public struct ProtectionKeys: Sendable {
    /// Bool "is on" key; nil when the protection is on whenever its type isn't PROTECTION_NONE.
    public let on: String?
    public let hash: String
    public let type: String

    public init(on: String?, hash: String, type: String) {
        self.on = on
        self.hash = hash
        self.type = type
    }

    /// isHiddenPasswordProtectionOn / hiddenPasswordHash / hiddenProtectionType.
    public static let hiddenItems = ProtectionKeys(on: "password_protection", hash: "password_hash", type: "protection_type")

    /// PROTECTED_FOLDER_HASH / PROTECTED_FOLDER_TYPE of one folder.
    public static func folder(_ path: String) -> ProtectionKeys {
        ProtectionKeys(on: nil, hash: "protected_folder_hash_" + path, type: "protected_folder_type_" + path)
    }
}

/// Reads, sets and checks a protection stored under ProtectionKeys.
public enum StoredProtection {
    private static var d: UserDefaults { .standard }

    public static func isOn(_ k: ProtectionKeys) -> Bool {
        if let on = k.on { return d.bool(forKey: on) }
        return (d.object(forKey: k.type) as? Int ?? Protection.none) != Protection.none
    }

    public static func set(_ k: ProtectionKeys, hash: String, type: Int) {
        if let on = k.on { d.set(true, forKey: on) }
        d.set(hash, forKey: k.hash)
        d.set(type, forKey: k.type)
    }

    public static func clear(_ k: ProtectionKeys) {
        if let on = k.on {
            d.set(false, forKey: on)
            d.set("", forKey: k.hash)
        } else {
            d.removeObject(forKey: k.hash)
            d.removeObject(forKey: k.type)
        }
    }

    /// handleHiddenFolderPasswordProtection() & co: a SecurityCheck for `.securityCheck(...)`,
    /// or nil (run `onSuccess` yourself) when the protection is off.
    public static func check(_ k: ProtectionKeys, onSuccess: @escaping () -> Void) -> SecurityCheck? {
        guard isOn(k) else { return nil }
        let type = d.object(forKey: k.type) as? Int ?? Protection.pattern
        return SecurityCheck(protectionType: type, requiredHash: d.string(forKey: k.hash) ?? "") { _, _ in onSuccess() }
    }
}

/// Settings switch for a stored protection: SecurityDialog sets up a new password when turning
/// it on and asks for the current one when turning it off.
public struct StoredProtectionToggle: View {
    @Environment(\.palette) private var palette
    let title: String
    let keys: ProtectionKeys
    @State private var isOn: Bool
    @State private var showDialog = false
    @State private var confirmation: String?

    public init(_ title: String, keys: ProtectionKeys) {
        self.title = title
        self.keys = keys
        _isOn = State(initialValue: StoredProtection.isOn(keys))
    }

    public var body: some View {
        Button { showDialog = true } label: {
            HStack {
                Text(title).font(.system(size: 16)).foregroundStyle(palette.textColor).multilineTextAlignment(.leading)
                Spacer()
                Toggle("", isOn: .constant(isOn)).labelsHidden().tint(palette.primaryColor).allowsHitTesting(false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDialog) {
            let d = UserDefaults.standard
            SecurityDialog(requiredHash: isOn ? d.string(forKey: keys.hash) ?? "" : "",
                           showTabIndex: isOn ? d.object(forKey: keys.type) as? Int ?? Protection.pattern : Protection.showAllTabs) { hash, type, ok in
                guard ok else { return }
                if isOn {
                    StoredProtection.clear(keys)
                } else {
                    StoredProtection.set(keys, hash: hash, type: type)
                    confirmation = type == Protection.biometric
                        ? "Protection setup successfully. Please reinstall the app in case of problems with resetting it."
                        : "Password setup successfully. Please reinstall the app in case you forget it."
                }
                isOn = StoredProtection.isOn(keys)
            }
            .environment(\.palette, palette)
        }
        .alert(confirmation ?? "", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })) {
            Button("OK") {}
        }
    }
}
