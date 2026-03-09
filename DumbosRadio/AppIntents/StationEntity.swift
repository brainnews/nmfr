import AppIntents

/// AppEntity representing a saved radio station, used by App Intents / Shortcuts.
struct StationEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Station"
    static var defaultQuery = StationEntityQuery()

    /// The stream URL, used as the stable identifier.
    var id: String
    var name: String
    var metaString: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(metaString)")
    }

    init(from station: Station) {
        self.id = station.url
        self.name = station.name
        self.metaString = station.metaString
    }
}

// MARK: - Query

struct StationEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [StationEntity] {
        let stations = await MainActor.run { PersistenceManager.shared.stations }
        return identifiers.compactMap { id in
            stations.first(where: { $0.url == id }).map { StationEntity(from: $0) }
        }
    }

    func entities(matching string: String) async throws -> [StationEntity] {
        let stations = await MainActor.run { PersistenceManager.shared.stations }
        let lower = string.lowercased()
        return stations
            .filter { $0.name.lowercased().contains(lower) }
            .map { StationEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [StationEntity] {
        let stations = await MainActor.run { PersistenceManager.shared.stations }
        return stations.map { StationEntity(from: $0) }
    }
}
