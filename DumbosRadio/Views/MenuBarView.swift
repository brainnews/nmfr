import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    var body: some View {
        VStack(spacing: 0) {
            // Mini player
            HStack(spacing: 10) {
                StationArtworkView(url: player.currentStation?.faviconURL, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentStation?.name ?? "Not My First Radio")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(player.currentStation?.metaString ?? "No station playing")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: { player.togglePlayStop() }) {
                    Image(systemName: player.state.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 14))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(player.state.isPlaying ? Color.accentColor : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Volume
            HStack(spacing: 8) {
                Image(systemName: persistence.isMuted ? "speaker.slash" : "speaker.wave.1")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        persistence.isMuted.toggle()
                        player.applyVolume()
                    }

                Slider(value: Binding(
                    get: { persistence.volume },
                    set: { v in
                        persistence.volume = v
                        if v > 0 { persistence.isMuted = false }
                        player.applyVolume()
                    }
                ), in: 0...1)
                .controlSize(.mini)

                Image(systemName: "speaker.wave.3")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Presets
            VStack(alignment: .leading, spacing: 2) {
                Text("PRESETS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                ForEach(0..<6, id: \.self) { i in
                    if let station = persistence.presets[i] {
                        Button(action: { player.play(station) }) {
                            HStack {
                                Text("\(i + 1)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)

                                Text(station.name)
                                    .font(.system(size: 11))
                                    .lineLimit(1)

                                Spacer()

                                if player.currentStation?.url == station.url && player.state.isPlaying {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                        .background(
                            player.currentStation?.url == station.url && player.state.isPlaying
                                ? Color.accentColor.opacity(0.1)
                                : Color.clear
                        )
                    }
                }

                if persistence.presets.allSatisfy({ $0 == nil }) {
                    Text("No presets configured")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
            }
            .padding(.bottom, 8)

            Divider()

            // Footer
            HStack {
                Button("Open Radio") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

                Spacer()

                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }
}
