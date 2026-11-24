import Foundation

extension DateTimeFormat {
    /// Long.formatDateOrTime(): the time for today (unless `hideTodaysDate` is false), else the
    /// configured date format without the current year (unless `showCurrentYear`), plus the time
    /// unless `hideTimeOnOtherDays`.
    public func formatDateOrTime(_ date: Date, hideTimeOnOtherDays: Bool, showCurrentYear: Bool, hideTodaysDate: Bool = true) -> String {
        let cal = Calendar.current
        if hideTodaysDate && cal.isDateInToday(date) {
            return formatTime(date)
        }
        var format = dateFormat
        if !showCurrentYear && cal.component(.year, from: date) == cal.component(.year, from: Date()) {
            format = format.replacingOccurrences(of: "y", with: "")
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if !hideTimeOnOtherDays {
            format += ", \(timeFormat)"
        }
        return Self.format(date, format)
    }
}

extension DurationStrings {
    /// formatSecondsToShortTimeString(): "1h 5m 3s".
    public static func shortTime(_ totalSeconds: Int) -> String {
        let days = totalSeconds / daySeconds
        let hours = (totalSeconds % daySeconds) / hourSeconds
        let minutes = (totalSeconds % hourSeconds) / minuteSeconds
        let seconds = totalSeconds % minuteSeconds
        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if seconds > 0 { parts.append("\(seconds)s") }
        return parts.joined(separator: " ")
    }
}
