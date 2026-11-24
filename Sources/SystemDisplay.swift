import ObjectiveC
import SwiftUI
import UIKit

/// Display settings that Settings (settings-ios) owns for the whole process: "Screen timeout"
/// (keep the screen on) and "Auto-rotate screen". Every app inside the launcher shares them.
/// The host calls `SystemDisplay.install()` once at startup (Settings also does when shown).
public enum SystemDisplay {
    public static let keepScreenOnKey = "system_keep_screen_on"
    public static let autoRotateKey = "system_auto_rotate"

    /// Screen timeout = Never: the idle timer stays off whatever the apps ask for.
    public static var keepScreenOn: Bool { UserDefaults.standard.bool(forKey: keepScreenOnKey) }
    /// Off = portrait only (apps that force another orientation keep it).
    public static var autoRotate: Bool { UserDefaults.standard.object(forKey: autoRotateKey) as? Bool ?? true }

    /// What the apps last asked `isIdleTimerDisabled` to be.
    @MainActor fileprivate static var requestedIdleTimerDisabled = false

    @MainActor private static var installed = false

    /// Routes every app's `isIdleTimerDisabled` through the "keep screen on" setting.
    @MainActor
    public static func install() {
        guard !installed else { return }
        installed = true
        requestedIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        let cls: AnyClass = UIApplication.self
        if let original = class_getInstanceMethod(cls, #selector(setter: UIApplication.isIdleTimerDisabled)),
           let replacement = class_getInstanceMethod(cls, #selector(UIApplication.fossifySystemSetIdleTimerDisabled(_:))) {
            method_exchangeImplementations(original, replacement)
        }
        UIApplication.shared.isIdleTimerDisabled = requestedIdleTimerDisabled
        refreshOrientation()
    }

    @MainActor
    public static func setKeepScreenOn(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: keepScreenOnKey)
        install()
        UIApplication.shared.isIdleTimerDisabled = requestedIdleTimerDisabled
    }

    @MainActor
    public static func setAutoRotate(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: autoRotateKey)
        refreshOrientation()
    }

    /// The orientations allowed once the auto-rotate setting is applied to an app's mask.
    public static func effectiveMask(_ mask: UIInterfaceOrientationMask) -> UIInterfaceOrientationMask {
        guard !autoRotate, mask.contains(.portrait) else { return mask }
        return .portrait
    }

    @MainActor
    private static func refreshOrientation() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                var vc = window.rootViewController
                while let current = vc {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    vc = current.presentedViewController
                }
            }
            if !autoRotate { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
        }
    }
}

extension UIApplication {
    /// Swapped with the `isIdleTimerDisabled` setter by `SystemDisplay.install()`, so calling it
    /// here runs the original setter.
    @objc dynamic func fossifySystemSetIdleTimerDisabled(_ disabled: Bool) {
        MainActor.assumeIsolated { SystemDisplay.requestedIdleTimerDisabled = disabled }
        fossifySystemSetIdleTimerDisabled(disabled || SystemDisplay.keepScreenOn)
    }
}
