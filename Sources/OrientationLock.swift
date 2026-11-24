import SwiftUI
import UIKit

/// "Force portrait mode" (Activity.requestedOrientation). iOS asks the app delegate
/// for the allowed orientations, so the hosting app (standalone or launcher) installs
/// `@UIApplicationDelegateAdaptor(OrientationLockDelegate.self)`; apps call `OrientationLock.set`.
@MainActor
public enum OrientationLock {
    public private(set) static var mask: UIInterfaceOrientationMask = .all

    public static func set(portrait: Bool) {
        let newMask: UIInterfaceOrientationMask = portrait ? .portrait : .all
        guard newMask != mask else { return }
        mask = newMask
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                var vc = window.rootViewController
                while let current = vc {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    vc = current.presentedViewController
                }
            }
            if portrait { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
        }
    }

    /// Any orientation mask (e.g. Gallery's force portrait / landscape / reverse landscape); `.all` releases it.
    public static func set(mask newMask: UIInterfaceOrientationMask) {
        guard newMask != mask else { return }
        mask = newMask
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                var vc = window.rootViewController
                while let current = vc {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    vc = current.presentedViewController
                }
            }
            if newMask != .all { scene.requestGeometryUpdate(.iOS(interfaceOrientations: newMask)) }
        }
    }
}

public final class OrientationLockDelegate: NSObject, UIApplicationDelegate {
    public func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}
