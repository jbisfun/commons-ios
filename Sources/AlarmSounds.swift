import AVFoundation
import AudioToolbox
import Observation
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

/// AlarmSound model (id, title, uri). `uri` is "default" for the system sound,
/// SILENT ("silent") for no sound, or a file name in Library/Sounds for the
/// user's own sounds (where notifications and AlarmKit can play them too).
public struct AlarmSound: Codable, Hashable, Sendable {
    public var id: Int
    public var title: String
    public var uri: String

    public init(id: Int, title: String, uri: String) {
        self.id = id
        self.title = title
        self.uri = uri
    }

    public static let silentURI = "silent"
    public static let defaultURI = "default"
    /// getDefaultAlarmSound().
    public static let defaultSound = AlarmSound(id: 0, title: "Default", uri: defaultURI)
    public static let silent = AlarmSound(id: 1, title: "No sound", uri: silentURI)

    public var isSilent: Bool { uri == AlarmSound.silentURI }

    /// Library/Sounds, the folder UNNotificationSound(named:) looks in.
    public static var soundsDirectory: URL {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: lib, withIntermediateDirectories: true)
        return lib
    }

    /// The playable file of a user sound, nil for the default / silent / missing ones.
    public var fileURL: URL? {
        guard uri != AlarmSound.defaultURI, !isSilent, !uri.contains("/") || uri.hasPrefix("/") else { return nil }
        let url = uri.hasPrefix("/") ? URL(fileURLWithPath: uri) : AlarmSound.soundsDirectory.appendingPathComponent(uri)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Sound for a local notification (custom sounds are cut to 30 s on import).
    public var notificationSound: UNNotificationSound? {
        if isSilent { return nil }
        if let url = fileURL, url.deletingLastPathComponent().standardizedFileURL == AlarmSound.soundsDirectory.standardizedFileURL {
            return UNNotificationSound(named: UNNotificationSoundName(url.lastPathComponent))
        }
        return .default
    }
}

/// BaseConfig's alarm related settings shared by the clock and calendar apps.
@Observable
public final class ReminderConfig {
    public static let shared = ReminderConfig()

    @ObservationIgnored private let d = UserDefaults.standard

    /// Minutes.
    public var snoozeTime: Int { didSet { d.set(snoozeTime, forKey: "snooze_delay") } }
    public var useSameSnooze: Bool { didSet { d.set(useSameSnooze, forKey: "use_same_snooze") } }
    public var wasAlarmWarningShown: Bool { didSet { d.set(wasAlarmWarningShown, forKey: "was_alarm_warning_shown") } }
    public var yourAlarmSounds: [AlarmSound] {
        didSet { d.set(String(data: (try? JSONEncoder().encode(yourAlarmSounds)) ?? Data(), encoding: .utf8), forKey: "your_alarm_sounds") }
    }

    private init() {
        snoozeTime = d.object(forKey: "snooze_delay") as? Int ?? 10
        useSameSnooze = d.object(forKey: "use_same_snooze") as? Bool ?? true
        wasAlarmWarningShown = d.bool(forKey: "was_alarm_warning_shown")
        yourAlarmSounds = d.string(forKey: "your_alarm_sounds").flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode([AlarmSound].self, from: $0) } ?? []
    }

    /// storeNewYourAlarmSound(): copies the picked audio into Library/Sounds as a
    /// notification-compatible .caf (linear PCM, at most 30 seconds).
    public func addSound(from source: URL) throws -> AlarmSound {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let title = source.deletingPathExtension().lastPathComponent
        let name = "\(UUID().uuidString.prefix(8))-\(title.filter { $0.isLetter || $0.isNumber }.prefix(32)).caf"
        let dst = AlarmSound.soundsDirectory.appendingPathComponent(name)
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount, AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
        ]
        let output = try AVAudioFile(forWriting: dst, settings: settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        var remaining = AVAudioFrameCount(min(Double(input.length), format.sampleRate * 30))
        while remaining > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: min(remaining, 32768)) {
            try input.read(into: buffer, frameCount: buffer.frameCapacity)
            if buffer.frameLength == 0 { break }
            try output.write(from: buffer)
            remaining -= min(remaining, buffer.frameLength)
        }
        let sound = AlarmSound(id: (yourAlarmSounds.map(\.id).max() ?? 1000) + 1, title: title, uri: name)
        yourAlarmSounds.append(sound)
        return sound
    }

    public func removeSound(_ sound: AlarmSound) {
        yourAlarmSounds.removeAll { $0.uri == sound.uri }
        if let url = sound.fileURL { try? FileManager.default.removeItem(at: url) }
    }
}

/// Plays an AlarmSound through the speaker even in silent mode (USAGE_ALARM).
@MainActor
public final class AlarmSoundPlayer {
    private var player: AVAudioPlayer?
    private var systemLoop = false

    public init() {}

    public var volume: Float {
        get { player?.volume ?? 1 }
        set { player?.volume = newValue }
    }

    public func play(_ sound: AlarmSound, loop: Bool, volume: Float = 1) {
        stop()
        guard !sound.isSilent else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let url = sound.fileURL ?? URL(fileURLWithPath: "/System/Library/Audio/UISounds/alarm.caf")
        if let p = try? AVAudioPlayer(contentsOf: url) {
            p.numberOfLoops = loop ? -1 : 0
            p.volume = volume
            p.play()
            player = p
        } else {
            systemLoop = loop
            playSystem()
        }
    }

    private func playSystem() {
        AudioServicesPlaySystemSoundWithCompletion(1005) { [weak self] in
            Task { @MainActor in
                guard let self, self.systemLoop else { return }
                self.playSystem()
            }
        }
    }

    public func stop() {
        systemLoop = false
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// SelectAlarmSoundDialog: "Your sounds" (with "Add a new sound" from Files and
/// long-press to remove) and the system sounds. Tapping a sound previews it.
public struct SelectAlarmSoundDialog: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    let loopAudio: Bool
    let onPick: (AlarmSound) -> Void
    let onDeleted: (AlarmSound) -> Void
    private let config = ReminderConfig.shared
    @State private var selected: String
    @State private var importing = false
    @State private var error: String?
    @State private var player = AlarmSoundPlayer()

    public init(currentURI: String, loopAudio: Bool = true, onPick: @escaping (AlarmSound) -> Void,
                onDeleted: @escaping (AlarmSound) -> Void = { _ in }) {
        self.loopAudio = loopAudio
        self.onPick = onPick
        self.onDeleted = onDeleted
        _selected = State(initialValue: currentURI)
    }

    private var systemSounds: [AlarmSound] { [.defaultSound, .silent] }

    public var body: some View {
        DialogFrame(title: nil) {
            Text("Your sounds").sectionHeader(palette).padding(.horizontal, -16).padding(.top, -24)
            ForEach(config.yourAlarmSounds, id: \.uri) { sound in
                row(sound)
                    .contextMenu {
                        Button(role: .destructive) { remove(sound) } label: { Label("Remove", systemImage: "trash") }
                    }
            }
            Button { importing = true } label: { RadioRow(title: "Add a new sound", on: false) }
                .buttonStyle(.plain)
            Text("System sounds").sectionHeader(palette).padding(.horizontal, -16)
            ForEach(systemSounds, id: \.uri) { row($0) }
            if let error {
                Text(error).font(.system(size: 14)).foregroundStyle(.red).padding(.top, 8)
            }
            DialogButtons {
                let all = config.yourAlarmSounds + systemSounds
                onPick(all.first { $0.uri == selected } ?? .defaultSound)
                dismiss()
            }
        }
        .onDisappear { player.stop() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            do {
                let sound = try config.addSound(from: url)
                selected = sound.uri
                error = nil
            } catch {
                self.error = "An unknown error occurred"
            }
        }
    }

    private func row(_ sound: AlarmSound) -> some View {
        Button {
            selected = sound.uri
            if sound.isSilent { player.stop() } else { player.play(sound, loop: loopAudio) }
        } label: {
            RadioRow(title: sound.title, on: sound.uri == selected)
        }
        .buttonStyle(.plain)
    }

    private func remove(_ sound: AlarmSound) {
        config.removeSound(sound)
        if selected == sound.uri { selected = AlarmSound.defaultURI }
        onDeleted(sound)
    }
}
