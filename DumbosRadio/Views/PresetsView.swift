import SwiftUI

struct PresetsView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { index in
                PresetButton(
                    index: index,
                    station: persistence.presets[index],
                    isActive: isActive(at: index),
                    isBuffering: isBuffering(at: index)
                )
                .environmentObject(player)
                .environmentObject(persistence)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func isActive(at index: Int) -> Bool {
        guard let preset = persistence.presets[index],
              let current = player.currentStation else { return false }
        return preset.url == current.url && player.state.isPlaying
    }

    private func isBuffering(at index: Int) -> Bool {
        guard let preset = persistence.presets[index],
              let current = player.currentStation else { return false }
        return preset.url == current.url && player.state.isLoading
    }
}

struct PresetButton: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    let index: Int
    let station: Station?
    let isActive: Bool
    let isBuffering: Bool

    @State private var showingContextMenu = false
    @State private var pulsing = false

    var body: some View {
        Button(action: { activate() }) {
            VStack(spacing: 1) {
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(isActive || isBuffering ? Color.accentColor : .secondary)

                if let station {
                    Text(station.name)
                        .font(.system(size: 8, design: .default))
                        .foregroundStyle(isActive || isBuffering ? Color.accentColor : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("—")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .padding(.horizontal, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(strokeColor, lineWidth: isBuffering ? 1.5 : 1)
                            .opacity(isBuffering ? (pulsing ? 0.9 : 0.2) : 1)
                    )
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .help(station.map { s in
            s.bitrate > 0 ? "\(s.name) · \(s.bitrate)kbps" : s.name
        } ?? "Empty — right-click to assign")
        .keyboardShortcut(keyEquivalent, modifiers: [])
        .contextMenu {
            if let station = player.currentStation {
                Button("Assign \"\(truncated(station.name))\" to Slot \(index + 1)") {
                    persistence.setPreset(station, at: index)
                }
            } else {
                Button("Assign Current Station") {}
                    .disabled(true)
            }

            if persistence.presets[index] != nil {
                Divider()
                Button("Clear Slot \(index + 1)") {
                    persistence.setPreset(nil, at: index)
                }
            }
        }
        .onAppear {
            if isBuffering { startPulse() }
        }
        .onChange(of: isBuffering) { buffering in
            if buffering {
                startPulse()
            } else {
                withAnimation(.easeOut(duration: 0.3)) { pulsing = false }
            }
        }
    }

    // MARK: - Helpers

    private var fillColor: Color {
        if isActive    { return Color.accentColor.opacity(0.15) }
        if isBuffering { return Color.accentColor.opacity(0.08) }
        return Color.white.opacity(0.05)
    }

    private var strokeColor: Color {
        isActive || isBuffering ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.1)
    }

    private func startPulse() {
        pulsing = false
        withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
            pulsing = true
        }
    }

    private func activate() {
        guard let station = station else { return }
        player.play(station)
    }

    private var keyEquivalent: KeyEquivalent {
        KeyEquivalent(Character("\(index + 1)"))
    }

    private func truncated(_ name: String, max: Int = 20) -> String {
        name.count > max ? String(name.prefix(max)) + "…" : name
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
