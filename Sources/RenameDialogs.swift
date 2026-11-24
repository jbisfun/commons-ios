import ImageIO
import SwiftUI

/// renameFile(): moves `old` to `new`, handling case-only renames on case-insensitive volumes.
public enum FileRename {
    @discardableResult
    public static func rename(_ old: String, to new: String) -> Bool {
        let fm = FileManager.default
        if old == new { return true }
        do {
            if old.lowercased() == new.lowercased() {
                let temp = "\(old.parentPath)/.\(UUID().uuidString)"
                try fm.moveItem(atPath: old, toPath: temp)
                try fm.moveItem(atPath: temp, toPath: new)
            } else {
                guard !fm.fileExists(atPath: new) else { return false }
                try fm.moveItem(atPath: old, toPath: new)
            }
            return true
        } catch {
            return false
        }
    }
}

/// RenameItemDialog: rename one file or folder (name + extension).
public struct RenameItemDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let path: String
    let onRenamed: (String) -> Void
    @State private var name: String
    @State private var ext: String
    @State private var error: String?
    private let isDirectory: Bool

    public init(path: String, onRenamed: @escaping (String) -> Void) {
        self.path = path
        self.onRenamed = onRenamed
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        isDirectory = isDir.boolValue
        let full = path.filenameFromPath
        let ext = isDir.boolValue ? "" : full.fileExtension
        _ext = State(initialValue: ext)
        _name = State(initialValue: ext.isEmpty ? full : String(full.dropLast(ext.count + 1)))
    }

    public var body: some View {
        DialogFrame(title: "Rename", scroll: false) {
            DialogTextField(placeholder: "Name", text: $name)
            if !isDirectory {
                DialogTextField(placeholder: "Extension", text: $ext)
            }
            if let error { Text(error).font(.system(size: 14)).foregroundStyle(.red).padding(.top, 6) }
            DialogButtons(ok: "OK") { confirm() }
        }
    }

    private func confirm() {
        guard !name.isEmpty else { error = "Filename cannot be empty"; return }
        var newName = name
        if !ext.isEmpty { newName += "." + ext }
        guard newName.isAValidFilename else { error = "Filename contains invalid characters"; return }
        let newPath = "\(path.parentPath)/\(newName)"
        if newPath == path { dismiss(); return }
        if newPath.lowercased() != path.lowercased() && FileManager.default.fileExists(atPath: newPath) {
            error = "A file or folder with that name already exists"
            return
        }
        if FileRename.rename(path, to: newPath) {
            onRenamed(newPath)
            dismiss()
        } else {
            error = "An unknown error occurred"
        }
    }
}

/// RenameDialog / RenameItemsDialog: rename several items at once, by adding text before or
/// after their names, or (files only) through a date/number pattern.
public struct RenameItemsDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let paths: [String]
    let allowPattern: Bool
    let onRenamed: () -> Void
    @State private var tab = 0
    @State private var text = ""
    @State private var append = true
    @State private var pattern = UserDefaults.standard.string(forKey: "last_rename_pattern_used") ?? ""
    @State private var error: String?

    public init(paths: [String], allowPattern: Bool, onRenamed: @escaping () -> Void) {
        self.paths = paths
        self.allowPattern = allowPattern
        self.onRenamed = onRenamed
    }

    public var body: some View {
        DialogFrame(title: "Rename", scroll: false) {
            if allowPattern {
                Picker("", selection: $tab) {
                    Text("Simple renaming").tag(0)
                    Text("Pattern").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 12)
            }
            if tab == 0 {
                DialogTextField(placeholder: "Text", text: $text)
                Button { append = true } label: { RadioRow(title: "Add text after filenames", on: append) }.buttonStyle(.plain)
                Button { append = false } label: { RadioRow(title: "Add text before filenames", on: !append) }.buttonStyle(.plain)
            } else {
                DialogTextField(placeholder: "Pattern", text: $pattern)
                Text("%Y year, %M month, %D day, %h hour, %m minute, %s second, %i incremental number")
                    .font(.system(size: 13)).foregroundStyle(palette.secondaryText).padding(.top, 4)
            }
            if let error { Text(error).font(.system(size: 14)).foregroundStyle(.red).padding(.top, 6) }
            DialogButtons { tab == 0 ? renameSimple() : renamePattern() }
        }
    }

    private func renameSimple() {
        guard !text.isEmpty else { dismiss(); return }
        guard text.isAValidFilename else { error = "The name contains invalid characters"; return }
        for path in paths where FileManager.default.fileExists(atPath: path) {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            let full = path.filenameFromPath
            let ext = isDir.boolValue ? "" : full.fileExtension
            let base = ext.isEmpty ? full : String(full.dropLast(ext.count + 1))
            let newBase = append ? base + text : text + base
            let newPath = "\(path.parentPath)/\(newBase)\(ext.isEmpty ? "" : "." + ext)"
            FileRename.rename(path, to: newPath)
        }
        onRenamed()
        dismiss()
    }

    private func renamePattern() {
        guard !pattern.isEmpty else { dismiss(); return }
        guard pattern.isAValidFilename else { error = "The name contains invalid characters"; return }
        UserDefaults.standard.set(pattern, forKey: "last_rename_pattern_used")
        let valid = paths.filter { FileManager.default.fileExists(atPath: $0) }
        let digits = String(valid.count).count
        var number = 1
        for path in valid {
            let date = Self.dateTaken(path) ?? FileDirItem(path: path)?.modified ?? Date()
            let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            func two(_ v: Int?) -> String { String(format: "%02d", v ?? 0) }
            var newName = pattern
                .replacingOccurrences(of: "%Y", with: "\(c.year ?? 0)")
                .replacingOccurrences(of: "%M", with: two(c.month))
                .replacingOccurrences(of: "%D", with: two(c.day))
                .replacingOccurrences(of: "%h", with: two(c.hour))
                .replacingOccurrences(of: "%m", with: two(c.minute))
                .replacingOccurrences(of: "%s", with: two(c.second))
                .replacingOccurrences(of: "%i", with: String(format: "%0\(digits)d", number))
            number += 1
            if !newName.contains(".") && path.filenameFromPath.contains(".") {
                newName += "." + path.fileExtension
            }
            var newPath = "\(path.parentPath)/\(newName)"
            var index = 0
            while FileManager.default.fileExists(atPath: newPath) {
                index += 1
                let ext = newName.fileExtension
                let base = ext.isEmpty ? newName : String(newName.dropLast(ext.count + 1))
                newPath = "\(path.parentPath)/\(base)~\(index)\(ext.isEmpty ? "" : "." + ext)"
            }
            FileRename.rename(path, to: newPath)
        }
        onRenamed()
        dismiss()
    }

    /// EXIF DateTimeOriginal, if any.
    private static func dateTaken(_ path: String) -> Date? {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let taken = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f.date(from: taken)
    }
}
