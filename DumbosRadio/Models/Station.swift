import Foundation

struct Station: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var url: String
    var favicon: String
    var country: String
    var tags: String
    var bitrate: Int
    var votes: Int

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        favicon: String = "",
        country: String = "",
        tags: String = "",
        bitrate: Int = 0,
        votes: Int = 0
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.favicon = favicon
        self.country = country
        self.tags = tags
        self.bitrate = bitrate
        self.votes = votes
    }

    /// Returns a 2–3 letter ISO region code regardless of whether `country`
    /// was stored as a full English name (old data) or already as a code.
    var countryCode: String {
        let trimmed = country.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        // Already looks like an ISO code
        if trimmed.count <= 3 && trimmed.allSatisfy({ $0.isLetter && $0.isUppercase }) {
            return trimmed
        }
        // Look up via Locale reverse-mapping (built once, cached)
        return Station.countryNameToCode[trimmed.lowercased()] ?? trimmed
    }

    private static let countryNameToCode: [String: String] = {
        var map: [String: String] = [:]
        for code in Locale.isoRegionCodes {
            if let name = Locale(identifier: "en_US_POSIX").localizedString(forRegionCode: code) {
                map[name.lowercased()] = code
            }
        }
        return map
    }()

    var metaString: String {
        var parts: [String] = []
        let cc = countryCode
        if !cc.isEmpty { parts.append(cc) }
        let tagList = tags.split(separator: ",").prefix(3)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if !tagList.isEmpty { parts.append(tagList) }
        if bitrate > 0 { parts.append("\(bitrate)kbps") }
        if votes > 0 { parts.append("♥ \(votes)") }
        return parts.isEmpty ? "Internet Radio" : parts.joined(separator: " · ")
    }

    var faviconURL: URL? {
        guard !favicon.isEmpty else { return nil }
        return URL(string: favicon)
    }
}
