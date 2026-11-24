import SwiftUI
import UIKit

/// OpenDeviceSettingsDialog: explains a denied permission and offers the app's page in Settings.
public struct OpenDeviceSettingsDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        DialogFrame(title: nil, scroll: false) {
            Text(message).font(.system(size: 16)).foregroundStyle(palette.textColor)
            HStack(spacing: 24) {
                Spacer()
                Button("Close") { dismiss() }
                Button("Go to Settings") {
                    dismiss()
                    Launcher.openDeviceSettings()
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(palette.primaryColor)
            .padding(.top, 24)
        }
        .presentationDetents([.height(200)])
    }
}

extension Launcher {
    /// openDeviceSettings(): the app's page in the Settings app.
    public static func openDeviceSettings() {
        open(URL(string: UIApplication.openSettingsURLString))
    }
}
