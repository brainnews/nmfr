import SwiftUI

@main
struct NMFRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var persistence = PersistenceManager.shared

    // Lazily create RadioPlayer with shared persistence
    @StateObject private var player: RadioPlayer

    init() {
        let p = PersistenceManager.shared
        _player = StateObject(wrappedValue: RadioPlayer(persistence: p))
    }

    var body: some Scene {
        // Main window
        WindowGroup("Not My First Radio") {
            ContentView()
                .environmentObject(player)
                .environmentObject(persistence)
                .onAppear {
                    setupNowPlaying()
                    restoreLastStation()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Replace default About panel with custom window
            CommandGroup(replacing: .appInfo) {
                OpenAboutButton()
            }

            // Remove default File > New
            CommandGroup(replacing: .newItem) {}

            // Playback menu
            CommandMenu("Playback") {
                Button("Play / Stop") {
                    player.togglePlayStop()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Mute / Unmute") {
                    persistence.isMuted.toggle()
                    player.applyVolume()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Button("Toggle Visualizer") {
                    persistence.visualizerEnabled.toggle()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Divider()

                ForEach(0..<6, id: \.self) { i in
                    Button("Preset \(i + 1)") {
                        if let station = persistence.presets[i] {
                            player.play(station)
                        }
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [.command, .shift])
                    .disabled(persistence.presets[i] == nil)
                }
            }
        }

        // Menu bar extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(player)
                .environmentObject(persistence)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        // Preferences window
        Settings {
            PreferencesView()
                .environmentObject(persistence)
        }

        // About window
        Window("About Not My First Radio", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: "radio")
            if player.state.isPlaying {
                if #available(macOS 14.0, *) {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative)
                } else {
                    Image(systemName: "waveform")
                }
            }
        }
    }

    private func setupNowPlaying() {
        NowPlayingManager.shared.setupRemoteCommands(player: player)
    }

    private func restoreLastStation() {
        // Restore last station to UI (but don't auto-play)
        if let last = persistence.lastStation {
            player.currentStation = last
        }
    }
}
