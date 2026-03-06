import SwiftUI

struct StationListView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    private enum StationSort { case added, alphabetical, recentlyPlayed }
    @State private var stationSort: StationSort = .added
    @State private var isSelecting             = false
    @State private var selectedURLs            = Set<String>()
    @State private var showRemoveConfirmation  = false
    @State private var activeTag: String?      = nil   // nil = All

    // MARK: - Tag filter data

    /// Unique tags sorted by frequency (most common first), min 2 occurrences.
    private var filterTags: [String] {
        var counts: [String: Int] = [:]
        for station in persistence.stations {
            for tag in station.parsedTags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
            .map { $0.key }
    }

    // MARK: - Displayed stations

    private var displayedStations: [Station] {
        let base: [Station]
        switch stationSort {
        case .added:
            base = persistence.stations
        case .alphabetical:
            base = persistence.stations.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .recentlyPlayed:
            var lastPlayed: [String: Date] = [:]
            for entry in persistence.history {
                let url = entry.station.url
                if lastPlayed[url] == nil || entry.date > lastPlayed[url]! {
                    lastPlayed[url] = entry.date
                }
            }
            base = persistence.stations.sorted {
                let a = lastPlayed[$0.url] ?? .distantPast
                let b = lastPlayed[$1.url] ?? .distantPast
                return a > b
            }
        }
        guard let tag = activeTag else { return base }
        return base.filter { $0.parsedTags.contains(tag) }
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
                        let tags = filterTags
                        if !tags.isEmpty {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    persistence.tagStripVisible.toggle()
                                    if !persistence.tagStripVisible { activeTag = nil }
                                }
                            }) {
                                Image(systemName: "tag")
                                    .font(.system(size: 9))
                                    .foregroundStyle(persistence.tagStripVisible ? Color.accentColor : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(persistence.tagStripVisible ? "Hide tag filters" : "Show tag filters")
                            .padding(.trailing, 6)
                            .onHover { inside in inside ? NSCursor.arrow.push() : NSCursor.pop() }
                        }

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                switch stationSort {
                                case .added:          stationSort = .alphabetical
                                case .alphabetical:   stationSort = .recentlyPlayed
                                case .recentlyPlayed: stationSort = .added
                                }
                            }
                        }) {
                            Image(systemName: stationSort == .alphabetical ? "textformat.abc"
                                            : stationSort == .recentlyPlayed ? "clock.arrow.circlepath"
                                            : "clock")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(stationSort == .alphabetical ? "Sorted A–Z — click for recently played"
                            : stationSort == .recentlyPlayed ? "Sorted by recently played — click for date added"
                            : "Sorted by date added — click for A–Z")
                    }

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isSelecting.toggle()
                            if !isSelecting { selectedURLs.removeAll() }
                        }
                    }) {
                        Image(systemName: isSelecting ? "pencil.slash" : "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(isSelecting ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isSelecting ? "Done selecting" : "Select stations")
                    .padding(.leading, 8)
                    .onHover { inside in inside ? NSCursor.arrow.push() : NSCursor.pop() }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)

                // Tag filter strip
                let tags = filterTags
                if !tags.isEmpty && persistence.tagStripVisible {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            TagPill(label: "All", selected: activeTag == nil) {
                                activeTag = nil
                            }
                            ForEach(tags, id: \.self) { tag in
                                TagPill(label: tag, selected: activeTag == tag) {
                                    activeTag = (activeTag == tag) ? nil : tag
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }
                }

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
            .onChange(of: persistence.stations.count) { _ in
                // If active tag no longer has enough stations to appear, clear it
                if let tag = activeTag, !filterTags.contains(tag) {
                    activeTag = nil
                }
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

// MARK: - TagPill

private struct TagPill: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(selected ? Color.accentColor : Color.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Station tag parsing

private extension Station {
    var parsedTags: [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }
}
