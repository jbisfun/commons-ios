# commons-ios

Shared core of the Fossify iOS ports ([contacts-ios](https://github.com/jbisfun/contacts-ios), [calculator-ios](https://github.com/jbisfun/calculator-ios)), the counterpart of [Fossify Commons](https://github.com/FossifyOrg/Commons). Swift module `FossifyCommons`.

- `BaseConfig`: theme, custom colors, font size (same UserDefaults keys in every app)
- `Theme`: `ThemeKind`, `Palette` (`\.palette` environment), `.fossifyTheme()` for the app root, `.paletteBackground()`
- `Components`: `RadioDialog`, `CheckRow`, `DialogFrame`, `DialogButtons`, `.toast`, `.sectionHeader`, `TopBar`, `IconButton`, `PressedStyle`, `Launcher`, swipe-back with hidden navigation bars
- `Settings`: `SettingsItem`, `SettingsToggle`, `CustomizeColorsView`, `AboutView(app: AppInfo)`
- `Hosting`: `\.closeApp` / `CloseAppButton` for apps running inside [launcher-ios](https://github.com/jbisfun/launcher-ios)
- `NotificationHub`: the process' single notification delegate and merged category set; apps register handlers instead of setting the center's delegate
- `DateTimeFormat`: date format / 24-hour settings with `format(_:)`, `ChangeDateTimeFormatDialog`, `Int.formattedDuration()`, `Int64.formattedSize`
- `ColorPickerDialog`: the system color picker as a sheet; `OrientationLock` + `OrientationLockDelegate` for "Force portrait mode"
- `SecurityDialog`: pattern / PIN / Face ID tabs, `SecurityConfig`, `.securityCheck($request)`, `.appLock()`, `PasswordProtectionToggle` (needs `NSFaceIDUsageDescription`)
- `StoredProtection`: hidden items / per-folder (`ProtectionKeys.hiddenItems`, `.folder(path)`) or app-specific protections, `StoredProtection.check(_:onSuccess:)`, `StoredProtectionToggle`
- `AutoBackup`: 6 AM backup slot, `%Y%M%D_%h%m%s` filenames, `currentFormattedDateTime()`, `DateTimePatternInfoDialog`
- Files: `FileDirItem` + `Sorting`/`ViewTypes`, `StorageRoot`, `Breadcrumbs`, `FilePickerDialog`, `StoragePickerDialog`, `CreateNewFolderDialog`, `DialogTextField`, `PropertiesDialog`, `RenameItemDialog` / `RenameItemsDialog`, `FileConflictDialog` + `.conflictCheck($check)`
- Alarms: `WeekDays` (first day of week, day bits/names), `DurationStrings`, `PickSecondsDialog` / `CustomIntervalPickerDialog`, `AlarmSound` / `SelectAlarmSoundDialog` / `AlarmSoundPlayer`, `ReminderConfig` (snooze, alarm warning, your sounds)
- `ShareSheet`: `ShareSheet` / `ShareItems` (system share sheet), `Launcher.openWith(_:)` ("Open with" chooser), `Launcher.topViewController()`
- Lists: `ActionModeBar` (selection CAB), `OverflowMenu`, `toggleSelection(_:in:)`, `FastScroller` (RecyclerViewFastScroller handle + bubble)
- `BlockedNumbers`: shared block list with `isBlocked(_:)` (patterns too), `ManageBlockedNumbersView`, `BlockedItemsView` (add/edit, copy, delete, .txt import/export), `ExportTextFileDialog`
- `GlobalSettings`: global "show checkmarks on switches" / "binary storage units" keys, `CheckmarkSwitchStyle` (used by `SettingsToggle`); `DonationView` (DonationActivity: platforms + crypto addresses)
- `LetterFastScroller` (indicatorfastscroll letter column + bubble, `firstIDs`), `KeypadHelper` (T9 letters -> digits, keypad letters), `DateTimeFormat.formatDateOrTime(...)`, `DurationStrings.shortTime(_:)` ("1h 5m 3s")
- `OpenDeviceSettingsDialog(message:)` (denied permission -> "Go to Settings"), `Launcher.openDeviceSettings()`
- `ColorShading`: `UInt32.darkened(by:)` / `lightened(by:)` / `alphaAdjusted(_:)` / `contrastARGB` (Commons' darkenColor / lightenColor / adjustAlpha / getContrastColor)

Apps check it out next to themselves in the pull workspace (`fossify-ios/commons-ios`) and build it as an idl static target:

```yaml
targets:
  - name: FossifyCalculator
    link: [FossifyCommons]
    # ...
  - name: FossifyCommons
    type: static
    dir: ../commons-ios
    min_ios: "17.0"
    sources: [Sources]
    frameworks: [SwiftUI, UIKit, Foundation]
    swift_version: "5.0"
```

GPL-3.0, like Fossify Commons.
