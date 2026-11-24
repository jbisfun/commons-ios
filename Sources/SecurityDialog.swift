import CryptoKit
import LocalAuthentication
import Observation
import SwiftUI
import UIKit

/// PROTECTION_* / SHOW_ALL_TABS from Fossify Commons.
public enum Protection {
    public static let none = -1
    public static let pattern = 0
    public static let pin = 1
    /// PROTECTION_FINGERPRINT: Face ID / Touch ID (apps need NSFaceIDUsageDescription).
    public static let biometric = 2
    public static let showAllTabs = -1

    /// isBiometricAuthSupported().
    public static var biometricAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// showBiometricPrompt().
    public static func authenticateWithBiometrics(_ completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate") { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    /// Lowercase hex SHA-1, as PinTab.getHashedPin() and PatternLockUtils.patternToSha1() produce.
    public static func sha1(_ text: String) -> String {
        Insecure.SHA1.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// The password-protection part of BaseConfig (same UserDefaults keys in every app).
@Observable
public final class SecurityConfig {
    public static let shared = SecurityConfig()

    @ObservationIgnored private let d = UserDefaults.standard

    public var isAppPasswordProtectionOn: Bool { didSet { d.set(isAppPasswordProtectionOn, forKey: "app_password_protection") } }
    public var appPasswordHash: String { didSet { d.set(appPasswordHash, forKey: "app_password_hash") } }
    public var appProtectionType: Int { didSet { d.set(appProtectionType, forKey: "app_protection_type") } }
    public var isDeletePasswordProtectionOn: Bool { didSet { d.set(isDeletePasswordProtectionOn, forKey: "delete_password_protection") } }
    public var deletePasswordHash: String { didSet { d.set(deletePasswordHash, forKey: "delete_password_hash") } }
    public var deleteProtectionType: Int { didSet { d.set(deleteProtectionType, forKey: "delete_protection_type") } }
    public var passwordRetryCount: Int { didSet { d.set(passwordRetryCount, forKey: "password_retry_count") } }
    public var passwordCountdownStartMs: Double { didSet { d.set(passwordCountdownStartMs, forKey: "password_count_down_start_ms") } }
    public var lastUnlockTimestampMs: Double { didSet { d.set(lastUnlockTimestampMs, forKey: "last_unlock_timestamp_ms") } }
    public var unlockTimeoutDurationMs: Double { didSet { d.set(unlockTimeoutDurationMs, forKey: "unlock_timeout_duration_ms") } }

    private init() {
        isAppPasswordProtectionOn = d.bool(forKey: "app_password_protection")
        appPasswordHash = d.string(forKey: "app_password_hash") ?? ""
        appProtectionType = d.object(forKey: "app_protection_type") as? Int ?? Protection.pattern
        isDeletePasswordProtectionOn = d.bool(forKey: "delete_password_protection")
        deletePasswordHash = d.string(forKey: "delete_password_hash") ?? ""
        deleteProtectionType = d.object(forKey: "delete_protection_type") as? Int ?? Protection.pattern
        passwordRetryCount = d.integer(forKey: "password_retry_count")
        passwordCountdownStartMs = d.double(forKey: "password_count_down_start_ms")
        lastUnlockTimestampMs = d.double(forKey: "last_unlock_timestamp_ms")
        unlockTimeoutDurationMs = d.object(forKey: "unlock_timeout_duration_ms") as? Double ?? 30_000
    }

    static let maxRetryCount = 3
    static let countdownSeconds = 5

    /// BaseSecurityTab.getCountdown(): seconds left of the lockout after too many wrong attempts.
    func countdown() -> Int {
        guard passwordRetryCount >= Self.maxRetryCount else { return 0 }
        let now = Date().timeIntervalSince1970 * 1000
        if passwordCountdownStartMs == 0 {
            passwordCountdownStartMs = now
            return Self.countdownSeconds
        }
        let remaining = Double(Self.countdownSeconds) * 1000 - (now - passwordCountdownStartMs)
        return remaining > 0 ? Int((remaining / 1000).rounded(.up)) : 0
    }

    func resetCountdown() {
        passwordRetryCount = 0
        passwordCountdownStartMs = 0
    }
}

/// SecurityDialog: pattern / PIN / biometrics tabs. With an empty `requiredHash` it sets up a
/// new password (enter + repeat); otherwise it checks the given one. `callback(hash, type, success)`.
public struct SecurityDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let requiredHash: String
    let showTabIndex: Int
    let callback: (String, Int, Bool) -> Void
    @State private var tab: Int
    @State private var finished = false

    public init(requiredHash: String, showTabIndex: Int, callback: @escaping (String, Int, Bool) -> Void) {
        self.requiredHash = requiredHash
        self.showTabIndex = showTabIndex
        self.callback = callback
        _tab = State(initialValue: showTabIndex == Protection.showAllTabs ? Protection.pattern : showTabIndex)
    }

    public var body: some View {
        DialogFrame(title: nil, scroll: false) {
            if showTabIndex == Protection.showAllTabs {
                Picker("", selection: $tab) {
                    Text("Pattern").tag(Protection.pattern)
                    Text("PIN").tag(Protection.pin)
                    if Protection.biometricAvailable { Text("Biometrics").tag(Protection.biometric) }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 16)
            }
            Group {
                switch tab {
                case Protection.pin: PinTab(requiredHash: requiredHash, onHash: received)
                case Protection.biometric: BiometricTab(autoPrompt: showTabIndex == Protection.biometric, onHash: received)
                default: PatternTab(requiredHash: requiredHash, onHash: received)
                }
            }
            .frame(maxWidth: .infinity)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.primaryColor)
            }
            .padding(.top, 8)
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(false)
        .onDisappear { if !finished { callback("", 0, false) } }
    }

    private func received(_ hash: String, _ type: Int) {
        finished = true
        callback(hash, type, true)
        dismiss()
    }
}

/// Title line shared by the pattern and PIN tabs: prompt, "wrong" flash, lockout countdown.
@MainActor
@Observable
final class SecurityTabTitle {
    var text: String
    var wrong = false
    let defaultText: String
    let wrongText: String
    let requiredHash: String
    private var task: Task<Void, Never>?

    init(defaultText: String, wrongText: String, requiredHash: String) {
        self.text = defaultText
        self.defaultText = defaultText
        self.wrongText = wrongText
        self.requiredHash = requiredHash
        if SecurityConfig.shared.passwordRetryCount >= SecurityConfig.maxRetryCount { startCountdown() }
    }

    var isLockedOut: Bool { !requiredHash.isEmpty && SecurityConfig.shared.countdown() > 0 }

    func correct() { SecurityConfig.shared.resetCountdown() }

    func incorrect() {
        let config = SecurityConfig.shared
        config.passwordRetryCount += 1
        if !requiredHash.isEmpty && config.passwordRetryCount >= SecurityConfig.maxRetryCount {
            startCountdown()
        } else {
            show(wrongText, wrong: true)
            task?.cancel()
            task = Task {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled { show(defaultText, wrong: false) }
            }
        }
    }

    func show(_ t: String, wrong: Bool) {
        text = t
        self.wrong = wrong
    }

    private func startCountdown() {
        task?.cancel()
        task = Task {
            while !Task.isCancelled {
                let left = SecurityConfig.shared.countdown()
                if left <= 0 {
                    SecurityConfig.shared.resetCountdown()
                    show(defaultText, wrong: false)
                    return
                }
                show("Too many incorrect unlock attempts.\nTry again in \(left) seconds.", wrong: true)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct TabTitle: View {
    @Environment(\.palette) private var palette
    let title: SecurityTabTitle

    var body: some View {
        Label(title.text, systemImage: "lock")
            .font(.system(size: 17))
            .multilineTextAlignment(.center)
            .foregroundStyle(title.wrong ? Color.red : palette.textColor)
            .frame(minHeight: 48)
    }
}

/// PatternTab: 3x3 pattern lock; hash = SHA-1 of the dot indices (row * 3 + column).
struct PatternTab: View {
    @Environment(\.palette) private var palette
    let requiredHash: String
    let onHash: (String, Int) -> Void
    @State private var title: SecurityTabTitle
    @State private var computedHash: String
    @State private var dots: [Int] = []
    @State private var finger: CGPoint?
    @State private var mode = 0 // 0 normal, 1 correct, 2 wrong
    @State private var inputEnabled = true

    init(requiredHash: String, onHash: @escaping (String, Int) -> Void) {
        self.requiredHash = requiredHash
        self.onHash = onHash
        _computedHash = State(initialValue: requiredHash)
        _title = State(initialValue: SecurityTabTitle(defaultText: "Insert pattern", wrongText: "Wrong pattern", requiredHash: requiredHash))
    }

    var body: some View {
        VStack(spacing: 16) {
            TabTitle(title: title)
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let color = mode == 2 ? Color.red : (mode == 1 || !dots.isEmpty ? palette.primaryColor : palette.textColor)
                ZStack {
                    Path { p in
                        for (i, d) in dots.enumerated() {
                            let c = center(d, side)
                            if i == 0 { p.move(to: c) } else { p.addLine(to: c) }
                        }
                        if let finger, !dots.isEmpty { p.addLine(to: finger) }
                    }
                    .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    ForEach(0..<9, id: \.self) { i in
                        Circle()
                            .fill(dots.contains(i) ? color : palette.textColor)
                            .frame(width: dots.contains(i) ? 18 : 12, height: dots.contains(i) ? 18 : 12)
                            .position(center(i, side))
                    }
                }
                .frame(width: side, height: side)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard inputEnabled else { return }
                        if title.isLockedOut { return }
                        finger = v.location
                        for i in 0..<9 where !dots.contains(i) {
                            let c = center(i, side)
                            if hypot(c.x - v.location.x, c.y - v.location.y) < side / 8 {
                                dots.append(i)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    }
                    .onEnded { _ in
                        finger = nil
                        guard inputEnabled, !dots.isEmpty else { return }
                        completed()
                    })
                .frame(maxWidth: .infinity)
            }
            .frame(height: 260)
        }
    }

    private func center(_ i: Int, _ side: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(i % 3) + 0.5) * side / 3, y: (CGFloat(i / 3) + 0.5) * side / 3)
    }

    private func completed() {
        let newHash = Protection.sha1(dots.map(String.init).joined())
        if computedHash.isEmpty {
            computedHash = newHash
            dots = []
            title.show("Repeat pattern", wrong: false)
        } else if computedHash == newHash {
            mode = 1
            title.correct()
            inputEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onHash(computedHash, Protection.pattern) }
        } else {
            title.incorrect()
            mode = 2
            inputEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dots = []
                mode = 0
                inputEnabled = true
                if requiredHash.isEmpty {
                    computedHash = ""
                    title.show("Insert pattern", wrong: false)
                }
            }
        }
    }
}

/// PinTab.
struct PinTab: View {
    @Environment(\.palette) private var palette
    let requiredHash: String
    let onHash: (String, Int) -> Void
    @State private var title: SecurityTabTitle
    @State private var computedHash: String
    @State private var pin = ""
    @State private var toast: String?

    init(requiredHash: String, onHash: @escaping (String, Int) -> Void) {
        self.requiredHash = requiredHash
        self.onHash = onHash
        _computedHash = State(initialValue: requiredHash)
        _title = State(initialValue: SecurityTabTitle(defaultText: "Enter PIN", wrongText: "Wrong PIN", requiredHash: requiredHash))
    }

    var body: some View {
        VStack(spacing: 8) {
            TabTitle(title: title)
            Text(String(repeating: "*", count: pin.count))
                .font(.system(size: 28))
                .frame(height: 40)
            let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["C", "0", "OK"]]
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(row, id: \.self) { key in
                        Button { press(key) } label: {
                            Group {
                                if key == "OK" { Image(systemName: "checkmark") } else { Text(key) }
                            }
                            .font(.system(size: 26))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressedStyle())
                        .foregroundStyle(palette.textColor)
                    }
                }
            }
        }
        .toast($toast)
    }

    private func press(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch key {
        case "C": if !pin.isEmpty { pin.removeLast() }
        case "OK": confirm()
        default: if !title.isLockedOut && pin.count < 10 { pin += key }
        }
    }

    private func confirm() {
        guard !title.isLockedOut else { return }
        let newHash = Protection.sha1(pin)
        if pin.isEmpty {
            toast = "Please enter a PIN"
        } else if computedHash.isEmpty && pin.count < 4 {
            pin = ""
            toast = "PIN must be at least 4 digits long"
        } else if computedHash.isEmpty {
            computedHash = newHash
            pin = ""
            title.show("Repeat PIN", wrong: false)
        } else if computedHash == newHash {
            title.correct()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onHash(computedHash, Protection.pin) }
        } else {
            pin = ""
            title.incorrect()
            if requiredHash.isEmpty { computedHash = "" }
        }
    }
}

/// BiometricIdTab: Face ID / Touch ID.
struct BiometricTab: View {
    @Environment(\.palette) private var palette
    let autoPrompt: Bool
    let onHash: (String, Int) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: LAContext().biometryType == .touchID ? "touchid" : "faceid")
                .font(.system(size: 64))
                .foregroundStyle(palette.primaryColor)
                .padding(.top, 24)
            Button("Authenticate", action: prompt)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.onPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(palette.primaryColor))
        }
        .padding(.bottom, 24)
        .onAppear { if autoPrompt { prompt() } }
    }

    private func prompt() {
        Protection.authenticateWithBiometrics { ok in
            if ok {
                SecurityConfig.shared.resetCountdown()
                onHash("", Protection.biometric)
            }
        }
    }
}

/// A pending performSecurityCheck() call.
public struct SecurityCheck: Identifiable {
    public let id = UUID()
    let protectionType: Int
    let requiredHash: String
    let onSuccess: (String, Int) -> Void
    let onFailure: () -> Void

    public init(protectionType: Int, requiredHash: String, onSuccess: @escaping (String, Int) -> Void, onFailure: @escaping () -> Void = {}) {
        self.protectionType = protectionType
        self.requiredHash = requiredHash
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }

    /// handleDeletePasswordProtection(): nil when deletion isn't protected.
    public static func deleteProtection(_ onSuccess: @escaping () -> Void) -> SecurityCheck? {
        let c = SecurityConfig.shared
        guard c.isDeletePasswordProtectionOn else { return nil }
        return SecurityCheck(protectionType: c.deleteProtectionType, requiredHash: c.deletePasswordHash) { _, _ in onSuccess() }
    }
}

struct SecurityCheckModifier: ViewModifier {
    @Environment(\.palette) private var palette
    @Binding var request: SecurityCheck?
    @State private var dialog: SecurityCheck?

    func body(content: Content) -> some View {
        content
            .onChange(of: request?.id) { _, _ in
                guard let r = request else { return }
                request = nil
                if r.protectionType == Protection.biometric {
                    Protection.authenticateWithBiometrics { ok in ok ? r.onSuccess("", Protection.biometric) : r.onFailure() }
                } else {
                    dialog = r
                }
            }
            .sheet(item: $dialog) { r in
                SecurityDialog(requiredHash: r.requiredHash, showTabIndex: r.protectionType) { hash, type, ok in
                    ok ? r.onSuccess(hash, type) : r.onFailure()
                }
                .environment(\.palette, palette)
            }
    }
}

extension View {
    /// performSecurityCheck(): set the binding to ask for the password (biometrics prompt directly).
    public func securityCheck(_ request: Binding<SecurityCheck?>) -> some View {
        modifier(SecurityCheckModifier(request: request))
    }

    /// AppLockManager + handleAppPasswordProtection(): covers the app until the app password is entered.
    public func appLock() -> some View { modifier(AppLockModifier()) }
}

/// AppLockManager: the app locks again after `unlockTimeoutDurationMs` in the background.
@MainActor
@Observable
public final class AppLock {
    public static let shared = AppLock()

    public private(set) var isLocked = SecurityConfig.shared.isAppPasswordProtectionOn
    @ObservationIgnored private var shouldUpdateLockState = true

    public func lock() {
        isLocked = SecurityConfig.shared.isAppPasswordProtectionOn
        SecurityConfig.shared.lastUnlockTimestampMs = 0
    }

    public func unlock() {
        isLocked = false
        SecurityConfig.shared.lastUnlockTimestampMs = Date().timeIntervalSince1970 * 1000
    }

    func onStop() {
        shouldUpdateLockState = true
        if !isLocked { SecurityConfig.shared.lastUnlockTimestampMs = Date().timeIntervalSince1970 * 1000 }
    }

    func updateLockState() {
        let config = SecurityConfig.shared
        guard config.isAppPasswordProtectionOn else {
            isLocked = false
            return
        }
        let now = Date().timeIntervalSince1970 * 1000
        if now - config.lastUnlockTimestampMs > config.unlockTimeoutDurationMs && shouldUpdateLockState {
            isLocked = true
            shouldUpdateLockState = false
        } else if !isLocked {
            config.lastUnlockTimestampMs = now
        }
    }
}

struct AppLockModifier: ViewModifier {
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var phase
    @State private var lock = AppLock.shared
    @State private var check: SecurityCheck?

    func body(content: Content) -> some View {
        content
            .overlay {
                if lock.isLocked {
                    VStack(spacing: 24) {
                        Image(systemName: "lock").font(.system(size: 48)).foregroundStyle(palette.textColor)
                        Button("Authenticate", action: ask)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(palette.primaryColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.backgroundColor.ignoresSafeArea())
                }
            }
            .securityCheck($check)
            .onAppear {
                lock.updateLockState()
                if lock.isLocked { ask() }
            }
            .onChange(of: phase) { _, p in
                if p == .background { lock.onStop() }
                if p == .active {
                    lock.updateLockState()
                    if lock.isLocked && check == nil { ask() }
                }
            }
    }

    private func ask() {
        let c = SecurityConfig.shared
        check = SecurityCheck(protectionType: c.appProtectionType, requiredHash: c.appPasswordHash) { _, _ in lock.unlock() }
    }
}

/// The "Password protect the whole application" / "Password protect ... deletion" settings rows
/// (setupAppPasswordProtection / setupDeletePasswordProtection).
public struct PasswordProtectionToggle: View {
    public enum Kind { case app, delete }

    @Environment(\.palette) private var palette
    let title: String
    let kind: Kind
    @State private var config = SecurityConfig.shared
    @State private var showDialog = false
    @State private var confirmation: String?

    public init(_ title: String, kind: Kind) {
        self.title = title
        self.kind = kind
    }

    private var isOn: Bool { kind == .app ? config.isAppPasswordProtectionOn : config.isDeletePasswordProtectionOn }

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
            let hash = kind == .app ? config.appPasswordHash : config.deletePasswordHash
            let type = kind == .app ? config.appProtectionType : config.deleteProtectionType
            SecurityDialog(requiredHash: isOn ? hash : "", showTabIndex: isOn ? type : Protection.showAllTabs) { newHash, newType, ok in
                guard ok else { return }
                let wasOn = isOn
                switch kind {
                case .app:
                    config.isAppPasswordProtectionOn = !wasOn
                    config.appPasswordHash = wasOn ? "" : newHash
                    config.appProtectionType = newType
                    if !wasOn { AppLock.shared.unlock() }
                case .delete:
                    config.isDeletePasswordProtectionOn = !wasOn
                    config.deletePasswordHash = wasOn ? "" : newHash
                    config.deleteProtectionType = newType
                }
                if !wasOn {
                    confirmation = newType == Protection.biometric
                        ? "Protection setup successfully. Please reinstall the app in case of problems with resetting it."
                        : "Password setup successfully. Please reinstall the app in case you forget it."
                }
            }
            .environment(\.palette, palette)
        }
        .alert(confirmation ?? "", isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } })) {
            Button("OK") {}
        }
    }
}
