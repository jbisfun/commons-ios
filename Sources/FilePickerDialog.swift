import SwiftUI

/// A top-level storage location (Android: internal storage, SD card, OTG, root).
public struct StorageRoot: Hashable, Identifiable, Sendable {
    public var path: String
    public var title: String
    public var id: String { path }

    public init(path: String, title: String) {
        self.path = path
        self.title = title
    }

    /// The root that contains `path` (longest match first).
    public static func containing(_ path: String, in roots: [StorageRoot]) -> StorageRoot? {
        roots.sorted { $0.path.count > $1.path.count }.first { path == $0.path || path.hasPrefix($0.path.hasSuffix("/") ? $0.path : $0.path + "/") }
    }

    /// humanizePath(): the root path replaced by its title.
    public static func humanize(_ path: String, in roots: [StorageRoot]) -> String {
        guard let root = containing(path, in: roots) else { return path }
        return root.title + String(path.dropFirst(root.path.count))
    }
}

/// views.Breadcrumbs: the clickable components of the current path, first one being the storage.
public struct Breadcrumbs: View {
    @Environment(\.palette) private var palette
    let path: String
    let roots: [StorageRoot]
    var fontSize: CGFloat
    let onTap: (_ index: Int, _ path: String) -> Void

    public init(path: String, roots: [StorageRoot], fontSize: CGFloat = 16, onTap: @escaping (_ index: Int, _ path: String) -> Void) {
        self.path = path
        self.roots = roots
        self.fontSize = fontSize
        self.onTap = onTap
    }

    private var items: [(String, String)] {
        guard let root = StorageRoot.containing(path, in: roots) else {
            var acc = ""
            return path.split(separator: "/").map { part in
                acc += "/" + part
                return (String(part), acc)
            }
        }
        var result = [(root.title, root.path)]
        var acc = root.path
        for part in path.dropFirst(root.path.count).split(separator: "/") {
            acc += "/" + part
            result.append((String(part), acc))
        }
        return result
    }

    public var body: some View {
        let items = items
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Image(systemName: "chevron.right").font(.system(size: fontSize * 0.7)).foregroundStyle(palette.secondaryText)
                        }
                        Button { onTap(index, item.1) } label: {
                            Text(item.0)
                                .font(.system(size: fontSize, weight: index == items.count - 1 ? .medium : .regular))
                                .foregroundStyle(index == items.count - 1 ? palette.textColor : palette.secondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.horizontal, 10)
            }
            .onAppear { proxy.scrollTo(items.count - 1, anchor: .trailing) }
            .onChange(of: path) { _, _ in withAnimation { proxy.scrollTo(items.count - 1, anchor: .trailing) } }
        }
    }
}

/// StoragePickerDialog: choose one of the storage roots.
public struct StoragePickerDialog: View {
    let roots: [StorageRoot]
    let current: String
    let onPick: (String) -> Void

    public init(roots: [StorageRoot], current: String, onPick: @escaping (String) -> Void) {
        self.roots = roots
        self.current = current
        self.onPick = onPick
    }

    public var body: some View {
        RadioDialog(title: "Select storage", items: roots.map { ($0.path, $0.title) },
                    selected: StorageRoot.containing(current, in: roots)?.path ?? "", onPick: onPick)
    }
}

/// CreateNewFolderDialog.
public struct CreateNewFolderDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let path: String
    let humanized: String
    let onCreated: (String) -> Void
    @State private var name = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    public init(path: String, humanized: String? = nil, onCreated: @escaping (String) -> Void) {
        self.path = path
        self.humanized = humanized ?? path
        self.onCreated = onCreated
    }

    public var body: some View {
        DialogFrame(title: "Create new folder", scroll: false) {
            Text(humanized.hasSuffix("/") ? humanized : humanized + "/")
                .font(.system(size: 14)).foregroundStyle(palette.secondaryText).padding(.bottom, 8)
            DialogTextField(placeholder: "Folder", text: $name).focused($focused)
            if let error { Text(error).font(.system(size: 14)).foregroundStyle(.red).padding(.top, 6) }
            DialogButtons {
                if name.isEmpty {
                    error = "Please enter a name"
                } else if !name.isAValidFilename {
                    error = "The name contains invalid characters"
                } else if FileManager.default.fileExists(atPath: "\(path)/\(name)") {
                    error = "A file or folder with that name already exists"
                } else if (try? FileManager.default.createDirectory(atPath: "\(path)/\(name)", withIntermediateDirectories: true)) != nil {
                    onCreated("\(path)/\(name)")
                    dismiss()
                } else {
                    error = "Could not create folder \(name)"
                }
            }
        }
        .onAppear { focused = true }
    }
}

/// MyEditText inside a dialog: an underlined single-line field.
public struct DialogTextField: View {
    @Environment(\.palette) private var palette
    let placeholder: String
    @Binding var text: String
    var secure: Bool

    public init(placeholder: String, text: Binding<String>, secure: Bool = false) {
        self.placeholder = placeholder
        _text = text
        self.secure = secure
    }

    public var body: some View {
        VStack(spacing: 4) {
            Group {
                if secure {
                    SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(palette.secondaryText))
                } else {
                    TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(palette.secondaryText))
                }
            }
            .font(.system(size: 17))
            .foregroundStyle(palette.textColor)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            Rectangle().fill(palette.primaryColor).frame(height: 1.5)
        }
        .padding(.vertical, 6)
    }
}

/// FilePickerDialog: browse the storages and pick a folder (or a file with `pickFile`).
public struct FilePickerDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let roots: [StorageRoot]
    let pickFile: Bool
    let showFAB: Bool
    let canAddShowHiddenButton: Bool
    let favorites: [String]
    let onPick: (String) -> Void

    @State private var path: String
    @State private var showHidden: Bool
    @State private var items: [FileDirItem] = []
    @State private var pickStorage = false
    @State private var createFolder = false
    @State private var showFavorites = false

    public init(path: String, roots: [StorageRoot], pickFile: Bool = false, showHidden: Bool = false, showFAB: Bool = false,
                canAddShowHiddenButton: Bool = false, favorites: [String] = [], onPick: @escaping (String) -> Void) {
        let start = FileManager.default.fileExists(atPath: path) ? path : (roots.first?.path ?? path)
        _path = State(initialValue: start)
        _showHidden = State(initialValue: showHidden)
        self.roots = roots
        self.pickFile = pickFile
        self.showFAB = showFAB
        self.canAddShowHiddenButton = canAddShowHiddenButton
        self.favorites = favorites
        self.onPick = onPick
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(pickFile ? "Select a file" : "Select a folder")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(palette.textColor)
                .padding(.horizontal, 24)
                .padding(.top, 24)
            Breadcrumbs(path: path, roots: roots) { index, p in
                if index == 0 && roots.count > 1 { pickStorage = true } else { path = p }
            }
            .padding(.horizontal, 8)
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if items.isEmpty {
                            Text("No items found.").italic().foregroundStyle(palette.secondaryText).padding(.top, 32)
                        }
                        ForEach(items) { item in
                            Button {
                                if item.isDirectory {
                                    path = item.path
                                } else if pickFile {
                                    onPick(item.path)
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                                        .font(.system(size: 24))
                                        .foregroundStyle(item.isDirectory ? palette.primaryColor.opacity(0.7) : palette.secondaryText)
                                        .frame(width: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).foregroundStyle(palette.textColor).lineLimit(1)
                                        Text(item.isDirectory ? "\(item.children) item\(item.children == 1 ? "" : "s")" : item.size.formattedSize)
                                            .font(.system(size: 13)).foregroundStyle(palette.secondaryText)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 80)
                }
                VStack(spacing: 12) {
                    if canAddShowHiddenButton {
                        smallFab(showHidden ? "eye.slash" : "eye") { showHidden.toggle() }
                    }
                    if !favorites.isEmpty {
                        smallFab("star") { showFavorites = true }
                    }
                    if showFAB {
                        Button { createFolder = true } label: {
                            Image(systemName: "plus").font(.system(size: 22, weight: .medium)).foregroundStyle(palette.onPrimary)
                                .frame(width: 56, height: 56).background(Circle().fill(palette.primaryColor))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            HStack(spacing: 24) {
                Spacer()
                Button("Cancel") { dismiss() }
                if !pickFile {
                    Button("OK") {
                        onPick(path)
                        dismiss()
                    }
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(palette.primaryColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(palette.surface.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task(id: "\(path)|\(showHidden)") { load() }
        .sheet(isPresented: $pickStorage) {
            StoragePickerDialog(roots: roots, current: path) { path = $0 }
        }
        .sheet(isPresented: $createFolder) {
            CreateNewFolderDialog(path: path, humanized: StorageRoot.humanize(path, in: roots)) { new in
                path = new
            }
        }
        .sheet(isPresented: $showFavorites) {
            RadioDialog(title: "Go to favorite", items: favorites.map { ($0, StorageRoot.humanize($0, in: roots).replacingOccurrences(of: "/", with: " / ")) },
                        selected: path) { path = $0 }
        }
    }

    private func smallFab(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(palette.onPrimary)
                .frame(width: 42, height: 42).background(Circle().fill(palette.primaryColor))
        }
        .buttonStyle(.plain)
    }

    private func load() {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        let list = names
            .filter { showHidden || !$0.hasPrefix(".") }
            .compactMap { FileDirItem(path: "\(path)/\($0)", countChildren: true, countHidden: showHidden) }
            .filter { pickFile || $0.isDirectory }
        items = list.sorted { FileDirItem.areInIncreasingOrder($0, $1, sorting: Sorting.byName | Sorting.useNumericValue) }
    }
}
