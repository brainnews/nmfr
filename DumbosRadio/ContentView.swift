import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

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
                withAnimation(.spring(duration: 0.25)) {
                    persistence.collapsed.toggle()
                }
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
                    .transition(.opacity)
            }
        }
        .frame(minWidth: 380, idealWidth: 380, maxWidth: 480)
        .frame(minHeight: persistence.collapsed ? 170 : 420, idealHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
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
