import SwiftUI

enum BrowserTab: String, CaseIterable {
    case myStations = "My Stations"
    case search = "Find Stations"
}

struct StationBrowserView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    @State private var selectedTab: BrowserTab = .myStations

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(BrowserTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .background(
                        selectedTab == tab
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                    )
                }
                Spacer()
            }
            .background(Color.white.opacity(0.03))

            Divider()

            // Both tabs stay in the hierarchy to preserve state (search results, scroll position)
            ZStack {
                StationListView()
                    .environmentObject(player)
                    .environmentObject(persistence)
                    .opacity(selectedTab == .myStations ? 1 : 0)
                    .allowsHitTesting(selectedTab == .myStations)

                SearchView(isActive: selectedTab == .search)
                    .environmentObject(player)
                    .environmentObject(persistence)
                    .opacity(selectedTab == .search ? 1 : 0)
                    .allowsHitTesting(selectedTab == .search)
            }
        }
    }
}
