import Foundation
import SwiftUI
import ServiceManagement

// MARK: - App Settings

/// Persisted settings for NotchDrop.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Key: String {
        case autoHideDelay, launchAtLogin, rememberFiles, savedFilePaths, language
    }

    @Published var autoHideDelay: Double {
        didSet { save(autoHideDelay, forKey: .autoHideDelay) }
    }
    @Published var launchAtLogin: Bool {
        didSet { save(launchAtLogin, forKey: .launchAtLogin); applyLaunchAtLogin() }
    }
    @Published var rememberFiles: Bool {
        didSet { save(rememberFiles, forKey: .rememberFiles) }
    }
    @Published var savedFilePaths: [String] {
        didSet { save(savedFilePaths, forKey: .savedFilePaths) }
    }
    @Published var language: Language {
        didSet {
            save(language.rawValue, forKey: .language)
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    private init() {
        let ud = UserDefaults.standard
        autoHideDelay  = ud.object(forKey: Key.autoHideDelay.rawValue) as? Double ?? 5.0
        launchAtLogin  = ud.bool(forKey: Key.launchAtLogin.rawValue)
        rememberFiles  = ud.bool(forKey: Key.rememberFiles.rawValue)
        savedFilePaths = ud.stringArray(forKey: Key.savedFilePaths.rawValue) ?? []
        let langRaw    = ud.string(forKey: Key.language.rawValue) ?? ""
        language       = Language(rawValue: langRaw) ?? (Locale.current.language.languageCode?.identifier == "zh" ? .chinese : .english)
    }

    private func save<T>(_ value: T, forKey key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private func applyLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("NotchDrop: Failed toggle launch-at-login: \(error.localizedDescription)")
            }
        }
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}
