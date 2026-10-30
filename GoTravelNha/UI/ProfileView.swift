import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        List {
            Section {
                if state.signedIn {
                    HStack(spacing: 12) {
                        Avatar(name: state.user?.displayName ?? "?", url: nil, size: 52)
                        VStack(alignment: .leading) {
                            Text(state.user?.displayName ?? L("profile_loading")).font(.headline)
                            if let email = state.user?.email { Text(email).font(.subheadline).foregroundStyle(.secondary) }
                        }
                    }
                    Button(L("profile_manage_account")) { openInBrowser(Config.oidcIssuer.appendingPathComponent("account").absoluteString) }
                    Button(L("action_sign_out"), role: .destructive) { state.signOut() }
                } else {
                    Text(L("profile_signed_out")).foregroundStyle(.secondary)
                    Button(L("action_sign_in")) { state.signIn() }
                    Button(L("action_register")) { state.signIn(register: true) }
                }
            }
            Section(L("profile_partners")) {
                Button(L("profile_trip_hotels")) {
                    state.openPartner(provider: "trip", url: "https://www.trip.com/hotels/?locale=en-SG&curr=SGD", placement: "app_profile_partner", screen: "profile")
                }
                Button(L("profile_klook_activities")) {
                    state.openPartner(provider: "klook", url: "https://www.klook.com/\(klookLocalePath(appLanguage()))/", placement: "app_profile_partner", screen: "profile")
                }
            }
            Section {
                // iOS: per-app language lives in the app's page in Settings
                Button(L("profile_language")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Button(L("profile_help")) { openInBrowser(site("help")) }
                Button(L("profile_privacy")) { openInBrowser(site("privacy")) }
                Button(L("profile_terms")) { openInBrowser(site("terms")) }
                Button(L("profile_website")) { openInBrowser(Config.siteURL.absoluteString) }
            } footer: {
                Text(L("profile_version", Config.appVersion))
            }
        }
        .navigationTitle(L("tab_profile"))
    }

    private func site(_ path: String) -> String { Config.siteURL.appendingPathComponent(path).absoluteString }
}
