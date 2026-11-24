import SwiftUI

/// showPickSecondsDialog(): preset durations, the current value and "Custom"
/// (CustomIntervalPickerDialog). Present it in a `.sheet`.
public struct PickSecondsDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let curSeconds: Int
    let isSnoozePicker: Bool
    let showSecondsAtCustomDialog: Bool
    let onCancel: (() -> Void)?
    let onPick: (Int) -> Void
    @State private var selected: Int
    @State private var custom = false
    @State private var picked = false

    public init(curSeconds: Int, isSnoozePicker: Bool = false, showSecondsAtCustomDialog: Bool = false,
                onCancel: (() -> Void)? = nil, onPick: @escaping (Int) -> Void) {
        self.curSeconds = curSeconds
        self.isSnoozePicker = isSnoozePicker
        self.showSecondsAtCustomDialog = showSecondsAtCustomDialog
        self.onCancel = onCancel
        self.onPick = onPick
        _selected = State(initialValue: curSeconds)
    }

    private var values: [Int] {
        var set: Set<Int> = [60, 300, 600, 1800, 3600, curSeconds]
        if !isSnoozePicker { set.formUnion([-1, 0]) }
        return set.sorted()
    }

    public var body: some View {
        Group {
            if custom {
                CustomIntervalPickerDialog(selectedSeconds: max(curSeconds, 0), showSeconds: showSecondsAtCustomDialog,
                                           onCancel: { custom = false }) { pick($0) }
            } else {
                DialogFrame(title: nil) {
                    ForEach(values, id: \.self) { value in
                        Button { pick(value) } label: {
                            RadioRow(title: DurationStrings.formatted(seconds: value, showBefore: !isSnoozePicker), on: value == selected)
                        }
                        .buttonStyle(.plain)
                    }
                    Button { custom = true } label: { RadioRow(title: "Custom", on: false) }
                        .buttonStyle(.plain)
                    if isSnoozePicker {
                        DialogButtons { pick(selected) }
                    }
                }
            }
        }
        .onDisappear { if !picked { onCancel?() } }
    }

    private func pick(_ value: Int) {
        picked = true
        onPick(value)
        dismiss()
    }
}

/// CustomIntervalPickerDialog: a number plus seconds / minutes / hours / days.
public struct CustomIntervalPickerDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let showSeconds: Bool
    let onCancel: (() -> Void)?
    let onPick: (Int) -> Void
    @State private var value: String
    @State private var multiplier: Int
    @FocusState private var focused: Bool

    public init(selectedSeconds: Int = 0, showSeconds: Bool = false, onCancel: (() -> Void)? = nil, onPick: @escaping (Int) -> Void) {
        self.showSeconds = showSeconds
        self.onCancel = onCancel
        self.onPick = onPick
        let s = selectedSeconds
        let (v, m): (Int, Int) = {
            if s == 0 { return (0, 60) }
            if s % 86400 == 0 { return (s / 86400, 86400) }
            if s % 3600 == 0 { return (s / 3600, 3600) }
            if s % 60 == 0 { return (s / 60, 60) }
            return (s, 1)
        }()
        _value = State(initialValue: v == 0 ? "" : "\(v)")
        _multiplier = State(initialValue: m == 1 && !showSeconds ? 60 : m)
    }

    public var body: some View {
        DialogFrame(title: nil, scroll: false) {
            TextField("", text: $value)
                .keyboardType(.numberPad)
                .focused($focused)
                .font(.system(size: 18))
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(palette.primaryColor).frame(height: 1) }
            let units = (showSeconds ? [(1, "seconds")] : []) + [(60, "minutes"), (3600, "hours"), (86400, "days")]
            ForEach(units, id: \.0) { unit in
                Button { multiplier = unit.0 } label: { RadioRow(title: unit.1, on: multiplier == unit.0) }
                    .buttonStyle(.plain)
            }
            HStack(spacing: 24) {
                Spacer()
                Button("Cancel") {
                    if let onCancel { onCancel() } else { dismiss() }
                }
                Button("OK") {
                    onPick((Int(value) ?? 0) * multiplier)
                    dismiss()
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(palette.primaryColor)
            .padding(.top, 16)
        }
        .onAppear { focused = true }
    }
}
