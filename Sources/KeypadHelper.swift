import Foundation

/// Fossify Commons' KeypadHelper (PhoneNumberUtils.convertKeypadLettersToDigits + extras):
/// letters -> phone keypad digits (ITU E.161), for T9 contact search on dialpads.
public enum KeypadHelper {
    /// Letters printed under each dialpad key.
    public static let letters: [Character: String] = [
        "2": "ABC", "3": "DEF", "4": "GHI", "5": "JKL", "6": "MNO", "7": "PQRS", "8": "TUV", "9": "WXYZ",
    ]

    /// Russian letters added under the keys on a Russian locale (DialpadActivity.russianCharsMap).
    public static let russianLetters: [Character: String] = [
        "2": "АБВГ", "3": "ДЕЁЖЗ", "4": "ИЙКЛ", "5": "МНОП", "6": "РСТУ", "7": "ФХЦЧ", "8": "ШЩЪЫ", "9": "ЬЭЮЯ",
    ]

    private static let map: [Character: Character] = {
        var m: [Character: Character] = ["ı": "4", "İ": "4", "ł": "5", "Ł": "5"]
        for (digit, chars) in letters {
            for c in chars {
                m[c] = digit
                m[Character(c.lowercased())] = digit
            }
        }
        return m
    }()

    private static let russianMap: [Character: Character] = {
        var m: [Character: Character] = [:]
        for (digit, chars) in russianLetters {
            for c in chars {
                m[c] = digit
                m[Character(c.lowercased())] = digit
            }
        }
        return m
    }()

    /// "1-800-FOSS-411" -> "1-800-3667-411". `russian` also maps Cyrillic letters.
    public static func convertKeypadLettersToDigits(_ input: String, russian: Bool = false) -> String {
        String(input.map { c in map[c] ?? (russian ? russianMap[c] : nil) ?? c })
    }
}
