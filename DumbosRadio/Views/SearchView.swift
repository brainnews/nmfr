import SwiftUI

struct SearchView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    let isActive: Bool

    @State private var query = ""
    @State private var results: [Station] = []
    @State private var isSearching = false
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?

    @State private var topStations: [Station] = []
    @State private var isLoadingTop = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))

                TextField("Search by station name or genre…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isFocused)
                    .onSubmit { performSearch() }

                if !query.isEmpty {
                    Button(action: {
                        query = ""
                        results = []
                        error = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))

            Divider()

            // Results
            if let error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if !results.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(results) { station in
                            StationRowView(station: station, showSaveButton: true, showPresetButton: false)
                                .environmentObject(player)
                                .environmentObject(persistence)
                        }
                    }
                    .padding(.vertical, 4)

                    Text(results.count == 1 ? "1 result" : "\(results.count) results")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 8)
                }
            } else if !query.isEmpty && !isSearching {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No results for \"\(query)\"")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if query.isEmpty {
                // Empty state: show trending stations once loaded
                if isLoadingTop {
                    VStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Loading trending stations…")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !topStations.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Trending")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.top, 8)
                                .padding(.bottom, 2)

                            LazyVStack(spacing: 2) {
                                ForEach(topStations) { station in
                                    StationRowView(station: station, showSaveButton: true, showPresetButton: false)
                                        .environmentObject(player)
                                        .environmentObject(persistence)
                                }
                            }
                            .padding(.vertical, 4)

                            Text("Powered by radio-browser.info")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 8)
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                        Text("Search by station name or genre")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("Powered by radio-browser.info")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            guard topStations.isEmpty && !isLoadingTop else { return }
            isLoadingTop = true
            topStations = (try? await RadioBrowserAPI.fetchTopStations()) ?? []
            isLoadingTop = false
        }
        .onChange(of: query) { newValue in
            scheduleSearch(newValue)
        }
        .onChange(of: isActive) { active in
            if active { isFocused = true }
        }
    }

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            error = nil
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await performSearchAsync(text)
        }
    }

    private func performSearch() {
        searchTask?.cancel()
        Task { await performSearchAsync(query) }
    }

    @MainActor
    private func performSearchAsync(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        error = nil

        do {
            results = try await RadioBrowserAPI.searchStations(query: trimmed)
        } catch {
            if !Task.isCancelled {
                self.error = "Search failed: \(error.localizedDescription)"
                results = []
            }
        }

        isSearching = false
    }
}
