import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager
    @Environment(\.colorScheme) private var colorScheme

    private var playerBackground: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.88)
    }

    var body: some View {
        ZStack {
            // Visualizer behind everything
            if persistence.visualizerEnabled {
                if player.state.isPlaying {
                    VisualizerView(player: player, isPlaying: true)
                } else {
                    IdleVisualizerView()
                }
            }

            // Player content
            HStack(spacing: 12) {
                StationArtworkView(url: player.currentStation?.faviconURL)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    // Station name
                    Text(player.currentStation?.name ?? "No Station")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Meta
                    Text(player.currentStation?.metaString ?? "Select a station to begin")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    // Controls
                    HStack(spacing: 8) {
                        // Play/Stop
                        Button(action: { player.togglePlayStop() }) {
                            Image(systemName: playButtonIcon)
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(player.state.isPlaying ? Color.accentColor : .primary)
                        .help(player.state.isPlaying ? "Stop" : "Play")
                        .disabled(player.currentStation == nil && !player.state.isPlaying)

                        // Mute
                        Button(action: {
                            persistence.isMuted.toggle()
                            player.applyVolume()
                        }) {
                            Image(systemName: persistence.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help(persistence.isMuted ? "Unmute" : "Mute")

                        // Visualizer toggle
                        Button(action: { persistence.visualizerEnabled.toggle() }) {
                            Image(systemName: persistence.visualizerEnabled ? "waveform" : "waveform.slash")
                                .font(.system(size: 12))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(persistence.visualizerEnabled ? Color.accentColor : .secondary)
                        .help(persistence.visualizerEnabled ? "Hide Visualizer" : "Show Visualizer")

                        // Volume slider
                        Slider(value: Binding(
                            get: { persistence.volume },
                            set: { v in
                                persistence.volume = v
                                if v > 0 { persistence.isMuted = false }
                                player.applyVolume()
                            }
                        ), in: 0...1)
                        .controlSize(.mini)
                        .frame(maxWidth: .infinity)
                    }

                    // Status / now-playing — always rendered to reserve space, invisible when nil.
                    // Priority: loading/error text > live stream title > hidden.
                    Text(player.state.statusText ?? (player.state.isPlaying ? player.streamTitle : nil) ?? " ")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(player.state.statusText != nil ? Color.accentColor : .secondary)
                        .lineLimit(1)
                        .opacity((player.state.statusText != nil || (player.state.isPlaying && player.streamTitle != nil)) ? 1 : 0)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(height: 90)
        .background(playerBackground)
    }

    private var playButtonIcon: String {
        switch player.state {
        case .idle: return "play.fill"
        case .loading: return "stop.fill"
        case .playing: return "stop.fill"
        case .error: return "arrow.clockwise"
        }
    }
}
