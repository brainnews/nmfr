import Foundation

struct HistoryEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var station: Station
    var trackTitle: String
    var date: Date
}
