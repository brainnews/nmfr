import Foundation
import Combine

class PersistenceManager: ObservableObject {
    static let shared = PersistenceManager()

    // MARK: - Stations Library
    @Published var stations: [Station] = [] {
        didSet { save(stations, forKey: "stations") }
    }

    // MARK: - Presets (6 slots, nil = empty)
    @Published var presets: [Station?] = Array(repeating: nil, count: 6) {
        didSet { savePresets() }
    }

    // MARK: - Last played station
    @Published var lastStation: Station? {
        didSet {
            if let s = lastStation { save(s, forKey: "lastStation") }
            else { UserDefaults.standard.removeObject(forKey: "lastStation") }
        }
    }

    // MARK: - UI State
    @Published var volume: Double = 0.8 {
        didSet { UserDefaults.standard.set(volume, forKey: "volume") }
    }
    @Published var isMuted: Bool = false {
        didSet { UserDefaults.standard.set(isMuted, forKey: "isMuted") }
    }
    @Published var collapsed: Bool = false {
        didSet { UserDefaults.standard.set(collapsed, forKey: "collapsed") }
    }
    @Published var visualizerEnabled: Bool = true {
        didSet { UserDefaults.standard.set(visualizerEnabled, forKey: "visualizerEnabled") }
    }
    @Published var menuBarMode: Bool = false {
        didSet { UserDefaults.standard.set(menuBarMode, forKey: "menuBarMode") }
    }
    @Published var launchAtLogin: Bool = false {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    @Published var notificationsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var globalShortcutsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(globalShortcutsEnabled, forKey: "globalShortcutsEnabled") }
    }

    init() {
        load()
    }

    private func load() {
        let ud = UserDefaults.standard
        stations = loadArray(Station.self, forKey: "stations") ?? []
        presets = loadPresets()
        lastStation = loadObject(Station.self, forKey: "lastStation")
        volume = ud.object(forKey: "volume") as? Double ?? 0.8
        isMuted = ud.bool(forKey: "isMuted")
        collapsed = ud.bool(forKey: "collapsed")
        visualizerEnabled = ud.object(forKey: "visualizerEnabled") as? Bool ?? true
        menuBarMode = ud.bool(forKey: "menuBarMode")
        launchAtLogin = ud.bool(forKey: "launchAtLogin")
        notificationsEnabled = ud.object(forKey: "notificationsEnabled") as? Bool ?? true
        globalShortcutsEnabled = ud.object(forKey: "globalShortcutsEnabled") as? Bool ?? true
    }

    // MARK: - Preset helpers
    func setPreset(_ station: Station?, at index: Int) {
        guard index >= 0 && index < 6 else { return }
        var p = presets
        p[index] = station
        presets = p
    }

    func presetIndex(for station: Station) -> Int? {
        presets.firstIndex(where: { $0?.url == station.url })
    }

    func isInLibrary(_ station: Station) -> Bool {
        stations.contains(where: { $0.url == station.url })
    }

    func addStation(_ station: Station) {
        guard !isInLibrary(station) else { return }
        stations.append(station)
    }

    func removeStation(_ station: Station) {
        stations.removeAll { $0.url == station.url }
        // Clear from presets too
        for i in 0..<6 {
            if presets[i]?.url == station.url {
                setPreset(nil, at: i)
            }
        }
    }

    // MARK: - Private helpers
    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadObject<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func loadArray<T: Decodable>(_ type: T.Type, forKey key: String) -> [T]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([T].self, from: data)
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: "presets")
        }
    }

    private func loadPresets() -> [Station?] {
        guard let data = UserDefaults.standard.data(forKey: "presets"),
              let loaded = try? JSONDecoder().decode([Station?].self, from: data),
              loaded.count == 6
        else {
            return Array(repeating: nil, count: 6)
        }
        return loaded
    }
}
