import SwiftUI

enum BrowserTab: String, CaseIterable {
    case myStations = "My Stations"
    case search = "Find Stations"
}

struct StationBrowserView: View {
    @EnvironmentObject var player: RadioPlayer
    @EnvironmentObject var persistence: PersistenceManager

    @State private var selectedTab: BrowserTab = .myStations
    @Namespace private var tabNamespace

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar — active background slides between tabs via matchedGeometryEffect
            HStack(spacing: 0) {
                ForEach(BrowserTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    }) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                            .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                    .buttonStyle(.plain)
                    .background {
                        if selectedTab == tab {
                            Color.accentColor.opacity(0.1)
                                .matchedGeometryEffect(id: "tabBG", in: tabNamespace)
                        }
                    }
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
