import Foundation

struct LibraryExportData: Codable {
    let version: Int
    let stations: [Station]
    let presets: [Station?]
}
