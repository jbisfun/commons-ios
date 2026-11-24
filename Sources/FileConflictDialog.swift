import SwiftUI

/// CONFLICT_SKIP / CONFLICT_OVERWRITE / CONFLICT_MERGE / CONFLICT_KEEP_BOTH.
public enum ConflictResolution: Int, Sendable {
    case skip = 1, overwrite, merge, keepBoth
}

/// FileConflictDialog: what to do with an item that already exists at the destination.
public struct FileConflictDialog: View {
    @Environment(\.dismiss) private var dismiss
    let item: FileDirItem
    let showApplyToAll: Bool
    let onResolve: (ConflictResolution, Bool) -> Void
    @State private var resolution: ConflictResolution
    @State private var applyToAll: Bool

    public init(item: FileDirItem, showApplyToAll: Bool, onResolve: @escaping (ConflictResolution, Bool) -> Void) {
        self.item = item
        self.showApplyToAll = showApplyToAll
        self.onResolve = onResolve
        let d = UserDefaults.standard
        var last = ConflictResolution(rawValue: d.object(forKey: "last_conflict_resolution") as? Int ?? 1) ?? .skip
        if last == .merge && !item.isDirectory { last = .skip }
        _resolution = State(initialValue: last)
        _applyToAll = State(initialValue: d.object(forKey: "last_conflict_apply_to_all") as? Bool ?? true)
    }

    public var body: some View {
        DialogFrame(title: nil) {
            Text(item.isDirectory ? "Folder \"\(item.name)\" already exists" : "File \"\(item.name)\" already exists")
                .font(.system(size: 17)).padding(.bottom, 8)
            option(.skip, "Skip")
            option(.overwrite, "Overwrite")
            if item.isDirectory { option(.merge, "Merge") }
            option(.keepBoth, "Keep both")
            if showApplyToAll {
                Divider().padding(.vertical, 8)
                CheckRow(title: "Apply to all conflicts", on: $applyToAll)
            }
            DialogButtons {
                UserDefaults.standard.set(resolution.rawValue, forKey: "last_conflict_resolution")
                UserDefaults.standard.set(applyToAll, forKey: "last_conflict_apply_to_all")
                onResolve(resolution, applyToAll && showApplyToAll)
                dismiss()
            }
        }
        .interactiveDismissDisabled()
    }

    private func option(_ r: ConflictResolution, _ title: String) -> some View {
        Button { resolution = r } label: { RadioRow(title: title, on: resolution == r) }.buttonStyle(.plain)
    }
}

/// checkConflicts(): asks about every item that already exists in `destination`, then
/// calls `completion` with path -> resolution ("" -> resolution when applied to all).
public struct ConflictCheck: Identifiable {
    public let id = UUID()
    public var items: [FileDirItem]
    public var destination: String
    public var completion: ([String: ConflictResolution]) -> Void
    public var onCancel: () -> Void

    public init(items: [FileDirItem], destination: String, completion: @escaping ([String: ConflictResolution]) -> Void, onCancel: @escaping () -> Void = {}) {
        self.items = items
        self.destination = destination
        self.completion = completion
        self.onCancel = onCancel
    }

    /// getConflictResolution().
    public static func resolution(for path: String, in resolutions: [String: ConflictResolution]) -> ConflictResolution {
        if resolutions.count == 1, let all = resolutions[""] { return all }
        return resolutions[path] ?? .skip
    }
}

private struct ConflictCheckModifier: ViewModifier {
    @Binding var check: ConflictCheck?
    @State private var pending: [FileDirItem] = []
    @State private var current: FileDirItem?
    @State private var resolutions: [String: ConflictResolution] = [:]
    @State private var active: ConflictCheck?
    @State private var answered = false

    func body(content: Content) -> some View {
        content
            .onChange(of: check?.id) { _, _ in start() }
            .onAppear { start() }
            .sheet(item: $current, onDismiss: next) { item in
                FileConflictDialog(item: item, showApplyToAll: pending.count > 0) { r, all in
                    answered = true
                    let path = "\(active?.destination ?? "")/\(item.name)"
                    if all {
                        resolutions = ["": r]
                        pending = []
                    } else {
                        resolutions[path] = r
                    }
                }
            }
    }

    private func start() {
        guard let c = check, active?.id != c.id else { return }
        active = c
        check = nil
        resolutions = [:]
        pending = c.items.filter { FileManager.default.fileExists(atPath: "\(c.destination)/\($0.name)") }
        if pending.isEmpty {
            finish()
        } else {
            current = pending.removeFirst()
        }
    }

    private func next() {
        guard answered else {
            active?.onCancel()
            active = nil
            return
        }
        answered = false
        if pending.isEmpty {
            finish()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { current = pending.removeFirst() }
        }
    }

    private func finish() {
        let c = active
        active = nil
        c?.completion(resolutions)
    }
}

extension View {
    /// Runs a conflict check (FileConflictDialog per conflicting item) whenever `check` is set.
    public func conflictCheck(_ check: Binding<ConflictCheck?>) -> some View {
        modifier(ConflictCheckModifier(check: check))
    }
}
