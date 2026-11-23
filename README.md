# commons-ios

Shared core of the Fossify iOS ports ([contacts-ios](https://github.com/jbisfun/contacts-ios), [calculator-ios](https://github.com/jbisfun/calculator-ios)), the counterpart of [Fossify Commons](https://github.com/FossifyOrg/Commons). Swift module `FossifyCommons`.

- `BaseConfig`: theme, custom colors, font size (same UserDefaults keys in every app)
- `Theme`: `ThemeKind`, `Palette` (`\.palette` environment), `.fossifyTheme()` for the app root, `.paletteBackground()`
- `Components`: `RadioDialog`, `CheckRow`, `DialogFrame`, `DialogButtons`, `.toast`, `.sectionHeader`, `TopBar`, `IconButton`, `PressedStyle`, `Launcher`, swipe-back with hidden navigation bars
- `Settings`: `SettingsItem`, `SettingsToggle`, `CustomizeColorsView`, `AboutView(app: AppInfo)`
- `Hosting`: `\.closeApp` / `CloseAppButton` for apps running inside [launcher-ios](https://github.com/jbisfun/launcher-ios)

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
