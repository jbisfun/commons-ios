import Foundation

/// Fossify's duration texts: formatSecondsToTimeString, formatMinutesToTimeString,
/// getFormattedSeconds / getFormattedMinutes (with the commons plurals).
public enum DurationStrings {
    public static let minuteSeconds = 60
    public static let hourSeconds = 3600
    public static let daySeconds = 86400
    public static let weekSeconds = 604800
    public static let monthSeconds = 2592000
    public static let yearSeconds = 31536000

    static func plural(_ n: Int, _ unit: String) -> String { "\(n) \(unit)\(n == 1 ? "" : "s")" }

    /// formatSecondsToTimeString(): "1 hour, 5 minutes".
    public static func seconds(_ totalSeconds: Int) -> String {
        let days = totalSeconds / daySeconds
        let hours = (totalSeconds % daySeconds) / hourSeconds
        let minutes = (totalSeconds % hourSeconds) / minuteSeconds
        let seconds = totalSeconds % minuteSeconds
        var parts: [String] = []
        if days > 0 { parts.append(plural(days, "day")) }
        if hours > 0 { parts.append(plural(hours, "hour")) }
        if minutes > 0 { parts.append(plural(minutes, "minute")) }
        if seconds > 0 { parts.append(plural(seconds, "second")) }
        return parts.isEmpty ? plural(0, "minute") : parts.joined(separator: ", ")
    }

    /// formatMinutesToTimeString().
    public static func minutes(_ totalMinutes: Int) -> String { seconds(totalMinutes * 60) }

    /// getFormattedSeconds(): reminder / snooze option titles ("5 minutes before", "At start", ...).
    public static func formatted(seconds: Int, showBefore: Bool = true) -> String {
        let suffix = showBefore ? " before" : ""
        switch seconds {
        case -1: return "No reminder"
        case 0: return "At start"
        case let s where s < 0 && s > -daySeconds:
            let minutes = -s / 60
            return String(format: "During the day at %02d:%02d", minutes / 60, minutes % 60)
        case let s where s % yearSeconds == 0: return plural(s / yearSeconds, "year") + suffix
        case let s where s % monthSeconds == 0: return plural(s / monthSeconds, "month") + suffix
        case let s where s % weekSeconds == 0: return plural(s / weekSeconds, "week") + suffix
        case let s where s % daySeconds == 0: return plural(s / daySeconds, "day") + suffix
        case let s where s % hourSeconds == 0: return plural(s / hourSeconds, "hour") + suffix
        case let s where s % minuteSeconds == 0: return plural(s / minuteSeconds, "minute") + suffix
        default: return plural(seconds, "second") + suffix
        }
    }

    /// getFormattedMinutes().
    public static func formatted(minutes: Int, showBefore: Bool = true) -> String {
        formatted(seconds: minutes == -1 ? -1 : minutes * 60, showBefore: showBefore)
    }
}
