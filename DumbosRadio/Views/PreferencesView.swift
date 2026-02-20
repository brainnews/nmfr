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
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            VisualizerPrefsView()
                .tabItem { Label("Visualizer", systemImage: "waveform") }

            LibraryPrefsView()
                .environmentObject(persistence)
                .tabItem { Label("Library", systemImage: "books.vertical") }
        }
        .frame(width: 400, height: 300)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                shortcutRow("Play / Stop", keys: "⌘⇧P")
                shortcutRow("Preset 1–6", keys: "1 – 6")
                shortcutRow("Mute", keys: "⌘⇧M")
                shortcutRow("Toggle Visualizer", keys: "⌘⇧V")
                shortcutRow("Open Preferences", keys: "⌘,")
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Preset keys 1–6 work when the main window is focused.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    private func shortcutRow(_ label: String, keys: String) -> some View {
        GridRow {
            Text(label)
                .font(.system(size: 12))
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
