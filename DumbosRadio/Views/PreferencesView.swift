import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @EnvironmentObject var persistence: PersistenceManager

    var body: some View {
        TabView {
            GeneralPrefsView()
                .environmentObject(persistence)
                .tabItem { Label("General", systemImage: "gear") }

            ShortcutsPrefsView()
                .environmentObject(persistence)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            VisualizerPrefsView()
                .tabItem { Label("Visualizer", systemImage: "waveform") }

            LibraryPrefsView()
                .environmentObject(persistence)
                .tabItem { Label("Library", systemImage: "books.vertical") }
        }
        .frame(width: 400, height: 370)
        .padding()
    }
}

struct GeneralPrefsView: View {
    @EnvironmentObject var persistence: PersistenceManager

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { persistence.launchAtLogin },
                    set: { v in
                        persistence.launchAtLogin = v
                        applyLaunchAtLogin(v)
                    }
                ))

                Toggle("Start in Menu Bar Mode", isOn: $persistence.menuBarMode)
            }

            Section("Notifications") {
                Toggle("Show notifications when station changes", isOn: $persistence.notificationsEnabled)
                    .onChange(of: persistence.notificationsEnabled) { enabled in
                        if enabled { NotificationManager.requestPermission() }
                    }
            }

            Section("Playback") {
                VStack(alignment: .leading) {
                    Text("Default Volume: \(Int(persistence.volume * 100))%")
                        .font(.system(size: 11))
                    Slider(value: $persistence.volume, in: 0...1)
                        .controlSize(.small)
                }
            }

            Section("Support") {
                HStack {
                    Spacer()
                    KoFiButton()
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }
}

struct ShortcutsPrefsView: View {
    @EnvironmentObject var persistence: PersistenceManager
    @State private var axGranted = GlobalShortcutManager.shared.isAccessibilityGranted

    var body: some View {
        Form {
            Section("Global Shortcut") {
                Toggle("Enable system-wide Play / Stop", isOn: $persistence.globalShortcutsEnabled)

                if persistence.globalShortcutsEnabled {
                    HStack {
                        Text("Shortcut")
                        Spacer()
                        Text("⌃⌥⌘P")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    if axGranted {
                        Label("Accessibility access granted — shortcut active", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 11))
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Accessibility access required", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 11))
                            Button("Open Accessibility Settings…") {
                                GlobalShortcutManager.shared.openAccessibilitySettings()
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section("In-App Shortcuts") {
                shortcutRow("Play / Stop", keys: "⌘⇧P")
                shortcutRow("Mute / Unmute", keys: "⌘⇧M")
                shortcutRow("Toggle Visualizer", keys: "⌘⇧V")
                shortcutRow("Preset 1–6", keys: "⌘⇧1 – 6")
                shortcutRow("Open Preferences", keys: "⌘,")
            }
        }
        .formStyle(.grouped)
        .task {
            // Poll until access is granted (or revoked) while this view is visible
            while !Task.isCancelled {
                axGranted = GlobalShortcutManager.shared.isAccessibilityGranted
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func shortcutRow(_ label: String, keys: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            Text(keys)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

struct VisualizerPrefsView: View {
    @EnvironmentObject var persistence: PersistenceManager

    private var colorBinding: Binding<Color> {
        Binding(
            get: { persistence.visualizerSolidColor.color },
            set: { persistence.visualizerSolidColor = StorableColor($0) }
        )
    }

    var body: some View {
        Form {
            Section("Waveform Color") {
                Picker("Color Mode", selection: $persistence.visualizerColorMode) {
                    Text("Rainbow").tag("rainbow")
                    Text("Solid Color").tag("solid")
                }
                .pickerStyle(.segmented)

                if persistence.visualizerColorMode == "solid" {
                    ColorPicker("Color", selection: colorBinding, supportsOpacity: false)
                }
            }

            Section("Overlay Effects") {
                Toggle("CRT",    isOn: $persistence.visualizerCRTEnabled)
                Toggle("Glitch", isOn: $persistence.visualizerGlitchEnabled)
                Toggle("Pixel",  isOn: $persistence.visualizerPixelatedEnabled)
            }
        }
        .formStyle(.grouped)
    }
}
