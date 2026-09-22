# Network Inspector

A SwiftUI iOS app scaffold for browsing captured HTTP request/response traffic.

The project is split in two:

- **`NetworkInspectorKit`** — a Swift Package containing all of the real logic
  (models, status-code classification, formatting, search/filtering, per-app
  traffic aggregation and ranking, and a seeded live-traffic generator). It has
  no UIKit/SwiftUI dependency, so it builds and its test suite runs on Linux as
  well as macOS.
- **`NetworkInspector`** — a thin SwiftUI app target (app lifecycle, views,
  assets) that imports `NetworkInspectorKit`. It has two tabs:
  - **Apps** — a live dashboard with totals (throughput, active apps,
    download and upload speed, data, error rate) and a ranked list of apps
    with sparklines and live ↓/↑ speeds. The list can be sorted by live
    activity, requests, speed, data, errors, latency or name, and reorders as
    traffic arrives. Tap an app to see its requests.
  - **Requests** — a searchable, status-filterable list of every request,
    with each one's download (and upload) speed.

  Sizes are always shown starting at KB, stepping up to MB then GB
  (e.g. "0.5 KB", "850 KB", "2.4 MB", "1.1 GB"); speeds use the same units
  per second.

  Traffic is simulated by `LiveTrafficGenerator` until real capture exists.

## Turning off an app's internet access

Any app can be cut off from the network (Wi‑Fi and cellular): long-press it
on the dashboard, use the Wi‑Fi button on its request list, or open
*Options ▸ Internet Access…* to manage the list and block any installed app
by bundle identifier.

This is done with a Network Extension **content filter**. The
`NetworkInspectorFilterData` extension sees every new socket flow along with
its source app's signing identifier and drops the flows of blocked apps; the
list reaches it through the filter's vendor configuration
(`AppBlocklist` in the package holds the matching logic). iOS has no other
public API for per-app network blocking.

Apple restricts where third-party content filters run:

- The Network Extension capability needs a **paid Apple Developer Program**
  team. Free Personal Teams can't sign the filter extensions.
- On an ordinary iPhone the filter only runs in **development-signed builds**
  installed from Xcode (the normal device-install flow below).
- **Supervised (MDM) devices** can also run it from distribution builds.

TestFlight and App Store builds on an ordinary iPhone can't install the
filter. On first use iOS asks to allow the app to filter network content; the
filter can also be turned off under Settings ▸ General ▸ VPN & Device
Management. The simulated feed mirrors the setting by dropping blocked apps'
requests.

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
NetworkInspectorFilterData/  Content filter data provider extension (drops blocked apps' flows)
NetworkInspectorFilterControl/ Content filter control provider extension (required, no-op)
NetworkInspectorKit/         Swift Package with all logic + Swift Testing suite
project.yml                  XcodeGen spec that wires the app target to the local package
.github/workflows/ci.yml     CI: generates the project, builds for a simulator, runs Kit tests
```

## Running on a physical iPhone (free Apple ID)

A free Apple ID is enough to run the app on your own device. Builds signed this
way expire after 7 days and must be re-installed from Xcode. Turning off an
app's internet access needs a paid team (see above); with a free team, remove
the two filter extensions from the app target's dependencies in `project.yml`
and the `NetworkInspector.entitlements` setting to sign.

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
