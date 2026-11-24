import SwiftUI
import UIKit

/// Activity.shareUris()/sharePathsIntent(): the system share sheet for files or text.
public struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    public init(items: [Any]) {
        self.items = items
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    public func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// Identifiable list of files to share, for `.sheet(item:)`.
public struct ShareItems: Identifiable {
    public let id = UUID()
    public let urls: [URL]

    public init(_ urls: [URL]) {
        self.urls = urls
    }
}

extension Launcher {
    /// The "Open with" chooser (Intent.createChooser(ACTION_VIEW)): apps that can open the file.
    /// Returns false when no app can (Fossify's "No valid app found" toast).
    @MainActor
    @discardableResult
    public static func openWith(_ url: URL) -> Bool {
        guard let root = topViewController() else { return false }
        let controller = UIDocumentInteractionController(url: url)
        openWithController = controller
        return controller.presentOpenInMenu(from: CGRect(x: root.view.bounds.midX, y: root.view.bounds.maxY - 1, width: 1, height: 1),
                                            in: root.view, animated: true)
    }

    /// Topmost presented view controller of the key window.
    @MainActor
    public static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// UIDocumentInteractionController must stay alive while its menu is shown.
@MainActor private var openWithController: UIDocumentInteractionController?
