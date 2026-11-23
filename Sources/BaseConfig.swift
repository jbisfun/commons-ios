import Observation
import SwiftUI
import UIKit

/// Port of Fossify Commons' BaseConfig: the settings every Fossify app shares
/// (SharedPreferences -> UserDefaults, same keys in every app).
@Observable
public final class BaseConfig {
    public static let shared = BaseConfig()

    @ObservationIgnored private let d = UserDefaults.standard

    public var theme: ThemeKind { didSet { d.set(theme.rawValue, forKey: "theme") } }
    public var customTextColor: UInt32 { didSet { d.set(Int(customTextColor), forKey: "text_color") } }
    public var customBackgroundColor: UInt32 { didSet { d.set(Int(customBackgroundColor), forKey: "background_color") } }
    public var customPrimaryColor: UInt32 { didSet { d.set(Int(customPrimaryColor), forKey: "primary_color") } }
    public var fontSize: FontSize { didSet { d.set(fontSize.rawValue, forKey: "font_size") } }

    private init() {
        theme = ThemeKind(rawValue: d.integer(forKey: "theme")) ?? .system
        customTextColor = UInt32(truncatingIfNeeded: d.object(forKey: "text_color") as? Int ?? 0xFF2D2D2D)
        customBackgroundColor = UInt32(truncatingIfNeeded: d.object(forKey: "background_color") as? Int ?? 0xFFFFFFFF)
        customPrimaryColor = UInt32(truncatingIfNeeded: d.object(forKey: "primary_color") as? Int ?? 0xFF106D1F)
        fontSize = FontSize(rawValue: d.object(forKey: "font_size") as? Int ?? FontSize.large.rawValue) ?? .large
    }
}

public enum FontSize: Int, CaseIterable, Sendable {
    case small = 0, medium, large, extraLarge

    public var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra large"
        }
    }

    /// Context.getTextSize(): smaller/normal/big/extra_big text sizes.
    public var points: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 18
        case .extraLarge: return 22
        }
    }
}
