import SwiftUI
import AppKit

struct StorableColor: Codable, Equatable {
    var red, green, blue, alpha: Double

    static let `default` = StorableColor(red: 0.3, green: 1.0, blue: 0.8, alpha: 1.0)

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.red = ns.redComponent
        self.green = ns.greenComponent
        self.blue = ns.blueComponent
        self.alpha = ns.alphaComponent
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
