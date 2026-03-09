import AppIntents

struct PlayStationIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Station"
    static var description = IntentDescription(
        "Play an internet radio station in Not My First Radio.",
        categoryName: "Playback"
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Station")
    var station: StationEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let player = RadioPlayer.shared else {
            throw PlayStationError.playerUnavailable
        }
        let persistence = PersistenceManager.shared
        // Resolve full Station from the library; fall back to a minimal Station if not found.
        let resolved = persistence.stations.first(where: { $0.url == station.id })
            ?? Station(name: station.name, url: station.id)
        player.play(resolved)
        return .result()
    }
}

enum PlayStationError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case playerUnavailable
    var localizedStringResource: LocalizedStringResource {
        "Not My First Radio is not running. Please open the app and try again."
    }
}

// MARK: - App Shortcuts (appear in Spotlight and Siri automatically)

struct NMFRShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayStationIntent(),
            phrases: [
                "Play \(\.$station) in \(.applicationName)",
                "Play \(\.$station) on \(.applicationName)",
                "Start \(\.$station) in \(.applicationName)",
            ],
            shortTitle: "Play Station",
            systemImageName: "radio"
        )
    }
}
