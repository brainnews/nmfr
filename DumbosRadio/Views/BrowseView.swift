import SwiftUI

enum BrowseMode: String, CaseIterable {
    case countries = "Countries"
    case genres    = "Genres"
}

struct BrowseView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    @State private var mode: BrowseMode = .countries
    @State private var filter: String = ""
    @State private var categories: [(name: String, count: Int)] = []
    @State private var isLoadingCategories = false

    @State private var selectedCategory: String? = nil
    @State private var stations: [Station] = []
    @State private var isLoadingStations = false
    @State private var stationError: String? = nil

    private var filteredCategories: [(name: String, count: Int)] {
        guard !filter.isEmpty else { return categories }
        return categories.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let selected = selectedCategory {
                // Station list for a selected country/genre
                stationListHeader(for: selected)
                Divider()
                stationListBody
            } else {
                // Category browser
                categoryHeader
                Divider()
                categoryBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: mode) {
            await loadCategories()
        }
    }

    // MARK: - Category browser

    private var categoryHeader: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(BrowseMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .onChange(of: mode) { _ in filter = "" }

            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                TextField("Filter…", text: $filter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !filter.isEmpty {
                    Button(action: { filter = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
        }
    }

    @ViewBuilder
    private var categoryBody: some View {
        if isLoadingCategories {
            VStack(spacing: 8) {
                ProgressView().controlSize(.regular)
                Text("Loading \(mode.rawValue.lowercased())…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredCategories.isEmpty {
            Text(filter.isEmpty ? "No \(mode.rawValue.lowercased()) found" : "No matches")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCategories, id: \.name) { item in
                        CategoryRowView(
                            name: item.name,
                            count: item.count,
                            mode: mode
                        ) {
                            selectCategory(item.name)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Station list

    private func stationListHeader(for category: String) -> some View {
        HStack(spacing: 6) {
            Button(action: { withAnimation(.easeInOut(duration: 0.18)) { selectedCategory = nil; stations = [] } }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Text(category)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            Spacer()

            if isLoadingStations {
                ProgressView().controlSize(.small).scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
    }

    @ViewBuilder
    private var stationListBody: some View {
        if isLoadingStations && stations.isEmpty {
            VStack(spacing: 8) {
                ProgressView().controlSize(.regular)
                Text("Loading stations…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = stationError {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else if stations.isEmpty {
            Text("No stations found")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(stations) { station in
                        StationRowView(station: station, showSaveButton: true, showPresetButton: false)
                            .environmentObject(player)
                            .environmentObject(persistence)
                    }
                }
                .padding(.vertical, 4)

                Text("\(stations.count) stations")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Data loading

    private func loadCategories() async {
        isLoadingCategories = true
        categories = []
        do {
            categories = try await (mode == .countries
                ? RadioBrowserAPI.fetchCountries()
                : RadioBrowserAPI.fetchTags())
        } catch {
            // silently leave categories empty
        }
        isLoadingCategories = false
    }

    private func selectCategory(_ name: String) {
        selectedCategory = name
        stations = []
        stationError = nil
        isLoadingStations = true

        Task {
            do {
                let fetched = try await (mode == .countries
                    ? RadioBrowserAPI.fetchStationsByCountry(name)
                    : RadioBrowserAPI.fetchStationsByTag(name))
                stations = fetched.sorted { $0.votes > $1.votes }
            } catch {
                stationError = "Could not load stations."
            }
            isLoadingStations = false
        }
    }
}

// MARK: - Category row

private struct CategoryRowView: View {
    let name: String
    let count: Int
    let mode: BrowseMode
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack {
                if mode == .countries {
                    Text(flagEmoji(for: name))
                        .font(.system(size: 14))
                        .frame(width: 22)
                }

                Text(name.capitalized)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(hovering ? Color.white.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private func flagEmoji(for countryName: String) -> String {
        // Convert country name to ISO code via Locale, then to flag emoji
        let lower = countryName.lowercased()
        let code: String? = Locale.isoRegionCodes.first { code in
            Locale(identifier: "en_US_POSIX").localizedString(forRegionCode: code)?.lowercased() == lower
        }
        guard let iso = code, iso.count == 2 else { return "🌐" }
        let base: UInt32 = 127397
        return iso.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(base + $0.value).map(Character.init)
        }.map(String.init).joined()
    }
}
