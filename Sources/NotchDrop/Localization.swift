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
    static var showInFinder: String          { s("在 Finder 中显示", "Show in Finder") }
    static var removeFile: String            { s("移除", "Remove") }
    static var clearAll: String              { s("清空", "Clear all") }
    static var cutToClipboard: String        { s("剪切到剪贴板", "Cut to Clipboard") }
    static var fileMovedNotification: String { s("文件已剪切到剪贴板\n可在 Finder 中粘贴", "File cut to clipboard\nPaste in Finder to place it") }

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

    // ── Trigger Zone Settings ──
    static var triggerSettings: String       { s("触发区域", "Trigger Zones") }
    static var leftTriggerWidth: String      { s("左侧触发区宽度:", "Left trigger width:") }
    static var rightTriggerWidth: String     { s("右侧触发区宽度:", "Right trigger width:") }
    static var triggerHeight: String         { s("触发区高度:", "Trigger height:") }
    static var triggerRangeHint: String      { s("调整屏幕顶部左右两侧触发区域的大小\n中间区域（刘海附近）不会响应鼠标", "Adjust the trigger zones on the left and right\nThe center area (near notch) won't respond") }
    static var triggerLeftDesc: String       { s("从屏幕左边缘开始的宽度", "Width from left edge") }
    static var triggerRightDesc: String      { s("从屏幕右边缘开始的宽度", "Width from right edge") }
}
