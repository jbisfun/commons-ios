import Observation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Fossify Commons' blocked numbers. Android keeps them in BlockedNumberContract, which
/// only the default dialer/SMS app may use; iOS has nothing apps can read, so the apps
/// keep the list themselves (UserDefaults, shared by every app inside the launcher).
@Observable
public final class BlockedNumbers {
    public static let shared = BlockedNumbers()

    @ObservationIgnored private let d = UserDefaults.standard
    public private(set) var numbers: [String] { didSet { d.set(numbers, forKey: "blocked_numbers_list") } }

    private init() {
        numbers = d.stringArray(forKey: "blocked_numbers_list") ?? []
    }

    /// addBlockedNumber().
    public func add(_ number: String) {
        let n = number.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, !numbers.contains(n) else { return }
        numbers.append(n)
    }

    /// deleteBlockedNumber().
    public func remove(_ number: String) {
        numbers.removeAll { $0 == number }
    }

    /// isNumberBlocked(): exact/last-digits match, or a "*" pattern (isNumberBlockedByPattern()).
    public func isBlocked(_ number: String) -> Bool {
        let compare = Self.comparable(number)
        let stripped = number.filter { !" -()./".contains($0) }
        for b in numbers {
            if b.contains("*") {
                let pattern = "^" + NSRegularExpression.escapedPattern(for: b).replacingOccurrences(of: "\\*", with: ".*") + "$"
                if number.range(of: pattern, options: .regularExpression) != nil { return true }
            } else if (!compare.isEmpty && compare == Self.comparable(b)) || stripped == b {
                return true
            }
        }
        return false
    }

    /// String.trimToComparableNumber(): the last 9 digits.
    static func comparable(_ number: String) -> String {
        String(number.filter { $0.isASCII && $0.isNumber }.suffix(9))
    }
}

/// ManageBlockedNumbersActivity.
public struct ManageBlockedNumbersView: View {
    private let blocked = BlockedNumbers.shared

    public init() {}

    public var body: some View {
        BlockedItemsView(
            title: "Manage blocked numbers",
            items: blocked.numbers.sorted(),
            placeholder: "You are not blocking anyone.",
            addTitle: "Add a blocked number",
            importTitle: "Import blocked numbers",
            exportTitle: "Export blocked numbers",
            exportName: "Blocked numbers",
            fieldLabel: "Number",
            helperText: "Enter a number or a pattern (e.g. *12345*, +1*8888) to block all calls and messages from numbers matching the pattern.",
            keyboard: .phonePad,
            add: { number in
                // in case the user also added a '.' in the pattern, remove it
                blocked.add(number.replacingOccurrences(of: ".*", with: "*"))
            },
            remove: blocked.remove)
    }
}

/// Shared screen behind ManageBlockedNumbersActivity and similar block lists
/// (e.g. Messages' blocked keywords): add/edit dialog, copy, delete, .txt import/export.
public struct BlockedItemsView: View {
    @Environment(\.palette) private var palette
    let title: String
    let items: [String]
    let placeholder: String
    let addTitle: String
    let importTitle: String
    let exportTitle: String
    let exportName: String
    let fieldLabel: String
    let helperText: String?
    let keyboard: UIKeyboardType
    let add: (String) -> Void
    let remove: (String) -> Void

    @State private var editing: EditedItem?
    @State private var selection = Set<String>()
    @State private var importing = false
    @State private var exportDialog = false
    @State private var exportFile: URL?
    @State private var toast: String?

    public init(title: String, items: [String], placeholder: String, addTitle: String, importTitle: String,
                exportTitle: String, exportName: String, fieldLabel: String, helperText: String? = nil,
                keyboard: UIKeyboardType = .default, add: @escaping (String) -> Void, remove: @escaping (String) -> Void) {
        self.title = title
        self.items = items
        self.placeholder = placeholder
        self.addTitle = addTitle
        self.importTitle = importTitle
        self.exportTitle = exportTitle
        self.exportName = exportName
        self.fieldLabel = fieldLabel
        self.helperText = helperText
        self.keyboard = keyboard
        self.add = add
        self.remove = remove
    }

    struct EditedItem: Identifiable {
        let id = UUID()
        var original: String?
    }

    public var body: some View {
        VStack(spacing: 0) {
            if selection.isEmpty {
                TopBar(title: title) {
                    IconButton(icon: "plus") { editing = EditedItem(original: nil) }
                    OverflowMenu {
                        Button(importTitle) { importing = true }
                        Button(exportTitle) {
                            if items.isEmpty { toast = "No entries for exporting have been found" } else { exportDialog = true }
                        }
                    }
                }
            } else {
                selectionBar
            }
            if items.isEmpty {
                VStack(spacing: 16) {
                    Text(placeholder).font(.system(size: 17).italic()).multilineTextAlignment(.center)
                    Button { editing = EditedItem(original: nil) } label: {
                        Text(addTitle).underline().foregroundStyle(palette.primaryColor)
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items, id: \.self) { item in
                            row(item)
                        }
                    }
                }
            }
        }
        .background(palette.backgroundColor.ignoresSafeArea())
        .toast($toast)
        .sheet(item: $editing) { e in
            BlockedItemDialog(title: e.original == nil ? addTitle : nil, label: fieldLabel, helperText: helperText,
                              keyboard: keyboard, value: e.original ?? "") { value in
                if let o = e.original, o != value { remove(o) }
                if !value.isEmpty { add(value) }
            }
        }
        .sheet(isPresented: $exportDialog) {
            ExportTextFileDialog(title: exportTitle, defaultName: "\(exportName)_\(Self.timestamp())") { name in
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".txt")
                do {
                    try items.joined(separator: ",").write(to: url, atomically: true, encoding: .utf8)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exportFile = url }
                } catch {
                    toast = "Exporting failed"
                }
            }
        }
        .fileMover(isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }), file: exportFile) { result in
            if case .success = result { toast = "Exporting successful" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, .text, .data]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let values = ((try? String(contentsOf: url, encoding: .utf8)) ?? "")
                .split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            values.forEach(add)
            toast = values.isEmpty ? "No items found." : "Importing successful"
        }
    }

    private func row(_ item: String) -> some View {
        let selected = selection.contains(item)
        return Text(item)
            .font(.system(size: palette.fontSize))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(selected ? palette.primaryColor.opacity(0.25) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                if selection.isEmpty { editing = EditedItem(original: item) } else { toggle(item) }
            }
            .onLongPressGesture { toggle(item) }
    }

    private func toggle(_ item: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if selection.contains(item) { selection.remove(item) } else { selection.insert(item) }
    }

    /// cab_blocked_numbers: copy (single item) and delete.
    private var selectionBar: some View {
        ActionModeBar(count: selection.count, onClose: { selection.removeAll() }) {
            if selection.count == 1, let item = selection.first {
                IconButton(icon: "doc.on.doc") {
                    toast = Launcher.copy(item)
                    selection.removeAll()
                }
            }
            IconButton(icon: "trash") {
                selection.forEach(remove)
                selection.removeAll()
            }
        }
    }

    static func timestamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy_MM_dd_HH_mm_ss"
        return f.string(from: Date())
    }
}

/// AddBlockedNumberDialog / AddBlockedKeywordDialog.
struct BlockedItemDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let title: String?
    let label: String
    let helperText: String?
    let keyboard: UIKeyboardType
    @State var value: String
    let onSave: (String) -> Void
    @FocusState private var focused: Bool

    init(title: String?, label: String, helperText: String?, keyboard: UIKeyboardType, value: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.label = label
        self.helperText = helperText
        self.keyboard = keyboard
        _value = State(initialValue: value)
        self.onSave = onSave
    }

    var body: some View {
        DialogFrame(title: title, scroll: false) {
            Text(label).font(.system(size: 13)).foregroundStyle(palette.primaryColor)
            TextField("", text: $value)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .padding(.vertical, 8)
            Divider().overlay(palette.primaryColor)
            if let helperText {
                Text(helperText).font(.system(size: 13)).foregroundStyle(palette.secondaryText).padding(.top, 6)
            }
            DialogButtons {
                onSave(value.trimmingCharacters(in: .whitespaces))
                dismiss()
            }
        }
        .presentationDetents([.medium])
        .onAppear { focused = true }
    }
}

/// ExportBlockedNumbersDialog without the folder row (the system picker chooses it):
/// asks for a file name, validated like isAValidFilename().
public struct ExportTextFileDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onExport: (String) -> Void
    @State private var name: String
    @State private var error: String?

    public init(title: String, defaultName: String, onExport: @escaping (String) -> Void) {
        self.title = title
        self.onExport = onExport
        _name = State(initialValue: defaultName)
    }

    public var body: some View {
        DialogFrame(title: title, scroll: false) {
            Text("Filename").font(.system(size: 13)).foregroundStyle(palette.primaryColor)
            TextField("", text: $name)
                .autocorrectionDisabled()
                .padding(.vertical, 8)
            Divider().overlay(palette.primaryColor)
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(.red).padding(.top, 6)
            }
            DialogButtons {
                let n = name.trimmingCharacters(in: .whitespaces)
                if n.isEmpty {
                    error = "Please enter a name"
                } else if n.contains(where: { "/\\:*?\"<>|\n\r\t\0`".contains($0) }) {
                    error = "The name contains invalid characters"
                } else {
                    onExport(n)
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium])
    }
}
