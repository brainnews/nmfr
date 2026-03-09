import SwiftUI
import Sparkle

@main
struct NMFRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var persistence = PersistenceManager.shared
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

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
                    GlobalShortcutManager.shared.setup(player: player, persistence: persistence)
                    applyDockIconPolicy()
                }
                .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                    if let end = persistence.sleepTimerEnd, Date() >= end {
                        persistence.sleepTimerEnd = nil
                        player.stop()
                    }
                }
                .onContinueUserActivity("com.miles.NotMyFirstRadio.playStation") { activity in
                    guard let urlString = activity.persistentIdentifier else { return }
                    let station = persistence.stations.first(where: { $0.url == urlString })
                        ?? persistence.lastStation
                    if let station { player.play(station) }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Replace default About panel with custom window
            CommandGroup(replacing: .appInfo) {
                OpenAboutButton()
                Button("Check for Updates…") {
                    updaterController.updater.checkForUpdates()
                }
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
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [.command, .option])
                    .disabled(persistence.presets[i] == nil)
                }

                Divider()

                Menu("Sleep Timer") {
                    if persistence.sleepTimerEnd != nil {
                        Button("Cancel Timer") {
                            persistence.sleepTimerEnd = nil
                        }
                        Divider()
                    }
                    Button("15 Minutes") {
                        persistence.sleepTimerEnd = Date().addingTimeInterval(15 * 60)
                    }
                    Button("30 Minutes") {
                        persistence.sleepTimerEnd = Date().addingTimeInterval(30 * 60)
                    }
                    Button("1 Hour") {
                        persistence.sleepTimerEnd = Date().addingTimeInterval(60 * 60)
                    }
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
            AboutView(updater: updaterController.updater)
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

    private func applyDockIconPolicy() {
        NSApp.setActivationPolicy(persistence.hideDockIcon ? .accessory : .regular)
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
