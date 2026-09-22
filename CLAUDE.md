# CLAUDE.md

SwiftUI iOS app for browsing captured HTTP request/response traffic. See
`README.md` for full setup, build and device-install steps.

## Layout

- `NetworkInspectorKit/` — Swift Package with all logic (models, status
  classification, formatting, search/filtering) and its Swift Testing suite.
  No UIKit/SwiftUI imports, so it stays buildable and testable on Linux.
- `NetworkInspector/` — thin SwiftUI app target that imports the package.
- `NetworkInspectorFilterData/`, `NetworkInspectorFilterControl/` — Network
  Extension content filter extensions that cut blocked apps off the network
  (per-app "turn internet off"). Needs the `content-filter-provider`
  entitlement, i.e. a paid team; only runs in dev-signed builds or on
  supervised devices.
- `project.yml` — XcodeGen spec. The `.xcodeproj` is generated, never committed.
- `.github/workflows/ci.yml` — macOS runner: `xcodegen generate`, simulator
  build, `swift test` in the package. Runs on pushes to `master` and on PRs.

## Conventions

- iOS 26 deployment target, Swift 6 language mode, strict concurrency `complete`.
- Put new logic in `NetworkInspectorKit` with tests; keep the app target to views.
- Signing: `DEVELOPMENT_TEAM` comes from the env var at `xcodegen generate`
  time. Never commit a team ID. Simulator/CI builds don't sign.
- Bundle ID: `com.omarkar.networkinspector`.

## Working in remote (Linux) sessions

- There is no Xcode, and Swift/XcodeGen may not be installed, so app builds
  can't be verified here — CI on GitHub is the check. If `swift` is available,
  run `cd NetworkInspectorKit && swift test`.
- Active development branch: `claude/swift-ios-app-init-ldhw95` (default
  branch is `master`).

## Device install

- With a Mac: run from Xcode (README "Running on a physical iPhone"). Free
  Apple ID installs expire after 7 days; paid accounts last about a year.
  Wireless install works after the first USB pairing.
- Without a Mac: needs the paid Developer Program plus a TestFlight upload
  workflow (App Store Connect API key with Admin role for cloud signing,
  auto-incremented build number, `ITSAppUsesNonExemptEncryption = NO`).
  Not implemented yet.
