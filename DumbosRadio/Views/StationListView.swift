import SwiftUI

struct StationListView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    @State private var sortAlphabetically = false

    private var displayedStations: [Station] {
        sortAlphabetically
            ? persistence.stations.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            : persistence.stations
    }

    var body: some View {
        if persistence.stations.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "radio")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("No saved stations")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Search and save stations to build your library.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            VStack(spacing: 0) {
                // Sort / count header
                HStack(spacing: 0) {
                    Text("\(persistence.stations.count) station\(persistence.stations.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Button(action: { withAnimation(.easeInOut(duration: 0.15)) { sortAlphabetically.toggle() } }) {
                        HStack(spacing: 3) {
                            Image(systemName: sortAlphabetically ? "textformat.abc" : "clock")
                                .font(.system(size: 9))
                            Text(sortAlphabetically ? "A–Z" : "Recent")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(sortAlphabetically ? "Sorted A–Z — click for recent" : "Sorted by date added — click for A–Z")
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(displayedStations) { station in
                            StationRowView(
                                station: station,
                                showSaveButton: false,
                                onRemove: { persistence.removeStation(station) }
                            )
                            .environmentObject(player)
                            .environmentObject(persistence)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
