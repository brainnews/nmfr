import SwiftUI
import AppKit

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("Not My First Radio")
                .font(.title2.weight(.semibold))

            Text("Version \(appVersion)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Link("Developed by Dumbsoft", destination: URL(string: "https://dumbsoft.com")!)
                .font(.system(size: 11))

            Divider()
                .padding(.horizontal, 40)

            KoFiButton()
        }
        .padding(28)
        .frame(width: 280)
    }
}

/// Used in .commands to open the About window — needs to be a View to access @Environment
struct OpenAboutButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About Not My First Radio") {
            openWindow(id: "about")
        }
    }
}

struct KoFiButton: View {
    var body: some View {
        Link(destination: URL(string: "https://ko-fi.com/Y8Y61HEIMA")!) {
            AsyncImage(url: URL(string: "https://storage.ko-fi.com/cdn/kofi6.png?v=6")) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text("Support on Ko-fi")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 36)
        }
        .buttonStyle(.plain)
        .help("Support NMFR on Ko-fi")
    }
}
