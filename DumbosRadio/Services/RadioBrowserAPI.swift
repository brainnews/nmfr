import Foundation

struct RadioBrowserAPI {
    private static let baseURL = "https://de1.api.radio-browser.info/json"

    /// Searches by station name and tag/genre in parallel, merges and deduplicates by URL, sorted by votes.
    static func searchStations(query: String) async throws -> [Station] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        async let nameResults = fetchStations(path: "byname", query: trimmed, limit: 20)
        async let tagResults  = fetchStations(path: "bytag",  query: trimmed, limit: 15)

        let (names, tags) = try await (nameResults, tagResults)

        var seen = Set<String>()
        var merged: [Station] = []
        for station in names + tags where seen.insert(station.url).inserted {
            merged.append(station)
        }
        return merged.sorted { $0.votes > $1.votes }
    }

    static func fetchCountries() async throws -> [(name: String, count: Int)] {
        let urlString = "\(baseURL)/countries?order=stationcount&reverse=true&hidebroken=true"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("NotMyFirstRadio/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode([RadioBrowserCategory].self, from: data)
        return decoded.compactMap { item -> (name: String, count: Int)? in
            guard !item.name.isEmpty, item.stationcount > 0 else { return nil }
            return (name: item.name, count: item.stationcount)
        }
    }

    static func fetchTags(limit: Int = 150) async throws -> [(name: String, count: Int)] {
        let urlString = "\(baseURL)/tags?order=stationcount&reverse=true&hidebroken=true&limit=\(limit)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("NotMyFirstRadio/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode([RadioBrowserCategory].self, from: data)
        return decoded.compactMap { item -> (name: String, count: Int)? in
            guard !item.name.isEmpty, item.stationcount > 0 else { return nil }
            return (name: item.name, count: item.stationcount)
        }
    }

    static func fetchStationsByCountry(_ country: String, limit: Int = 50) async throws -> [Station] {
        try await fetchStations(path: "bycountryexact", query: country, limit: limit)
    }

    static func fetchStationsByTag(_ tag: String, limit: Int = 50) async throws -> [Station] {
        try await fetchStations(path: "bytag", query: tag, limit: limit)
    }

    static func fetchTopStations(limit: Int = 25) async throws -> [Station] {
        let urlString = "\(baseURL)/stations/topvote/\(limit)?hidebroken=true"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("NotMyFirstRadio/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([RadioBrowserStation].self, from: data).compactMap { $0.toStation() }
    }

    private static func fetchStations(path: String, query: String, limit: Int) async throws -> [Station] {
        var pathAllowed = CharacterSet.urlPathAllowed
        pathAllowed.remove(charactersIn: "&+?#")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: pathAllowed) ?? query
        let urlString = "\(baseURL)/stations/\(path)/\(encoded)?limit=\(limit)&order=votes&reverse=true&hidebroken=true"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("NotMyFirstRadio/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([RadioBrowserStation].self, from: data).compactMap { $0.toStation() }
    }
}

// MARK: - API Response Models

private struct RadioBrowserCategory: Decodable {
    let name: String
    let stationcount: Int
}

private struct RadioBrowserStation: Decodable {
    let name: String
    let urlResolved: String?
    let url: String?
    let favicon: String?
    let countrycode: String?
    let tags: String?
    let bitrate: Int?
    let votes: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case urlResolved = "url_resolved"
        case url
        case favicon
        case countrycode
        case tags
        case bitrate
        case votes
    }

    func toStation() -> Station? {
        let streamURL = (urlResolved?.isEmpty == false ? urlResolved : url) ?? ""
        guard !streamURL.isEmpty, URL(string: streamURL) != nil else { return nil }

        return Station(
            name: name.trimmingCharacters(in: .whitespaces),
            url: streamURL,
            favicon: favicon ?? "",
            country: countrycode ?? "",
            tags: tags ?? "",
            bitrate: bitrate ?? 0,
            votes: votes ?? 0
        )
    }
}
