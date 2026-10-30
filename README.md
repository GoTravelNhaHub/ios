# GoTravelNha for iOS

Swift + SwiftUI, iOS 17+, no third-party packages. Bundle id `com.gotravelnha.app`. Open `GoTravelNha.xcodeproj`
in Xcode 26 (folders are synchronized groups: new files under `GoTravelNha/` join the target automatically).

Talks to the same API as www (`../../backend`, api.gotravelnha.com) and signs in through Keycloak
(`../../keycloak`, public client `gotravelnha-mobile`, callback scheme `com.gotravelnha.app`).

- Run: pick a simulator or device, set your team under Signing & Capabilities, ⌘R. Tests: ⌘U.
- Local backend and Keycloak: Edit Scheme → Run → Arguments, add
  `-GTNApiBaseURL http://localhost:3002 -GTNOidcIssuer http://localhost:8080/realms/gotravelnha`
  (read through UserDefaults in `App/Config.swift`; production is the default).

## Layout (`GoTravelNha/`)

| Path | Role |
| --- | --- |
| `App/` | `@main` app and tab bar, `AppState` (user, tab hand-offs, booking actions), `Config` (URLs, `L()` for strings) |
| `Auth/` | `ASWebAuthenticationSession` + PKCE against Keycloak, `offline_access` refresh token in the Keychain |
| `Data/APIClient.swift` | URLSession; Bearer token, one refresh-and-retry on 401; every endpoint |
| `Data/Models.swift`, `LenientDecoding.swift` | Response shapes (mirror `web/types`); stored itineraries decode with defaults for missing fields |
| `Booking/Booking.swift` | Port of `web/utils/community-booking.ts` (also in the Android app). Partner-links answers are keyed by `klookQuery()` |
| `Booking/PartnerLauncher.swift` | Partner links go through `POST /api/affiliate/click`, opened in an in-app Safari sheet |
| `UI/` | Home, Community, AI Planner, My Trips (plans + saved), Profile; trip detail, trip map (MapKit), saved plan |

Strings: `Localizable.xcstrings` (en, vi, zh-Hans), generated from the same table as the Android `strings.xml`.
