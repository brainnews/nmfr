import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    @State private var hoverPlay = false
    @State private var hoverMute = false
    @State private var hoveredPreset: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Mini player
            HStack(spacing: 10) {
                StationArtworkView(url: player.currentStation?.faviconURL, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentStation?.name ?? "Not My First Radio")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(player.streamTitle ?? player.currentStation?.metaString ?? "No station playing")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.35), value: player.streamTitle)
                }

                Spacer()

                // Mute
                Button(action: {
                    persistence.isMuted.toggle()
                    player.applyVolume()
                }) {
                    Image(systemName: persistence.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .opacity(hoverMute ? 0.6 : 1)
                .onHover { hoverMute = $0 }
                .help(persistence.isMuted ? "Unmute" : "Mute")

                // Play/Stop
                Button(action: { player.togglePlayStop() }) {
                    Image(systemName: player.state.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 14))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(player.state.isPlaying ? Color.accentColor : .primary)
                .opacity(hoverPlay ? 0.6 : 1)
                .onHover { hoverPlay = $0 }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Presets
            VStack(alignment: .leading, spacing: 0) {
                Text("PRESETS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(0..<6, id: \.self) { i in
                    if let station = persistence.presets[i] {
                        let isActive = player.currentStation?.url == station.url && player.state.isPlaying
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

                                if isActive {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                isActive
                                    ? Color.accentColor.opacity(0.1)
                                    : (hoveredPreset == i ? Color.primary.opacity(0.07) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { hoveredPreset = $0 ? i : nil }
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
                Button("Open Radio") { openMainWindow() }
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

    private func openMainWindow() {
        // Close the MenuBarExtra panel before activating the main window
        NSApp.windows.first { $0 is NSPanel && $0.isVisible }?.close()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.isVisible && !($0 is NSPanel) }?.makeKeyAndOrderFront(nil)
    }
}
