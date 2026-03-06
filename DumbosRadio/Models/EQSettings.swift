import Foundation

struct EQSettings: Codable, Equatable {
    var enabled: Bool = false
    var presetName: String = "Flat"
    var gains: [Float] = [0, 0, 0, 0, 0]   // one per band, dB

    static let bandCount = 5
    static let bandFrequencies: [Float] = [60, 250, 1000, 4000, 12000]
    static let bandLabels = ["60", "250", "1k", "4k", "12k"]
    static let gainRange: ClosedRange<Double> = -12...12

    static let presets: [(name: String, gains: [Float])] = [
        ("Flat",         [ 0,  0,  0,  0,  0]),
        ("Bass Boost",   [ 6,  4,  0,  0,  0]),
        ("Treble Boost", [ 0,  0,  0,  4,  6]),
        ("Vocal",        [-2,  0,  4,  3,  1]),
        ("Radio",        [ 2,  3,  0,  2,  2]),
    ]

    mutating func applyPreset(named name: String) {
        guard let preset = EQSettings.presets.first(where: { $0.name == name }) else { return }
        gains = preset.gains
        presetName = name
    }

    mutating func setGain(_ gain: Float, at index: Int) {
        gains[index] = gain
        // Check if this matches a known preset
        if let match = EQSettings.presets.first(where: { $0.gains == gains }) {
            presetName = match.name
        } else {
            presetName = "Custom"
        }
    }
}
