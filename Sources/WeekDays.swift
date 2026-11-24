import Foundation
import Observation

/// BaseConfig.firstDayOfWeek plus Fossify's weekday bit helpers (MONDAY_BIT ... SUNDAY_BIT,
/// week_days / week_days_short / week_day_letters, getSelectedDaysString, rotateWeekdays).
/// Day indexes are 0 = Monday ... 6 = Sunday, like the Android string arrays.
@Observable
public final class WeekDays {
    public static let shared = WeekDays()

    public static let mondayBit = 1
    public static let tuesdayBit = 2
    public static let wednesdayBit = 4
    public static let thursdayBit = 8
    public static let fridayBit = 16
    public static let saturdayBit = 32
    public static let sundayBit = 64
    public static let everyDayBit = 127
    public static let weekDaysBit = 31
    public static let weekendsBit = 96

    public static let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    public static let shortNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    public static let letters = ["M", "T", "W", "T", "F", "S", "S"]

    @ObservationIgnored private let d = UserDefaults.standard

    /// ISO 8601 numbering: Monday = 1 ... Sunday = 7.
    public var firstDayOfWeek: Int { didSet { d.set(firstDayOfWeek, forKey: "first_day_of_week") } }

    private init() {
        let system = Calendar.current.firstWeekday == 1 ? 7 : Calendar.current.firstWeekday - 1
        firstDayOfWeek = d.object(forKey: "first_day_of_week") as? Int ?? system
    }

    /// rotateWeekdays(): day indexes (0 = Monday) starting at the first day of the week.
    public func rotated(_ days: [Int] = Array(0..<7)) -> [Int] {
        guard !days.isEmpty else { return days }
        let shift = (firstDayOfWeek - 1) % days.count
        return Array(days[shift...] + days[..<shift])
    }

    /// getSelectedDaysString(): "Mon, Tue, Wed" in week order.
    public func selectedDaysString(_ bitMask: Int) -> String {
        rotated().filter { bitMask & (1 << $0) != 0 }.map { WeekDays.shortNames[$0] }.joined(separator: ", ")
    }

    /// Index 0 = Monday for a Foundation weekday (1 = Sunday ... 7 = Saturday).
    public static func index(ofCalendarWeekday weekday: Int) -> Int { (weekday + 5) % 7 }

    /// Foundation weekday (1 = Sunday) for a day index (0 = Monday).
    public static func calendarWeekday(ofIndex index: Int) -> Int { (index + 1) % 7 + 1 }
}
