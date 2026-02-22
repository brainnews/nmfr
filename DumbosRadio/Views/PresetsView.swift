import SwiftUI

struct PresetsView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    var body: some View {
        HStack(spacing: 5) {
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
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.12)).frame(height: 1)
        }
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

    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false
    @GestureState private var isPressed = false

    var body: some View {
        Button(action: { activate() }) {
            VStack(spacing: 3) {
                // LED indicator dot
                Circle()
                    .fill(ledColor)
                    .frame(width: 3.5, height: 3.5)
                    .shadow(color: isActive ? Color.accentColor : .clear, radius: 3.5, x: 0, y: 0)

                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(indexLabelColor)

                if let station {
                    Text(station.name)
                        .font(.system(size: 8, design: .default))
                        .foregroundStyle(isActive ? .primary : (isBuffering ? .primary : .secondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("—")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
        }
        .buttonStyle(TactileButtonStyle(isActive: isActive, isBuffering: isBuffering, hovering: hovering, isPressed: isPressed, colorScheme: colorScheme))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in state = true }
        )
        .onHover { hovering = $0 }
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
    }

    // MARK: - Helpers

    private var indexLabelColor: Color {
        (isActive || isBuffering) ? .primary : .secondary
    }

    private var ledColor: Color {
        if isActive    { return Color.accentColor }
        if isBuffering { return Color.accentColor.opacity(0.55) }
        return Color.primary.opacity(0.15)
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

// MARK: - Tactile Button Style

private struct TactileButtonStyle: ButtonStyle {
    let isActive: Bool
    let isBuffering: Bool
    let hovering: Bool
    let isPressed: Bool
    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        let p = isPressed

        configuration.label
            .background(
                ZStack {
                    // Base fill — darkened for a more physical, remote-control feel
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlColor))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08))

                    // Active accent wash
                    if isActive {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.22))
                    }

                    // Lighting gradient — reverses on press to simulate physical depression
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                stops: p ? [
                                    .init(color: .black.opacity(0.14), location: 0),
                                    .init(color: .clear, location: 0.45),
                                    .init(color: .white.opacity(0.05), location: 1),
                                ] : [
                                    .init(color: .white.opacity(hovering ? 0.16 : 0.12), location: 0),
                                    .init(color: .clear, location: 0.5),
                                    .init(color: .black.opacity(0.15), location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            // Bevel border — light top / dark bottom, flips on press
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        LinearGradient(
                            colors: p
                                ? [.black.opacity(0.55), .white.opacity(0.07)]
                                : [.white.opacity(0.22), .black.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            // Buffering pulse border
            .overlay(
                Group {
                    if isBuffering {
                        BufferingBorderView(cornerRadius: 6)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            // Drop shadow lifts away on press
            .shadow(
                color: p ? .black.opacity(0.08) : .black.opacity(0.38),
                radius: p ? 0.5 : 3,
                x: 0,
                y: p ? 0 : 2
            )
            .scaleEffect(p ? 0.955 : 1.0)
            .animation(.spring(response: 0.13, dampingFraction: 0.8), value: p)
    }
}

// MARK: - Buffering border

private struct BufferingBorderView: View {
    let cornerRadius: CGFloat
    @State private var pulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(Color.accentColor, lineWidth: 1.5)
            .opacity(pulsing ? 0.9 : 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
            .onDisappear { pulsing = false }
    }
}
