import Foundation

// Snapshots the apps publish into the launcher's app group (WidgetBridge.save) for the home-screen
// widget extension (fossify-ios/widgets-ios). Plain Codable values: the extension never touches
// an app's stores, it only draws these.

/// WidgetKit kinds of the extension's widgets (also the reload keys).
public enum WidgetKinds {
    public static let calculator = "org.fossify.widgets.calculator"
    public static let calendarDate = "org.fossify.widgets.calendar.date"
    public static let calendarList = "org.fossify.widgets.calendar.list"
    public static let calendarMonthly = "org.fossify.widgets.calendar.monthly"
    public static let clockDigital = "org.fossify.widgets.clock.digital"
    public static let clockAnalogue = "org.fossify.widgets.clock.analogue"
    public static let galleryFolder = "org.fossify.widgets.gallery.folder"
    public static let musicPlayer = "org.fossify.widgets.musicplayer"
    public static let notes = "org.fossify.widgets.notes"
    public static let voiceRecorder = "org.fossify.widgets.voicerecorder"

    public static let calendar = [calendarDate, calendarList, calendarMonthly]
    public static let clock = [clockDigital, clockAnalogue]
}

/// App ids in widget URLs (`fossify://open/<app>`), one per BundledApp of the launcher.
public enum WidgetApps {
    public static let calculator = "calculator"
    public static let calendar = "calendar"
    public static let clock = "clock"
    public static let gallery = "gallery"
    public static let musicPlayer = "musicplayer"
    public static let notes = "notes"
    public static let voiceRecorder = "voicerecorder"
}

/// BaseConfig's colors, for the "Theme" color choice.
public struct WidgetTheme: Codable, Equatable {
    public var primary: UInt32
    public var text: UInt32
    public var background: UInt32

    public init(primary: UInt32, text: UInt32, background: UInt32) {
        self.primary = primary
        self.text = text
        self.background = background
    }

    public static let `default` = WidgetTheme(primary: 0xFF10_6D1F, text: 0xFFEE_EEEE, background: 0xFF25_2525)
}

// MARK: Calculator

/// The widget calculator kept in the app group (MyWidgetProvider's in-memory CalculatorImpl).
public struct CalculatorWidgetSnapshot: Codable, Equatable {
    public var formula: String
    public var result: String
    /// CalculatorImpl state as JSON (calculator-ios CalculatorState).
    public var state: String
    public var decimalSeparator: String
    /// Last toast (e.g. division by zero), shown until the next key.
    public var message: String?

    public init(formula: String = "", result: String = "0", state: String = "", decimalSeparator: String = ".", message: String? = nil) {
        self.formula = formula
        self.result = result
        self.state = state
        self.decimalSeparator = decimalSeparator
        self.message = message
    }
}

// MARK: Calendar

public struct CalendarWidgetSnapshot: Codable, Equatable {
    /// One event occurrence for the list widget (sorted like getEventListItems).
    public struct ListEvent: Codable, Equatable {
        public var key: String
        public var title: String
        /// Time line(s): "All-day" / "7:00 - 7:30 (Tue, Mar 3)" + "\n" + description.
        public var time: String
        public var startTS: Int64
        public var endTS: Int64
        public var color: UInt32
        public var isAllDay: Bool
        public var isTask: Bool
        public var isTaskCompleted: Bool
        public var strike: Bool
        /// Day code (yyyyMMdd), day section title and month section label.
        public var dayCode: String
        public var dayTitle: String
        public var monthLabel: String
        public var eventID: Int64

        public init(key: String, title: String, time: String, startTS: Int64, endTS: Int64, color: UInt32, isAllDay: Bool,
                    isTask: Bool, isTaskCompleted: Bool, strike: Bool, dayCode: String, dayTitle: String, monthLabel: String, eventID: Int64) {
            self.key = key; self.title = title; self.time = time; self.startTS = startTS; self.endTS = endTS; self.color = color
            self.isAllDay = isAllDay; self.isTask = isTask; self.isTaskCompleted = isTaskCompleted; self.strike = strike
            self.dayCode = dayCode; self.dayTitle = dayTitle; self.monthLabel = monthLabel; self.eventID = eventID
        }
    }

    /// An event drawn in the monthly grid.
    public struct MonthEvent: Codable, Equatable {
        public var title: String
        public var color: UInt32
        public var endTS: Int64
        public var isTask: Bool
        public var isTaskCompleted: Bool
        public var strike: Bool

        public init(title: String, color: UInt32, endTS: Int64, isTask: Bool, isTaskCompleted: Bool, strike: Bool) {
            self.title = title; self.color = color; self.endTS = endTS; self.isTask = isTask
            self.isTaskCompleted = isTaskCompleted; self.strike = strike
        }
    }

    public struct Day: Codable, Equatable {
        public var value: Int
        public var code: String
        public var isThisMonth: Bool
        public var isWeekend: Bool
        public var weekOfYear: Int
        /// Event slots (indices into Month.events, -1 = empty), the same slot across a week for
        /// multi-day events (MyWidgetMonthlyProvider's day slot lists).
        public var slots: [Int]

        public init(value: Int, code: String, isThisMonth: Bool, isWeekend: Bool, weekOfYear: Int, slots: [Int]) {
            self.value = value; self.code = code; self.isThisMonth = isThisMonth; self.isWeekend = isWeekend
            self.weekOfYear = weekOfYear; self.slots = slots
        }
    }

    public struct Month: Codable, Equatable {
        /// yyyyMM
        public var code: String
        public var title: String
        public var days: [Day]
        public var events: [MonthEvent]

        public init(code: String, title: String, days: [Day], events: [MonthEvent]) {
            self.code = code; self.title = title; self.days = days; self.events = events
        }
    }

    public var listEvents: [ListEvent]
    public var months: [Month]
    public var weekDayLetters: [String]
    public var fontSize: Double
    public var showWeekNumbers: Bool
    public var showGrid: Bool
    public var highlightWeekends: Bool
    public var weekendColor: UInt32
    public var dimPastEvents: Bool
    public var dimCompletedTasks: Bool
    /// Config.displayPastEvents, minutes.
    public var displayPastMinutes: Int
    public var generated: Date

    public init(listEvents: [ListEvent], months: [Month], weekDayLetters: [String], fontSize: Double, showWeekNumbers: Bool,
                showGrid: Bool, highlightWeekends: Bool, weekendColor: UInt32, dimPastEvents: Bool, dimCompletedTasks: Bool,
                displayPastMinutes: Int, generated: Date) {
        self.listEvents = listEvents; self.months = months; self.weekDayLetters = weekDayLetters; self.fontSize = fontSize
        self.showWeekNumbers = showWeekNumbers; self.showGrid = showGrid; self.highlightWeekends = highlightWeekends
        self.weekendColor = weekendColor; self.dimPastEvents = dimPastEvents; self.dimCompletedTasks = dimCompletedTasks
        self.displayPastMinutes = displayPastMinutes; self.generated = generated
    }
}

// MARK: Clock

public struct ClockWidgetSnapshot: Codable, Equatable {
    /// getClosestEnabledAlarmString() ("Tue 07:00"), empty without alarms.
    public var nextAlarm: String
    public var nextAlarmDate: Date?
    public var use24Hour: Bool

    public init(nextAlarm: String, nextAlarmDate: Date?, use24Hour: Bool) {
        self.nextAlarm = nextAlarm
        self.nextAlarmDate = nextAlarmDate
        self.use24Hour = use24Hour
    }
}

// MARK: Gallery

public struct GalleryWidgetSnapshot: Codable, Equatable {
    public struct Folder: Codable, Equatable {
        public var path: String
        public var name: String
        /// Cover thumbnail, relative to WidgetBridge.fileURL (nil while missing).
        public var thumbnail: String?
        public var count: Int

        public init(path: String, name: String, thumbnail: String?, count: Int) {
            self.path = path; self.name = name; self.thumbnail = thumbnail; self.count = count
        }
    }

    public var folders: [Folder]
    public var cropThumbnails: Bool

    public init(folders: [Folder], cropThumbnails: Bool) {
        self.folders = folders
        self.cropThumbnails = cropThumbnails
    }
}

// MARK: Music Player

public struct MusicWidgetSnapshot: Codable, Equatable {
    public var hasTrack: Bool
    public var title: String
    public var artist: String
    public var isPlaying: Bool
    /// Artwork thumbnail relative to WidgetBridge.fileURL.
    public var artwork: String?

    public init(hasTrack: Bool, title: String, artist: String, isPlaying: Bool, artwork: String?) {
        self.hasTrack = hasTrack; self.title = title; self.artist = artist; self.isPlaying = isPlaying; self.artwork = artwork
    }
}

// MARK: Notes

public struct NotesWidgetSnapshot: Codable, Equatable {
    public struct Note: Codable, Equatable {
        public var id: Int64
        public var title: String
        public var isChecklist: Bool
        /// Protected notes publish no content (the widget can't ask for the password).
        public var isLocked: Bool
        public var text: String
        /// Checklist items in widget order (WidgetAdapter).
        public var tasks: [Item]

        public init(id: Int64, title: String, isChecklist: Bool, isLocked: Bool, text: String, tasks: [Item]) {
            self.id = id; self.title = title; self.isChecklist = isChecklist; self.isLocked = isLocked; self.text = text; self.tasks = tasks
        }
    }

    public struct Item: Codable, Equatable {
        public var title: String
        public var isDone: Bool

        public init(title: String, isDone: Bool) {
            self.title = title
            self.isDone = isDone
        }
    }

    public var notes: [Note]
    /// Config.gravity: 0 start, 1 center, 2 end.
    public var gravity: Int
    public var fontSize: Double
    public var monospaced: Bool

    public init(notes: [Note], gravity: Int, fontSize: Double, monospaced: Bool) {
        self.notes = notes; self.gravity = gravity; self.fontSize = fontSize; self.monospaced = monospaced
    }
}

// MARK: Voice Recorder

public struct RecorderWidgetSnapshot: Codable, Equatable {
    public var isRecording: Bool
    public var isPaused: Bool

    public init(isRecording: Bool, isPaused: Bool) {
        self.isRecording = isRecording
        self.isPaused = isPaused
    }
}
