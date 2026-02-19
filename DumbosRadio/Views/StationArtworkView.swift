import SwiftUI

struct StationArtworkView: View {
    let url: URL?
    var size: CGFloat = 64

    @State private var image: NSImage?
    @State private var loaded = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "radio")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: url?.absoluteString) {
            await loadImage()
        }
    }

    private func loadImage() async {
        image = nil
        guard let url else { return }
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let img = NSImage(data: data) {
            image = img
        }
    }
}
