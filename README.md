# Network Inspector

A SwiftUI iOS app scaffold for browsing captured HTTP request/response traffic.

The project is split in two:

- **`NetworkInspectorKit`** — a Swift Package containing all of the real logic
  (models, status-code classification, duration/byte-size formatting, and
  search/filtering over a list of captured entries). It has no UIKit/SwiftUI
  dependency, so it builds and its test suite runs on Linux as well as macOS.
- **`NetworkInspector`** — a thin SwiftUI app target (app lifecycle, views,
  assets) that imports `NetworkInspectorKit` and renders a searchable list of
  sample captured requests.

## Prerequisites

- Xcode 27 (iOS 26 SDK), Swift 6 language mode with strict concurrency.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj`
  from `project.yml` (the project file itself is not checked in):

  ```sh
  brew install xcodegen
  ```

## Generate & open the project

```sh
xcodegen generate
open NetworkInspector.xcodeproj
```

Then build/run the `NetworkInspector` scheme on an iOS 26 simulator or device.

## Running tests

The package's Swift Testing suite can be run directly, without Xcode:

```sh
cd NetworkInspectorKit
swift test
```

It can also be run from Xcode via the `NetworkInspector` scheme once the
project has been generated, since the app target depends on the package as a
local Swift Package dependency.

## Project layout

```
NetworkInspector/            App target sources (SwiftUI views, app entry point, assets)
NetworkInspectorKit/         Swift Package with all logic + Swift Testing suite
project.yml                  XcodeGen spec that wires the app target to the local package
.github/workflows/ci.yml     CI: generates the project, builds for a simulator, runs Kit tests
```

## Running on a physical iPhone (free Apple ID)

A free Apple ID is enough to run the app on your own device. Builds signed this
way expire after 7 days and must be re-installed from Xcode.

1. **Add your Apple ID** — Xcode ▸ Settings ▸ Accounts ▸ `+` ▸ Apple ID.
2. **Find your team ID** — Xcode's Accounts pane lists your personal team as
   "<Your Name> (Personal Team)" but does not display its ID. First create a
   signing certificate (Accounts ▸ *Manage Certificates…* ▸ `+` ▸ Apple
   Development), then read the ID from the certificate's `OU` field:
   ```sh
   security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
   ```
   It is a 10-character string like `A1B2C3D4E5`.
3. **Generate the project with your team:**
   ```sh
   export DEVELOPMENT_TEAM=A1B2C3D4E5   # your ID from step 2
   xcodegen generate
   open NetworkInspector.xcodeproj
   ```
   Keeping this in an env var means no personal team ID is committed.
4. **Enable Developer Mode on the iPhone** (iOS 16+) — Settings ▸ Privacy &
   Security ▸ Developer Mode ▸ on, then reboot. The option only appears after
   the device has been connected to Xcode at least once.
5. **Build to the device** — connect over USB, pick the iPhone in Xcode's
   destination menu, press Run (⌘R).
6. **Trust the developer** — the first launch fails with "Untrusted Developer".
   On the iPhone: Settings ▸ General ▸ VPN & Device Management ▸ tap your Apple
   ID ▸ Trust.

### Free-account limits

- Builds stop launching after **7 days**; re-run from Xcode to renew.
- Max 3 apps installed per device at once, and at most 10 new App IDs
  (bundle identifiers) per 7 days.
- No TestFlight and no over-the-air install — those need the paid
  Apple Developer Program ($99/yr).
- If the bundle identifier collides with an existing app, change
  `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to something unique.
