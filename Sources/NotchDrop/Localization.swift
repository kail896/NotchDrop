import Foundation

// MARK: - Language

enum Language: String, Codable, CaseIterable {
    case english = "en"
    case chinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "简体中文"
        }
    }
}

// MARK: - Localized Strings

/// Type-safe localized string access.
/// Uses **computed** properties so every access re-reads the current language.
enum L {
    private static var isChinese: Bool {
        let raw = UserDefaults.standard.string(forKey: "language") ?? ""
        return Language(rawValue: raw) ?? (Locale.current.language.languageCode?.identifier == "zh" ? .chinese : .english) == .chinese
    }

    private static func s(_ zh: String, _ en: String) -> String {
        isChinese ? zh : en
    }

    // ── General ──
    static var appName: String               { "NotchDrop" }
    static var settings: String              { s("设置…", "Settings…") }
    static var quit: String                  { s("退出 NotchDrop", "Quit NotchDrop") }
    static var togglePanel: String           { s("切换面板", "Toggle Notch Panel") }

    // ── Notch Panel ──
    static var dropFilesHere: String         { s("将文件拖放到此处", "Drop files here") }
    static var dragHint: String              { s("从任意位置拖入文件\n临时存放", "Drag files from anywhere\nto temporarily store them") }
    static var files: String                 { s("个文件", " files") }

    // ── Settings Window ──
    static var settingsTitle: String         { s("NotchDrop 设置", "NotchDrop Settings") }
    static var generalTab: String            { s("通用", "General") }
    static var languageLabel: String         { s("语言:", "Language:") }
    static var autoHideDelay: String         { s("自动隐藏延迟:", "Auto-hide delay:") }
    static var autoHint: String              { s("鼠标离开后面板等待多久才自动隐藏", "How long before the panel hides after the mouse leaves") }
    static var launchAtLogin: String         { s("开机启动", "Launch at login") }
    static var launchHint: String            { s("登录时自动启动 NotchDrop", "Automatically start NotchDrop at login") }
    static var rememberFiles: String         { s("记忆文件", "Remember files") }
    static var rememberHint: String          { s("退出后保留面板中的文件，下次启动恢复", "Keep files after quitting and relaunching") }
}
