import Foundation
import SwiftUI

/// Helpers behind Fossify's automatic backups (getNextAutoBackupTime / backup filename patterns).
public enum AutoBackup {
    /// getPreviousAutoBackupTime(): the 6 AM backup slot that most recently passed. iOS has no
    /// alarms for these apps, so they back up when opened after this time if the last backup is older.
    public static func previousBackupTime(now: Date = Date()) -> Date {
        let cal = Calendar.current
        let six = cal.date(bySettingHour: 6, minute: 0, second: 0, of: now)!
        return now >= six ? six : cal.date(byAdding: .day, value: -1, to: six)!
    }

    /// Expands the %Y %M %D %h %m %s filename patterns (DateTimePatternInfoDialog).
    public static func filename(_ pattern: String, date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func two(_ v: Int?) -> String { String(format: "%02d", v ?? 0) }
        return pattern
            .replacingOccurrences(of: "%Y", with: String(c.year ?? 0))
            .replacingOccurrences(of: "%M", with: two(c.month))
            .replacingOccurrences(of: "%D", with: two(c.day))
            .replacingOccurrences(of: "%h", with: two(c.hour))
            .replacingOccurrences(of: "%m", with: two(c.minute))
            .replacingOccurrences(of: "%s", with: two(c.second))
    }

    /// Context.getCurrentFormattedDateTime(): "yyyyMMdd_HHmmss".
    public static func currentFormattedDateTime(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: date)
    }
}

/// DateTimePatternInfoDialog.
public struct DateTimePatternInfoDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        DialogFrame(title: nil) {
            Text("You can use the following patterns to name your file automatically:\n\n%Y - year\n%M - month\n%D - day\n%h - hour\n%m - minute\n%s - second")
                .font(.system(size: 16))
                .foregroundStyle(palette.textColor)
            HStack {
                Spacer()
                Button("OK") { dismiss() }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.primaryColor)
            }
            .padding(.top, 16)
        }
    }
}
