import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager
    @Environment(\.colorScheme) private var colorScheme

    private var playerBackground: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.88)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Player
            PlayerView()
                .environmentObject(player)
                .environmentObject(persistence)

            Divider()

            // Presets
            PresetsView()
                .environmentObject(player)
                .environmentObject(persistence)

            // Collapse toggle
            Button(action: {
                // Both directions: set state immediately so the window resizes without
                // fighting a spring. The insertion/removal transitions own their animations.
                persistence.collapsed.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: persistence.collapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 9))
                    Text(persistence.collapsed ? "Show Stations" : "Hide Stations")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.02))

            // Station browser (collapsible)
            if !persistence.collapsed {
                Divider()

                StationBrowserView()
                    .environmentObject(player)
                    .environmentObject(persistence)
                    .frame(minHeight: 200, maxHeight: .infinity)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.2)),
                        removal: .opacity.animation(.easeIn(duration: 0.15))))
            }
        }
        .frame(minWidth: 380, idealWidth: 380, maxWidth: 480, alignment: .top)
        .frame(minHeight: persistence.collapsed ? 170 : 420, idealHeight: 520, alignment: .top)
        .background(playerBackground)
        .background(WindowBackgroundSetter(color: NSColor(playerBackground)))
        .onChange(of: player.state) { newState in
            handleStateChange(newState)
        }
    }

    private func handleStateChange(_ state: PlaybackState) {
        guard let station = player.currentStation else { return }

        if case .playing = state {
            NowPlayingManager.shared.update(station: station, isPlaying: true)

            if persistence.notificationsEnabled {
                NotificationManager.notifyStationChanged(station)
            }
        } else if case .idle = state {
            NowPlayingManager.shared.update(station: nil, isPlaying: false)
        }
    }
}

/// Sets NSWindow.backgroundColor to match our custom background, eliminating
/// the flash of the system window color during expand/collapse animation.
private struct WindowBackgroundSetter: NSViewRepresentable {
    let color: NSColor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { view.window?.backgroundColor = color }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { nsView.window?.backgroundColor = color }
    }
}
