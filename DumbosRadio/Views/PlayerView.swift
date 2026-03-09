import SwiftUI
import AppKit

struct PlayerView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var hoverPlay = false
    @State private var hoverMute = false
    @State private var hoverViz  = false
    @State private var hoverEQ   = false
    @State private var showEQ    = false
    @State private var now       = Date()

    private var playerBackground: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.88)
    }

    var body: some View {
        ZStack {
            // Visualizer behind everything — hidden when idle/stopped to avoid a flat line.
            // Loading shows the animated sine waves since there's no audio signal yet.
            if persistence.visualizerEnabled && player.isActive {
                VisualizerView(
                    player: player,
                    isPlaying: true,
                    settings: VisualizerSettings(
                        colorMode:        persistence.visualizerColorMode,
                        solidColor:       persistence.visualizerSolidColor,
                        crtEnabled:       persistence.visualizerCRTEnabled,
                        glitchEnabled:    persistence.visualizerGlitchEnabled,
                        pixelatedEnabled: persistence.visualizerPixelatedEnabled
                    )
                )
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

                    // Meta — shows Shazam match when available, else ICY stream title
                    HStack(spacing: 6) {
                        let shazamMatch = player.shazamMatch
                        let shazamText: String? = shazamMatch.flatMap { m in
                            let parts = [m.artist, m.title].compactMap { $0 }.filter { !$0.isEmpty }
                            return parts.isEmpty ? nil : parts.joined(separator: " – ")
                        }
                        let displayText = shazamText
                            ?? player.streamTitle
                            ?? player.currentStation?.metaString
                            ?? "Select a station to begin"

                        if shazamText != nil {
                            Image(systemName: "music.note")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.accentColor.opacity(0.7))
                        } else if player.isShazamMatching {
                            if #available(macOS 14.0, *) {
                                Image(systemName: "shazam.logo")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.secondary.opacity(0.5))
                            } else {
                                Image(systemName: "waveform.badge.magnifyingglass")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.secondary.opacity(0.5))
                            }
                        }

                        Text(displayText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentTransition(.opacity)
                            .animation(.easeInOut(duration: 0.35), value: displayText)

                        if let station = player.currentStation {
                            let query = (shazamText ?? player.streamTitle ?? station.name)
                                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            Menu {
                                if let amURL = shazamMatch?.appleMusicURL {
                                    Button("Open in Apple Music") { NSWorkspace.shared.open(amURL) }
                                    Divider()
                                }
                                Button("Spotify")     { openURL("https://open.spotify.com/search/\(query)") }
                                Button("Apple Music") { openURL("https://music.apple.com/search?term=\(query)") }
                                Button("Bandcamp")    { openURL("https://bandcamp.com/search?q=\(query)") }
                                Button("YouTube")     { openURL("https://www.youtube.com/results?search_query=\(query)") }
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .frame(width: 16, height: 16)
                            .help("Find on music sites")
                        }
                    }

                    // Controls
                    HStack(spacing: 8) {
                        // Play/Stop — symbol morphs on macOS 14+
                        Button(action: { player.togglePlayStop() }) {
                            if #available(macOS 14.0, *) {
                                Image(systemName: playButtonIcon)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(height: 26)
                                    .contentTransition(.symbolEffect(.replace))
                            } else {
                                Image(systemName: playButtonIcon)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(height: 26)
                            }
                        }
                        .buttonStyle(.plain)
                        .onHover { hoverPlay = $0 }
                        .opacity(hoverPlay ? 0.6 : 1)
                        .foregroundStyle(player.state.isPlaying ? Color.accentColor : .primary)
                        .animation(.easeInOut(duration: 0.2), value: player.state.isPlaying)
                        .help(player.state.isPlaying ? "Stop" : "Play")
                        .disabled(player.currentStation == nil && !player.state.isPlaying)

                        // EQ
                        Button(action: { showEQ.toggle() }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 12))
                                .frame(height: 22)
                        }
                        .buttonStyle(.plain)
                        .onHover { hoverEQ = $0 }
                        .opacity(hoverEQ ? 0.6 : 1)
                        .foregroundStyle(persistence.eqSettings.enabled ? Color.accentColor : .secondary)
                        .help("Equalizer")
                        .popover(isPresented: $showEQ, arrowEdge: .bottom) {
                            EQView()
                                .environmentObject(persistence)
                        }

                        // Visualizer toggle
                        Button(action: { persistence.visualizerEnabled.toggle() }) {
                            Image(systemName: persistence.visualizerEnabled ? "waveform" : "waveform.slash")
                                .font(.system(size: 12))
                                .frame(height: 22)
                        }
                        .buttonStyle(.plain)
                        .onHover { hoverViz = $0 }
                        .opacity(hoverViz ? 0.6 : 1)
                        .foregroundStyle(persistence.visualizerEnabled ? Color.accentColor : .secondary)
                        .help(persistence.visualizerEnabled ? "Hide Visualizer" : "Show Visualizer")

                        // Mute
                        Button(action: {
                            persistence.isMuted.toggle()
                            player.applyVolume()
                        }) {
                            Image(systemName: persistence.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 12))
                                .frame(height: 22)
                        }
                        .buttonStyle(.plain)
                        .onHover { hoverMute = $0 }
                        .opacity(hoverMute ? 0.6 : 1)
                        .foregroundStyle(.secondary)
                        .help(persistence.isMuted ? "Unmute" : "Mute")

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
                        .frame(maxWidth: 80)

                        // Sleep timer countdown
                        if let end = persistence.sleepTimerEnd {
                            Button(action: { persistence.sleepTimerEnd = nil }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "moon.fill")
                                        .font(.system(size: 8))
                                    Text(sleepTimerLabel(end: end))
                                        .font(.system(size: 9, design: .monospaced))
                                }
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Sleep timer active — click to cancel")
                            .transition(.opacity)
                        }

                        // Status — slides in from trailing edge when buffering/error
                        if let status = player.state.statusText {
                            Text(status)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .lineLimit(1)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.easeOut(duration: 0.25), value: player.state)

                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(height: 90)
        .background(playerBackground)
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
    }

    private func sleepTimerLabel(end: Date) -> String {
        let remaining = end.timeIntervalSince(now)
        guard remaining > 0 else { return "" }
        let minutes = Int(remaining / 60) + 1
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins == 0 ? "\(hours)h" : "\(hours)h\(mins)m"
        }
        return "\(minutes)m"
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
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
