import SwiftUI

/// The "All Fossify apps" settings that Fossify Thank You writes to the shared
/// global config (MyContentProvider). Inside the launcher every app reads the
/// same UserDefaults, so these keys apply to all of them.
public enum GlobalSettings {
    /// SettingsSwitchComponent / MyMaterialSwitch draw a check in the thumb.
    public static let showCheckmarksOnSwitchesKey = "show_checkmarks_on_switches"
    /// Long.formatSize() uses KiB/MiB (1024) instead of kB/MB (1000).
    public static let useBinaryStorageUnitsKey = "use_binary_storage_units"
}

/// The iOS switch, or a switch with a check in the thumb while
/// "Show checkmarks on switches" is enabled.
public struct CheckmarkSwitchStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        CheckmarkSwitch(configuration: configuration)
    }
}

private struct CheckmarkSwitch: View {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @AppStorage(GlobalSettings.showCheckmarksOnSwitchesKey) private var showCheckmarks = false
    let configuration: ToggleStyleConfiguration

    var body: some View {
        if showCheckmarks {
            HStack {
                configuration.label
                Spacer(minLength: 8)
                let on = configuration.isOn
                Capsule()
                    .fill(on ? palette.primaryColor : palette.textColor.opacity(0.18))
                    .frame(width: 51, height: 31)
                    .overlay(alignment: on ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
                            .padding(2)
                            .overlay {
                                if on {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(palette.primaryColor)
                                }
                            }
                    }
                    .opacity(isEnabled ? 1 : 0.5)
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.2)) { configuration.isOn.toggle() }
                    }
                    .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
            }
        } else {
            Toggle(configuration).toggleStyle(.switch)
        }
    }
}
