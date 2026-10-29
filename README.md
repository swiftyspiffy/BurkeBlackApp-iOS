<p align="center">
  <img src="ios_screenshots/1.1/main.png" width="220" alt="Home Screen" />
</p>

<h1 align="center">The Dirty Skull</h1>

<p align="center">
  The official companion app for <a href="https://twitch.tv/burkeblack">BurkeBlack's</a> Twitch community.
</p>

<p align="center">
  <a href="https://apps.apple.com/us/app/dirty-skull/id6761034588">
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" height="50" />
  </a>
  &nbsp;&nbsp;
  <a href="https://play.google.com/store/apps/details?id=com.swiftyspiffy.burkeblackapp">
    <img src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" alt="Get it on Google Play" height="40" />
  </a>
</p>

<p align="center">
  <a href="https://burkeblack.tv/app/ios/">Website</a> &middot;
  <a href="https://github.com/swiftyspiffy/BurkeBlackApp-Android">Android Repo</a> &middot;
  <a href="https://discord.gg/burkeblack">Discord</a> &middot;
  <a href="https://twitch.tv/burkeblack">Twitch</a>
</p>

---

## What Is This?

**The Dirty Skull** is the official mobile app for [BurkeBlack](https://twitch.tv/burkeblack), a full-time variety streamer on Twitch. It gives his community - The Pirates - a way to stay connected to the stream, participate in events, and manage community features, all from their phone.

Whether you're a long-time crew member or a new viewer, the app gives you everything you need at your fingertips.

## Screenshots

<p align="center">
  <img src="ios_screenshots/1.1/main.png" width="180" alt="Home" />
  <img src="ios_screenshots/1.1/profile.png" width="180" alt="Captain's Quarters" />
  <img src="ios_screenshots/1.1/soundbytes.png" width="180" alt="Soundbytes" />
  <img src="ios_screenshots/1.1/giveaways.png" width="180" alt="Giveaways" />
</p>
<p align="center">
  <img src="ios_screenshots/1.1/clip_voting.png" width="180" alt="Clip Voting" />
  <img src="ios_screenshots/1.1/community_game_servers.png" width="180" alt="Community Servers" />
  <img src="ios_screenshots/1.1/captains_studio.png" width="180" alt="Captain's Studio" />
  <img src="ios_screenshots/1.1/crew.png" width="180" alt="Crew" />
</p>

## Features

- **Live Stream Status** - see when BurkeBlack is live, with a countdown to the next stream. Tap to jump straight to Twitch.
- **Captains** - vote for the next captain, browse the crew, and view election/all-time voter rankings. Election alerts can be minimized and reopened; voting uses your existing Twitch account and voting tokens.
- **Real-Time Giveaways** - enter giveaways directly from the app as they happen on stream. Watch the timer and see who wins.
- **Soundbytes** - browse, preview, and send soundbytes to the stream. Filter by genre, search by name, and track your credits.
- **Your Stats** - track doubloons, donations, bits cheered, subscription history, and giveaway wins all in one place.
- **Badges** - earn badges for being a follower, subscriber, gifter, bits supporter, and donator.
- **Clip Voting** - vote and rank your favorite clips each month.
- **Community Game Servers** - browse community-run game servers with connection details and access requirements.
- **Home Screen Widgets** - crew stats and stream status widgets to keep up at a glance.
- **Mod Panel** - moderators get a full toolkit: manage commands, timed messages, giveaways, soundbytes, and more.

## Download

The app is available for free on the [App Store](https://apps.apple.com/us/app/dirty-skull/id6761034588) and [Google Play](https://play.google.com/store/apps/details?id=com.swiftyspiffy.burkeblackapp).

Having trouble? Use the in-app feedback form (**Account > Send Feedback**) to report issues and include diagnostics.

---

## Contributing

Interested in contributing? Great! Here's how to get started.

This is the **iOS** repository. The Android app lives at [BurkeBlackApp-Android](https://github.com/swiftyspiffy/BurkeBlackApp-Android).

### Requirements

- iOS 17.0+
- Xcode 27.1+ for release builds and native iPhone Duo support
- Swift 5.9+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project file generation)

### Getting Started

```bash
# Clone the repo
git clone https://github.com/swiftyspiffy/BurkeBlackApp-iOS.git
cd BurkeBlackApp

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open BurkeBlackApp.xcodeproj
```

> **Note:** The app communicates with `api.burkeblack.tv` for backend data. Public endpoints (stream status, home data) work without authentication. Features like giveaways, soundbytes, and account stats require a Twitch login.

### Architecture

- **SwiftUI** - fully native UI with `NavigationStack`, `TabView`, and modern SwiftUI patterns
- **MVVM** - ViewModels manage state and business logic
- **Swift Concurrency** - `async`/`await` throughout, `@MainActor` isolation, `actor`-based services
- **WebSocket** - native `URLSessionWebSocketTask` for real-time giveaway events with automatic reconnection
- **WidgetKit** - home screen widgets with App Group data sharing
- **Authentication** - Twitch OAuth via `ASWebAuthenticationSession` with backend token exchange
- **Security** - bearer tokens stored in iOS Keychain, not UserDefaults

### Project Structure

```
BurkeBlackApp/
├── BurkeBlackAppApp.swift          # App entry point
├── Models/
│   └── Models.swift                # Data models
├── Services/
│   ├── APIService.swift            # Public API client
│   ├── TwitchAuthService.swift     # OAuth & authenticated API
│   ├── GiveawayWebSocket.swift     # Real-time WebSocket manager
│   ├── AccountViewModel.swift      # User session & dashboard
│   └── ...                         # Other view models & services
├── Views/
│   ├── ContentView.swift           # Root TabView
│   ├── HomeView.swift              # Stream status & countdown
│   ├── AccountView.swift           # Login & dashboard
│   ├── GiveawayPopupView.swift     # Real-time giveaway overlay
│   ├── ModPanelView.swift          # Moderator tools
│   └── ...                         # Other views
└── Assets.xcassets/                # Icons, images, equipment photos

BurkeBlackWidget/
├── BurkeBlackWidget.swift          # Widget extension (crew stats, stream status)
└── Assets.xcassets/                # Widget assets

BurkeBlackNotificationService/
└── NotificationService.swift       # Rich push notification support
```

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Submit a pull request with a clear description of what you changed and why

For bug reports or feature requests, please [open an issue](https://github.com/swiftyspiffy/BurkeBlackApp-iOS/issues).

---

## Developer

Built by [swiftyspiffy](https://github.com/swiftyspiffy) for the BurkeBlack community.

[Twitch](https://twitch.tv/swiftyspiffy) · [Twitter / X](https://twitter.com/swiftyspiffy) · [GitHub](https://github.com/swiftyspiffy)

## Captains development

Captains is available to everyone in iOS **1.10.0** under **Crew → Captains**. Browsing is public; voting and balances require Twitch sign-in. The extension-only `burkesbooty_captains` rollout flag does not control the app.

**Rigging → Captains** controls automatic election alerts (on by default). Alerts and the minimized pirate-captain circle open the same full Captains screen. Drag the circle to move it out of the way; its position and the selected Captains section are remembered. The app remembers which election has already alerted on this installation. Minimizing, restarting, or refreshing standings does not reopen it. A new election or giveaway alert expands one event at a time.

The app uses the existing `/captain/api/v1/` endpoints and Captains WebSocket on `overlays.burkeblack.tv`. Private operations explicitly renew the mobile bearer session through the Go `/app/auth/renew` endpoint. There is no new login, backend, or token balance. Atomic per-user vote receipts in Application Support preserve the original request ID for manual **Check vote** recovery. No vote is automatically retried.

Run fixture-based core contracts on macOS or Linux with Swift installed:

```bash
bash tests/captains-contract/run.sh
```

This exercises production model, transport, persistence, popup coordination, and ViewModel code without spending live tokens. Native SwiftUI compilation and phone/tablet visual checks still require a Mac. iOS CI remains manual-only on a self-hosted Mac; unavailable or canceled validation is pending, never passing.

Native validation on 2026-10-29 passed all four contract suites, the signed device archive/export, and the simulator Release build. Build 2 additionally passed the manual iPhone simulator UI suite in `tests/captains-ui`: the full-screen election alert, circular control, dragging without opening, saved position across restart, portrait/page scrolling, horizontal crew browsing, section restoration, and rotation bounds. Build 3 also passed edge-drag regression checks on the Duo sidebar layout and on a regular iPhone in portrait and landscape. Full larger-text, theme, sign-in-return, and simultaneous-event visual checks remain pending.

## TestFlight deployment

Reuse the existing Mac Mini's Dirty Skull release scripts, Xcode 27.1, and Fastlane. Stage an exported local commit in an isolated release directory; do not mutate remote Git checkouts. Keep release artifacts, signing configuration, and App Store Connect credentials outside the repository.

Signing runs as a LaunchAgent in the existing GUI session using the configured build keychain and provisioning profiles. An SSH-session identity check can report zero identities while GUI signing works.

Upload with the existing Fastlane `pilot upload` script, then verify processing, export compliance, and membership in the existing internal **Burke Mods** group. Fastlane 2.237.0's `pilot builds` currently requests an unsupported `buildDeliveries` relationship; use its installed Spaceship `ConnectAPI::Build.all` for readback. CI remains manual-only; a successful manual archive does not re-enable automatic builds.
