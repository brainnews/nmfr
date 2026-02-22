import SwiftUI

struct StationRowView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    let station: Station
    let showSaveButton: Bool
    var showPresetButton: Bool = true
    var onRemove: (() -> Void)? = nil

    @State private var hovering = false
    @State private var justSaved = false

    var isPlaying: Bool {
        player.currentStation?.url == station.url && player.state.isPlaying
    }

    var isSaved: Bool {
        persistence.isInLibrary(station)
    }

    var presetIndex: Int? {
        persistence.presetIndex(for: station)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Artwork
            StationArtworkView(url: station.faviconURL, size: 36)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(station.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isPlaying ? Color.accentColor : .primary)
                        .lineLimit(1)

                    if isPlaying {
                        if #available(macOS 14.0, *) {
                            Image(systemName: "waveform")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.accentColor)
                                .symbolEffect(.variableColor.iterative)
                        } else {
                            Image(systemName: "waveform")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                Text(station.metaString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Actions (visible on hover or always)
            HStack(spacing: 4) {
                // Preset assign
                if showPresetButton { Menu {
                    ForEach(0..<6, id: \.self) { i in
                        let label = persistence.presets[i].map { "Slot \(i + 1) · \($0.name)" }
                                    ?? "Assign to Slot \(i + 1)"
                        Button(label) {
                            persistence.setPreset(station, at: i)
                        }
                    }
                } label: {
                    Image(systemName: presetIndex != nil ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24, height: 24)
                .foregroundStyle(presetIndex != nil ? Color.accentColor : .secondary)
                .help("Assign to Preset") }

                // Save or Remove
                if showSaveButton {
                    Button(action: {
                        if isSaved {
                            persistence.removeStation(station)
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                                persistence.addStation(station)
                                justSaved = true
                            }
                            Task {
                                try? await Task.sleep(for: .milliseconds(400))
                                withAnimation(.easeOut(duration: 0.2)) { justSaved = false }
                            }
                        }
                    }) {
                        Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 11))
                            .frame(width: 24, height: 24)
                            .scaleEffect(justSaved ? 1.35 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSaved ? .green : .secondary)
                    .help(isSaved ? "Saved" : "Save to Library")
                } else if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Remove from Library")
                }
            }
            .opacity(hovering ? 1 : 0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(isPlaying
                      ? Color.accentColor.opacity(0.1)
                      : (hovering ? Color.primary.opacity(0.07) : .clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isPlaying {
                player.stop()
            } else {
                player.play(station)
            }
        }
        .onHover { hovering = $0 }
    }
}
