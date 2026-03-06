import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var persistence: PersistenceManager

    var body: some View {
        if persistence.history.isEmpty {
            Text("Songs you hear will appear here")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(groupedHistory, id: \.0) { section, entries in
                        sectionHeader(section)
                        ForEach(entries) { entry in
                            HistoryRowView(entry: entry)
                        }
                    }
                }
                .padding(.vertical, 4)

                Button("Clear History") {
                    persistence.clearHistory()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    // Groups entries by "Today", "Yesterday", or "Mon Mar 3" etc.
    private var groupedHistory: [(String, [HistoryEntry])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        var groups: [(String, [HistoryEntry])] = []
        var currentKey: String? = nil
        var currentEntries: [HistoryEntry] = []

        for entry in persistence.history {
            let entryDay = cal.startOfDay(for: entry.date)
            let key: String
            if entryDay == today {
                key = "Today"
            } else if entryDay == yesterday {
                key = "Yesterday"
            } else {
                key = entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            }

            if key == currentKey {
                currentEntries.append(entry)
            } else {
                if let k = currentKey { groups.append((k, currentEntries)) }
                currentKey = key
                currentEntries = [entry]
            }
        }
        if let k = currentKey { groups.append((k, currentEntries)) }
        return groups
    }
}

// MARK: - Row

private struct HistoryRowView: View {
    let entry: HistoryEntry

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            StationArtworkView(url: entry.station.faviconURL, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.trackTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(entry.station.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if hovering {
                let query = entry.trackTitle
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                Menu {
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

            Text(timeString(for: entry.date))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    private func timeString(for date: Date) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let entryDay = cal.startOfDay(for: date)
        let timeStr = date.formatted(.dateTime.hour().minute())

        if entryDay == today {
            return timeStr
        } else if let yesterday = cal.date(byAdding: .day, value: -1, to: today), entryDay == yesterday {
            return "Yesterday \(timeStr)"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day()) + " \(timeStr)"
        }
    }
}
