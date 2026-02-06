import SwiftUI

struct RootView: View {
    enum Tab: Hashable {
        case home
        case stats
        case calendar
        case settings
    }

    @State private var selectedTab: Tab = .home
    @State private var selectedMonth = Date()
    @State private var showingAddSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(month: $selectedMonth)
                    .tabItem {
                        Label("明细", systemImage: "list.bullet")
                    }
                    .tag(Tab.home)

                StatsView(month: $selectedMonth)
                    .tabItem {
                        Label("图表", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(Tab.stats)

                CalendarView(month: $selectedMonth)
                    .tabItem {
                        Label("日历", systemImage: "calendar")
                    }
                    .tag(Tab.calendar)

                SettingsView()
                    .tabItem {
                        Label("我的", systemImage: "person.circle")
                    }
                    .tag(Tab.settings)
            }

            AddFloatingButton {
                showingAddSheet = true
            }
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTransactionSheet()
        }
    }
}

private struct AddFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 56, height: 56)
                .background(Color("PrimaryYellow"))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
        .accessibilityLabel("记账")
    }
}
