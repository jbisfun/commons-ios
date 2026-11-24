import Foundation
import Observation
import SwiftUI

/// BaseConfig.dateFormat / use24HourFormat (same UserDefaults keys in every app),
/// with Fossify's Long.formatDate()/formatTime() helpers.
@Observable
public final class DateTimeFormat {
    public static let shared = DateTimeFormat()

    /// DATE_FORMAT_ONE ... DATE_FORMAT_EIGHT (Android and Unicode patterns agree for these).
    public static let dateFormats = ["dd.MM.yyyy", "dd/MM/yyyy", "MM/dd/yyyy", "yyyy-MM-dd",
                                     "d MMMM yyyy", "MMMM d yyyy", "MM-dd-yyyy", "dd-MM-yyyy"]

    @ObservationIgnored private let d = UserDefaults.standard

    public var dateFormat: String { didSet { d.set(dateFormat, forKey: "date_format") } }
    public var use24HourFormat: Bool { didSet { d.set(use24HourFormat, forKey: "use_24_hour_format") } }

    private init() {
        dateFormat = d.string(forKey: "date_format") ?? DateTimeFormat.defaultDateFormat()
        use24HourFormat = d.object(forKey: "use_24_hour_format") as? Bool ?? DateTimeFormat.systemUses24Hour()
    }

    /// TIME_FORMAT_24 / TIME_FORMAT_12.
    public var timeFormat: String { use24HourFormat ? "HH:mm" : "hh:mm a" }

    /// Long.formatDate(): "<date format>, <time format>".
    public func format(_ date: Date, dateFormat: String? = nil, timeFormat: String? = nil) -> String {
        Self.format(date, "\(dateFormat ?? self.dateFormat), \(timeFormat ?? self.timeFormat)")
    }

    /// Long.formatTime().
    public func formatTime(_ date: Date) -> String { Self.format(date, timeFormat) }

    public static func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f.string(from: date)
    }

    /// getDefaultDateFormat(): match the locale's short date pattern, else "d MMMM yyyy".
    private static func defaultDateFormat() -> String {
        let pattern = (DateFormatter.dateFormat(fromTemplate: "yMd", options: 0, locale: .current) ?? "")
            .lowercased().replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "yyyy", with: "y").replacingOccurrences(of: "yy", with: "y")
        switch pattern {
        case "d.m.y", "dd.mm.y": return dateFormats[0]
        case "dd/mm/y", "d/m/y": return dateFormats[1]
        case "mm/dd/y", "m/d/y": return dateFormats[2]
        case "y-mm-dd", "y-m-d": return dateFormats[3]
        case "mm-dd-y": return dateFormats[6]
        case "dd-mm-y": return dateFormats[7]
        default: return dateFormats[4]
        }
    }

    private static func systemUses24Hour() -> Bool {
        !(DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")
    }
}

/// ChangeDateTimeFormatDialog.
public struct ChangeDateTimeFormatDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    private let config = DateTimeFormat.shared
    private let onChange: () -> Void
    @State private var selected: String
    @State private var use24: Bool

    /// February 15, 2023.
    private static let sample = Date(timeIntervalSince1970: 1_676_419_200)

    public init(onChange: @escaping () -> Void = {}) {
        self.onChange = onChange
        _selected = State(initialValue: DateTimeFormat.shared.dateFormat)
        _use24 = State(initialValue: DateTimeFormat.shared.use24HourFormat)
    }

    public var body: some View {
        DialogFrame(title: nil) {
            ForEach(DateTimeFormat.dateFormats, id: \.self) { format in
                Button { selected = format } label: {
                    RadioRow(title: DateTimeFormat.format(Self.sample, format), on: format == selected)
                }
                .buttonStyle(.plain)
            }
            Divider().overlay(palette.divider).padding(.vertical, 8)
            CheckRow(title: "Use 24-hour time format", on: $use24)
            DialogButtons {
                config.dateFormat = selected
                config.use24HourFormat = use24
                onChange()
                dismiss()
            }
        }
    }
}

extension Int {
    /// Int.getFormattedDuration(): seconds -> "mm:ss" / "hh:mm:ss".
    public func formattedDuration(forceShowHours: Bool = false) -> String {
        let hours = self / 3600, minutes = self % 3600 / 60, seconds = self % 60
        var s = ""
        if self >= 3600 {
            s = String(format: "%02d:", hours)
        } else if forceShowHours {
            s = "0:"
        }
        return s + String(format: "%02d:%02d", minutes, seconds)
    }
}

extension Int64 {
    /// Long.formatSize() (FileSizeFormatter, decimal units unless use_binary_storage_units).
    public var formattedSize: String {
        guard self > 0 else { return "0 B" }
        let binary = UserDefaults.standard.bool(forKey: "use_binary_storage_units")
        let divisor = binary ? 1024.0 : 1000.0
        let units = binary ? ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB"] : ["B", "kB", "MB", "GB", "TB", "PB", "EB"]
        let groups = Swift.min(Int(log10(Double(self)) / log10(divisor)), units.count - 1)
        let value = Double(self) / pow(divisor, Double(groups))
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: value)) ?? "\(value)") \(units[groups])"
    }
}
