import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @AppStorage("language") private var _language = ""

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem {
                    Label(L.generalTab, systemImage: "gearshape")
                }
        }
        .frame(width: 480, height: 440)
    }
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // ── Language ──
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.languageLabel)
                        .font(.system(size: 13, weight: .medium))

                    Picker("", selection: $settings.language) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }

                Divider()

                // ── Auto-hide delay ──
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L.autoHideDelay)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(String(format: "%.1f s", settings.autoHideDelay))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(minWidth: 40, alignment: .trailing)
                    }
                    Slider(value: $settings.autoHideDelay, in: 1.0...10.0, step: 0.5)
                    Text(L.autoHint)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // ── Launch at login ──
                Toggle(isOn: $settings.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.launchAtLogin)
                            .font(.system(size: 13, weight: .medium))
                        Text(L.launchHint)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // ── Remember files ──
                Toggle(isOn: $settings.rememberFiles) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.rememberFiles)
                            .font(.system(size: 13, weight: .medium))
                        Text(L.rememberHint)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.automatic)
    }
}
