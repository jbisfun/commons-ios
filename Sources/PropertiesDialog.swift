import AVFoundation
import CryptoKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// PropertiesDialog for one or more files/folders. Values load in the background;
/// long-press a value to copy it.
public struct PropertiesDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let paths: [String]
    let countHidden: Bool
    let humanize: (String) -> String
    @State private var rows: [(String, String)] = []

    public init(paths: [String], countHidden: Bool, humanize: @escaping (String) -> String = { $0 }) {
        self.paths = paths
        self.countHidden = countHidden
        self.humanize = humanize
    }

    public var body: some View {
        DialogFrame(title: "Properties") {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.0).font(.system(size: 14, weight: .medium)).foregroundStyle(palette.textColor)
                    Text(row.1).font(.system(size: 15)).foregroundStyle(palette.secondaryText).textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .contextMenu { Button("Copy") { UIPasteboard.general.string = row.1 } }
            }
            HStack {
                Spacer()
                Button("OK") { dismiss() }.font(.system(size: 16, weight: .medium)).foregroundStyle(palette.primaryColor)
            }
            .padding(.top, 16)
        }
        .task { await load() }
    }

    private func set(_ label: String, _ value: String) {
        if let i = rows.firstIndex(where: { $0.0 == label }) { rows[i].1 = value } else { rows.append((label, value)) }
    }

    @MainActor
    private func load() async {
        let countHidden = countHidden
        if paths.count == 1, let item = FileDirItem(path: paths[0]) {
            set("Name", item.name)
            set("Path", humanize(item.parentPath))
            set("Size", "…")
            if item.isDirectory {
                set("Direct children count", "…")
                set("Total files count", "…")
            }
            let type = UTType(filenameExtension: item.path.fileExtension.lowercased())
            if !item.isDirectory, let type {
                if type.conforms(to: .image) {
                    for (k, v) in Self.imageProperties(item.path) { set(k, v) }
                } else if type.conforms(to: .audiovisualContent) {
                    for (k, v) in await Self.mediaProperties(item.path, isAudio: type.conforms(to: .audio)) { set(k, v) }
                }
            }
            set("Last modified", DateTimeFormat.shared.format(item.modified))
            if !item.isDirectory {
                set("MD5", "…")
                set("SHA-1", "…")
                set("SHA-256", "…")
            }
            let path = item.path, isDir = item.isDirectory
            let size = await Task.detached { FileDirItem.properSize(path, countHidden: countHidden) }.value
            set("Size", size.formattedSize)
            if isDir {
                set("Direct children count", "\(FileDirItem.directChildrenCount(path, countHidden: countHidden))")
                let files = await Task.detached { FileDirItem.fileCount(path, countHidden: countHidden) }.value
                set("Total files count", "\(files)")
            } else {
                let hashes = await Task.detached { Self.digests(path) }.value
                set("MD5", hashes.0)
                set("SHA-1", hashes.1)
                set("SHA-256", hashes.2)
            }
        } else {
            let items = paths.compactMap { FileDirItem(path: $0) }
            set("Items selected", "\(paths.count)")
            if Set(items.map(\.parentPath)).count == 1, let first = items.first {
                set("Path", humanize(first.parentPath))
            }
            set("Size", "…")
            set("Total files count", "…")
            let paths = paths
            let totals = await Task.detached { () -> (Int64, Int) in
                var size: Int64 = 0, files = 0
                for p in paths {
                    size += FileDirItem.properSize(p, countHidden: countHidden)
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: p, isDirectory: &isDir)
                    files += isDir.boolValue ? FileDirItem.fileCount(p, countHidden: countHidden) : 1
                }
                return (size, files)
            }.value
            set("Size", totals.0.formattedSize)
            set("Total files count", "\(totals.1)")
        }
    }

    /// Resolution, date taken, camera, GPS (ExifInterface).
    private static func imageProperties(_ path: String) -> [(String, String)] {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return [] }
        var result: [(String, String)] = []
        if let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int {
            result.append(("Resolution", "\(w) x \(h) (\(megapixels(w, h)))"))
        }
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any], let taken = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy:MM:dd HH:mm:ss"
            result.append(("Date taken", f.date(from: taken).map { DateTimeFormat.shared.format($0) } ?? taken))
        }
        if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            let camera = [tiff[kCGImagePropertyTIFFMake] as? String, tiff[kCGImagePropertyTIFFModel] as? String].compactMap { $0 }.joined(separator: " ")
            if !camera.isEmpty { result.append(("Camera", camera)) }
        }
        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           var lat = gps[kCGImagePropertyGPSLatitude] as? Double, var lon = gps[kCGImagePropertyGPSLongitude] as? Double {
            if gps[kCGImagePropertyGPSLatitudeRef] as? String == "S" { lat = -lat }
            if gps[kCGImagePropertyGPSLongitudeRef] as? String == "W" { lon = -lon }
            result.append(("GPS coordinates", "\(lat), \(lon)"))
            if let alt = gps[kCGImagePropertyGPSAltitude] as? Double { result.append(("Altitude", "\(alt)m")) }
        }
        return result
    }

    private static func megapixels(_ w: Int, _ h: Int) -> String {
        let mp = (Double(w * h) / 1_000_000 * 10).rounded() / 10
        return "\(mp)MP"
    }

    /// Duration, resolution, title, artist, album (MediaMetadataRetriever).
    private static func mediaProperties(_ path: String, isAudio: Bool) async -> [(String, String)] {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        var result: [(String, String)] = []
        if let duration = try? await asset.load(.duration), duration.seconds.isFinite, duration.seconds > 0 {
            result.append(("Duration", Int(duration.seconds.rounded()).formattedDuration()))
        }
        if !isAudio, let track = try? await asset.loadTracks(withMediaType: .video).first,
           let size = try? await track.load(.naturalSize), let t = try? await track.load(.preferredTransform) {
            let s = size.applying(t)
            result.append(("Resolution", "\(Int(abs(s.width))) x \(Int(abs(s.height)))"))
        }
        let metadata = (try? await asset.load(.commonMetadata)) ?? []
        func value(_ id: AVMetadataIdentifier) async -> String? {
            guard let item = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: id).first else { return nil }
            return try? await item.load(.stringValue)
        }
        if isAudio, let title = await value(.commonIdentifierTitle) { result.append(("Song title", title)) }
        if let artist = await value(.commonIdentifierArtist) { result.append(("Artist", artist)) }
        if let album = await value(.commonIdentifierAlbumName) { result.append(("Album", album)) }
        return result
    }

    /// MD5 / SHA-1 / SHA-256 of a file, streamed.
    private static func digests(_ path: String) -> (String, String, String) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return ("", "", "") }
        defer { try? handle.close() }
        var md5 = Insecure.MD5(), sha1 = Insecure.SHA1(), sha256 = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            md5.update(data: chunk)
            sha1.update(data: chunk)
            sha256.update(data: chunk)
        }
        func hex<D: Digest>(_ d: D) -> String { d.map { String(format: "%02x", $0) }.joined() }
        return (hex(md5.finalize()), hex(sha1.finalize()), hex(sha256.finalize()))
    }
}
