import SwiftUI

struct StationListView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    @State private var sortAlphabetically      = false
    @State private var isSelecting             = false
    @State private var selectedURLs            = Set<String>()
    @State private var showRemoveConfirmation  = false

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
                // Header
                HStack(spacing: 0) {
                    Text(isSelecting
                         ? (selectedURLs.isEmpty ? "Select stations" : "\(selectedURLs.count) selected")
                         : "\(persistence.stations.count) station\(persistence.stations.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .animation(nil, value: isSelecting)

                    Spacer()

                    if !isSelecting {
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

                    Button(isSelecting ? "Done" : "Select") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isSelecting.toggle()
                            if !isSelecting { selectedURLs.removeAll() }
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(displayedStations) { station in
                            HStack(spacing: 0) {
                                if isSelecting {
                                    Image(systemName: selectedURLs.contains(station.url) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 15))
                                        .foregroundStyle(selectedURLs.contains(station.url) ? Color.accentColor : Color.secondary)
                                        .frame(width: 30)
                                        .padding(.leading, 4)
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                }
                                StationRowView(
                                    station: station,
                                    showSaveButton: false,
                                    onRemove: isSelecting ? nil : { persistence.removeStation(station) }
                                )
                                .environmentObject(player)
                                .environmentObject(persistence)
                                .allowsHitTesting(!isSelecting)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelecting { toggleSelection(station) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Select-mode bottom bar
                if isSelecting {
                    Divider()
                    HStack {
                        Button("Select All") {
                            selectedURLs = Set(displayedStations.map { $0.url })
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button("Remove \(selectedURLs.count) Station\(selectedURLs.count == 1 ? "" : "s")") {
                            showRemoveConfirmation = true
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(selectedURLs.isEmpty ? Color.secondary.opacity(0.4) : Color.red)
                        .disabled(selectedURLs.isEmpty)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert(
                "Remove \(selectedURLs.count) Station\(selectedURLs.count == 1 ? "" : "s")?",
                isPresented: $showRemoveConfirmation
            ) {
                Button("Remove", role: .destructive) { removeSelected() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .onChange(of: persistence.stations.isEmpty) { isEmpty in
                if isEmpty { isSelecting = false; selectedURLs.removeAll() }
            }
        }
    }

    // MARK: - Helpers

    private func toggleSelection(_ station: Station) {
        if selectedURLs.contains(station.url) {
            selectedURLs.remove(station.url)
        } else {
            selectedURLs.insert(station.url)
        }
    }

    private func removeSelected() {
        persistence.removeStations(matching: selectedURLs)
        selectedURLs.removeAll()
        isSelecting = false
    }
}
