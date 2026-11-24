import Foundation

/// Sorting flags shared by every Fossify app (SORT_BY_* / SORT_DESCENDING / SORT_USE_NUMERIC_VALUE).
public enum Sorting {
    public static let byName = 1
    public static let byDateModified = 2
    public static let bySize = 4
    public static let byDateTaken = 8
    public static let byExtension = 16
    public static let byPath = 32
    public static let descending = 1024
    public static let useNumericValue = 32768
}

/// VIEW_TYPE_GRID / VIEW_TYPE_LIST.
public enum ViewTypes {
    public static let grid = 1
    public static let list = 2
}

/// models.FileDirItem: one file or folder of the local file system, addressed by its path.
public struct FileDirItem: Hashable, Identifiable, Sendable {
    public var path: String
    public var name: String
    public var isDirectory: Bool
    public var children: Int
    public var size: Int64
    public var modified: Date

    public var id: String { path }

    public init(path: String, name: String? = nil, isDirectory: Bool = false, children: Int = 0, size: Int64 = 0, modified: Date = .distantPast) {
        self.path = path
        self.name = name ?? path.filenameFromPath
        self.isDirectory = isDirectory
        self.children = children
        self.size = size
        self.modified = modified
    }

    /// File.toFileDirItem(): reads the item from disk, nil if it doesn't exist.
    public init?(path: String, countChildren: Bool = false, countHidden: Bool = false) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        self.init(path: path, isDirectory: isDir.boolValue,
                  children: isDir.boolValue && countChildren ? FileDirItem.directChildrenCount(path, countHidden: countHidden) : 0,
                  size: isDir.boolValue ? 0 : (attrs?[.size] as? NSNumber)?.int64Value ?? 0,
                  modified: attrs?[.modificationDate] as? Date ?? .distantPast)
    }

    public var parentPath: String { path.parentPath }

    /// getExtension(): folders sort by their name.
    public var fileExtension: String { isDirectory ? name : path.fileExtension }

    /// FileDirItem.compareTo(): folders first, then by the sorting flags.
    public static func areInIncreasingOrder(_ a: FileDirItem, _ b: FileDirItem, sorting: Int) -> Bool {
        if a.isDirectory != b.isDirectory { return a.isDirectory }
        var result: ComparisonResult
        if sorting & Sorting.byName != 0 {
            if sorting & Sorting.useNumericValue != 0 {
                result = a.name.normalizedForSearch.lowercased().compare(b.name.normalizedForSearch.lowercased(), options: .numeric)
            } else {
                let x = a.name.normalizedForSearch.lowercased(), y = b.name.normalizedForSearch.lowercased()
                result = x == y ? .orderedSame : (x < y ? .orderedAscending : .orderedDescending)
            }
        } else if sorting & Sorting.bySize != 0 {
            result = a.size == b.size ? .orderedSame : (a.size < b.size ? .orderedAscending : .orderedDescending)
        } else if sorting & Sorting.byDateModified != 0 {
            result = a.modified == b.modified ? .orderedSame : (a.modified < b.modified ? .orderedAscending : .orderedDescending)
        } else {
            let x = a.fileExtension.lowercased(), y = b.fileExtension.lowercased()
            result = x == y ? .orderedSame : (x < y ? .orderedAscending : .orderedDescending)
        }
        if sorting & Sorting.descending != 0 {
            return result == .orderedDescending
        }
        return result == .orderedAscending
    }

    /// getBubbleText(): what the fast scroller shows for the current sorting.
    public func bubbleText(sorting: Int) -> String {
        if sorting & Sorting.bySize != 0 { return size.formattedSize }
        if sorting & Sorting.byDateModified != 0 { return DateTimeFormat.shared.format(modified) }
        if sorting & Sorting.byExtension != 0 { return fileExtension.lowercased() }
        return name
    }

    /// File.getDirectChildrenCount().
    public static func directChildrenCount(_ path: String, countHidden: Bool) -> Int {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        return countHidden ? names.count : names.filter { !$0.hasPrefix(".") }.count
    }

    /// File.getProperSize(): the size of a file, or everything inside a folder.
    public static func properSize(_ path: String, countHidden: Bool) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            return ((try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? NSNumber)?.int64Value ?? 0
        }
        var total: Int64 = 0
        walk(path, countHidden: countHidden) { _, isDirectory, size in if !isDirectory { total += size } }
        return total
    }

    /// File.getFileCount(): files inside a folder, recursively.
    public static func fileCount(_ path: String, countHidden: Bool) -> Int {
        var count = 0
        walk(path, countHidden: countHidden) { _, isDirectory, _ in if !isDirectory { count += 1 } }
        return count
    }

    /// Recursively visits everything below `path` (not `path` itself), skipping hidden
    /// items and the content of hidden folders unless `countHidden`.
    public static func walk(_ path: String, countHidden: Bool, _ visit: (_ path: String, _ isDirectory: Bool, _ size: Int64) -> Void) {
        guard let e = FileManager.default.enumerator(atPath: path) else { return }
        let base = path.hasSuffix("/") ? path : path + "/"
        while let relative = e.nextObject() as? String {
            let attrs = e.fileAttributes
            let isDir = (attrs?[.type] as? FileAttributeType) == .typeDirectory
            if !countHidden && relative.filenameFromPath.hasPrefix(".") {
                if isDir { e.skipDescendants() }
                continue
            }
            visit(base + relative, isDir, (attrs?[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }
}

extension String {
    /// getFilenameFromPath().
    public var filenameFromPath: String {
        let trimmed = hasSuffix("/") && count > 1 ? String(dropLast()) : self
        return trimmed.components(separatedBy: "/").last ?? trimmed
    }

    /// getParentPath().
    public var parentPath: String {
        var p = self
        if p.hasSuffix("/") && p.count > 1 { p.removeLast() }
        guard let slash = p.lastIndex(of: "/") else { return p }
        let parent = String(p[..<slash])
        return parent.isEmpty ? "/" : parent
    }

    /// The extension after the last dot of the file name ("" if none).
    public var fileExtension: String {
        let name = filenameFromPath
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return String(name[name.index(after: dot)...])
    }

    /// isAValidFilename().
    public var isAValidFilename: Bool {
        let illegal: Set<Character> = ["/", "\n", "\r", "\t", "\0", "\u{0C}", "`", "?", "*", "\\", "<", ">", "|", "\"", ":"]
        return !contains { illegal.contains($0) }
    }

    /// normalizeString(): strips diacritics for searching and sorting.
    public var normalizedForSearch: String {
        folding(options: .diacriticInsensitive, locale: nil)
    }

    /// Path with `parent/name` made unique by appending _1, _2, ... (getAvailablePath / keep both).
    public var availablePath: String {
        guard FileManager.default.fileExists(atPath: self) else { return self }
        let parent = parentPath, name = filenameFromPath, ext = fileExtension
        let base = ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
        var i = 1
        while true {
            let candidate = "\(parent)/\(base)_\(i)\(ext.isEmpty ? "" : "." + ext)"
            if !FileManager.default.fileExists(atPath: candidate) { return candidate }
            i += 1
        }
    }
}
