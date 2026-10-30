import SwiftUI

@main
struct GoTravelNhaApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .tint(Brand.primary)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        TabView(selection: Binding(get: { state.tab }, set: select)) {
            NavigationStack { ExploreView() }
                .tabItem { Label(L("tab_explore"), systemImage: "house") }
                .tag(AppTab.explore)
            NavigationStack { CommunityView() }
                .tabItem { Label(L("tab_community"), systemImage: "person.2") }
                .tag(AppTab.community)
            NavigationStack { PlannerView() }
                .tabItem { Label(L("tab_planner"), systemImage: "sparkles") }
                .tag(AppTab.planner)
            NavigationStack { TripsView() }
                .tabItem { Label(L("tab_trips"), systemImage: "suitcase") }
                .tag(AppTab.trips)
            NavigationStack { ProfileView() }
                .tabItem { Label(L("tab_profile"), systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .task(id: state.signedIn) { await state.refreshUser() }
        // My Trips needs an account: leave it when the session ends
        .onChange(of: state.signedIn) { _, signedIn in
            if !signedIn && state.tab == .trips { state.tab = .explore }
        }
        .alert(L("signin_failed"), isPresented: Binding(get: { state.authError != nil }, set: { if !$0 { state.authError = nil } })) {
            Button(L("action_ok")) { state.authError = nil }
        } message: {
            Text(state.authError ?? "")
        }
    }

    private func select(_ tab: AppTab) {
        if tab == .trips && !state.signedIn {
            state.signIn(then: .trips)
        } else {
            state.tab = tab
        }
    }
}
