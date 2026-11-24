import SwiftUI
import UIKit

/// ColorPickerDialog, backed by the system color picker (UIColorPickerViewController).
/// Present it in a `.sheet`; `onPick` gets the chosen opaque ARGB color once the
/// picker is closed, and is not called if no color was chosen.
public struct ColorPickerDialog: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let title: String?
    let color: UInt32
    let onPick: (UInt32) -> Void

    public init(title: String? = nil, color: UInt32, onPick: @escaping (UInt32) -> Void) {
        self.title = title
        self.color = color
        self.onPick = onPick
    }

    public func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    public func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let vc = UIColorPickerViewController()
        vc.selectedColor = UIColor(Color(argb: color | 0xFF000000))
        vc.supportsAlpha = false
        if let title { vc.title = title }
        vc.delegate = context.coordinator
        return vc
    }

    public func updateUIViewController(_ vc: UIColorPickerViewController, context: Context) {
        context.coordinator.dismiss = dismiss
    }

    public static func dismantleUIViewController(_ vc: UIColorPickerViewController, coordinator: Coordinator) {
        coordinator.commit()
    }

    @MainActor
    public final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        let onPick: (UInt32) -> Void
        var picked: UInt32?
        var dismiss: DismissAction?

        init(onPick: @escaping (UInt32) -> Void) { self.onPick = onPick }

        public func colorPickerViewController(_ vc: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
            picked = Color(uiColor: color).argb | 0xFF000000
        }

        public func colorPickerViewControllerDidFinish(_ vc: UIColorPickerViewController) {
            commit()
            dismiss?()
        }

        func commit() {
            guard let picked else { return }
            self.picked = nil
            onPick(picked)
        }
    }
}
