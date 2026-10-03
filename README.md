# Network Inspector

A SwiftUI iOS app that shows which apps on the iPhone use the network (for
example WhatsApp, Safari or Instagram), what they connect to, and how much
data they move. It can also cut any app off from the internet.

The project is split in two:

- **`NetworkInspectorKit`** — a Swift Package containing all of the real logic
  (models, the capture journal, app naming, status-code classification,
  formatting, search/filtering, per-app traffic aggregation and ranking, and
  a seeded demo-traffic generator). It has no UIKit/SwiftUI dependency, so it
  builds and its test suite runs on Linux as well as macOS.
- **`NetworkInspector`** — a thin SwiftUI app target (app lifecycle, views,
  assets) that imports `NetworkInspectorKit`. It has two tabs:
  - **Apps** — a live dashboard with totals (throughput, active apps,
    download and upload speed, data, blocked share) and a ranked list of
    apps, by name and icon, with sparklines and live ↓/↑ speeds. The list
    can be sorted by live activity, connections, speed, data, blocked,
    duration or name, and reorders as traffic arrives. Tap an app to see its
    connections.
  - **Connections** — a searchable list of every connection captured on the
    device: app, remote host and port, TCP/UDP, open/closed/blocked, how long
    it lasted and the bytes it moved.

  Sizes are always shown starting at KB, stepping up to MB then GB
  (e.g. "0.5 KB", "850 KB", "2.4 MB", "1.1 GB"); speeds use the same units
  per second.

  *Options ▸ Show Demo Traffic* switches to a simulated feed of made-up apps
  (`LiveTrafficGenerator`). There the second tab lists HTTP requests instead.

## Seeing which apps use the network

iOS doesn't let an app watch other apps' traffic. The one public API that
says which app opened a connection is a Network Extension **content filter**,
the same one used to turn apps' internet off (see below), so capture has the
same requirements: a paid developer team and a development-signed build on a
physical iPhone (or a supervised device). It doesn't work in the simulator.

Tap **Start Capturing** on the dashboard (or *Options ▸ Start Capturing*) and
allow the "Filter Network Content" prompt. From then on:

1. The `NetworkInspectorFilterData` extension sees each new connection and
   asks the system to report it, both when it opens and when it closes.
   Its sandbox can't write anywhere, so it can't pass flows on by itself.
2. The system delivers the reports to the `NetworkInspectorFilterControl`
   extension, which appends them to a journal file (`FlowJournal`) in the
   app group container `group.com.omarkar.networkinspector`.
3. The app follows that file and assembles the events into connections
   (`ConnectionLog`).

The filter keeps running while the app is closed, so traffic from then shows
up the next time the app opens. The journal keeps the most recent few MB.

What is and isn't visible:

- Every connection's app, remote host (the hostname when the app connected
  by name, otherwise the IP address), port, protocol, and open and close
  times.
- Bytes sent and received, but only once a connection **closes**. Long-lived
  connections, such as a messenger's chat socket, show their data when they
  end.
- No URLs, paths, HTTP methods, status codes or content. Almost all traffic
  is encrypted, and the filter only sees connections.
- Some traffic is made by iOS on an app's behalf and shows up under a system
  service, e.g. "Background Transfers" or "Push Notifications".

Apps are named, in order of preference, from:

1. A built-in list of popular apps and iOS services (`KnownApps`), e.g.
   `net.whatsapp.WhatsApp` → "WhatsApp".
2. The App Store. The app asks Apple's iTunes Lookup API for the name and
   icon of each app it sees (sending only the bundle ID), one at a time, and
   caches the answers. Apple's built-in apps aren't looked up.
3. The bundle ID itself, e.g. `com.example.coolgame.ios` → "Coolgame".

App extensions are named after their app, e.g. "WhatsApp (ServiceExtension)".

If you change the bundle ID prefix, also change the app group in
`FlowJournal.appGroupIdentifier` and in the app and filter control
entitlements.

## Turning off an app's internet access

Any app can be cut off from the network (Wi‑Fi and cellular): long-press it
on the dashboard, use the Wi‑Fi button on its connection list, or open
*Options ▸ Internet Access…* to manage the list and block any installed app
by bundle identifier.

This is done with a Network Extension **content filter**. The
`NetworkInspectorFilterData` extension sees every new socket flow along with
its source app's signing identifier and drops the flows of blocked apps; the
list reaches it through the filter's vendor configuration
(`FilterSettings` and `AppBlocklist` in the package hold the encoding and
matching logic). iOS has no other public API for per-app network blocking.
The filter runs while any app is blocked or traffic capture is on.

Apple restricts where third-party content filters run:

- The Network Extension capability needs a **paid Apple Developer Program**
  team. Free Personal Teams can't sign the filter extensions.
- On an ordinary iPhone the filter only runs in **development-signed builds**
  installed from Xcode (the normal device-install flow below).
- **Supervised (MDM) devices** can also run it from distribution builds.

TestFlight and App Store builds on an ordinary iPhone can't install the
filter. On first use iOS asks to allow the app to filter network content; the
filter can also be turned off under Settings ▸ General ▸ VPN & Device
Management. Blocked apps show a red Wi‑Fi slash while the filter is running
and an orange Wi‑Fi warning when it isn't (their traffic still flows). The
simulated feed mirrors the setting by dropping blocked apps' requests.

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
NetworkInspectorFilterData/  Content filter data provider extension (drops blocked apps' flows, reports flows while capturing)
NetworkInspectorFilterControl/ Content filter control provider extension (writes reported flows to the shared journal)
NetworkInspectorKit/         Swift Package with all logic + Swift Testing suite
project.yml                  XcodeGen spec that wires the app target to the local package
.github/workflows/ci.yml     CI: generates the project, builds for a simulator, runs Kit tests
```

## Running on a physical iPhone (free Apple ID)

A free Apple ID is enough to run the app on your own device. Builds signed this
way expire after 7 days and must be re-installed from Xcode. Turning off an
app's internet access and seeing real traffic by app both need a paid team
(see above). With a free team, generate from `project.personal.yml` instead,
which leaves out the two filter extensions and the app's entitlements
(step 3); the app then only shows demo traffic. Otherwise signing fails with
"Personal development teams … do not support the Network Extensions
capability".

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
   xcodegen generate --spec project.personal.yml   # free team
   # xcodegen generate                             # paid team
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

## Manual checks (can't run in remote sessions)

Code in this repo is mostly written from remote Linux sessions, which have no
Xcode, no simulator and no iPhone, and can't download the Swift toolchain. So
none of the steps below have run there. Run them on a Mac after pulling a
change, and report failures back (or paste the error output).

CI is the only automatic check, and it runs only on pull requests and pushes
to `master`, not on plain branch pushes. Open a PR to get a build.

### Every change

1. Run the package tests:
   ```sh
   cd NetworkInspectorKit && swift test
   ```
2. Build the app for the simulator:
   ```sh
   xcodegen generate
   xcodebuild -project NetworkInspector.xcodeproj -scheme NetworkInspector \
     -destination "generic/platform=iOS Simulator" build
   ```

### Internet toggle (content filter)

Needs a paid team in `DEVELOPMENT_TEAM` and a physical iPhone. The simulator
can't run content filters; there the Internet Access sheet should show
"Filter unavailable".

1. Generate with your paid team, then run on the iPhone from Xcode
   (see "Running on a physical iPhone"). Signing must succeed for all three
   targets: `NetworkInspector`, `NetworkInspectorFilterData` and
   `NetworkInspectorFilterControl`. If Xcode complains about the Network
   Extensions capability, enable it for the three App IDs in the developer
   portal, or let automatic signing do it.
2. Open *Options ▸ Internet Access…*, enter the bundle ID of a real
   installed app (for example `com.apple.mobilesafari` for Safari), tap
   **Block**, and allow the "Filter Network Content" prompt. Status should
   read "Filter active".
3. Open that app: pages should fail to load on both Wi‑Fi and cellular.
   Other apps should still work.
4. Swipe the entry away (**Allow**) and check the app gets internet back.
   With no apps blocked, the filter should turn off.
5. Block an app again, then turn the filter off in Settings ▸ General ▸ VPN &
   Device Management and return to the app. The blocked app's icon should
   turn from a red Wi‑Fi slash to an orange Wi‑Fi warning, and the sheet
   should read "Filter off" with a **Turn On Filter** button that restores
   it. Denying the first permission prompt should also show orange, not red.
6. If blocking has no effect, the filter probably reports app IDs in a format
   `AppBlocklist.blocks(sourceAppIdentifier:)` doesn't match. Log
   `flow.sourceAppIdentifier` in `FilterDataProvider.handleNewFlow` and view
   the output in Console.app, filtered to the filter extension's process.

### Traffic capture (real apps by name)

Same setup as above: a paid team and a physical iPhone. Signing must also
succeed for the **App Groups** capability on `NetworkInspector` and
`NetworkInspectorFilterControl` (automatic signing registers
`group.com.omarkar.networkinspector`; if it can't, add the group in the
developer portal and enable it for both App IDs). In the simulator, **Start
Capturing** should end in "Capture Unavailable" with a **Show Demo Traffic**
button. In a free Apple ID build (`project.personal.yml`) it should say the
build doesn't include the content filter, without any permission prompt.

1. Launch the app. The dashboard should say "See Which Apps Use the Network"
   with a **Start Capturing** button, and no made-up apps (Courier, Frame…).
2. Tap **Start Capturing** and allow the prompt. The toolbar should read
   "Live" and the dashboard "Waiting for Traffic".
3. Open WhatsApp (or any app), use it for a few seconds, and come back.
   "WhatsApp" should be listed by name; its real icon should replace the
   glyph within a few seconds (App Store lookup). Other apps and iOS services
   (e.g. "Push Notifications", "DNS") may show up too.
4. Tap WhatsApp: its connections should list hosts such as
   `g.whatsapp.net:443` or `*.whatsapp.net`, marked Open or Closed. Closed
   ones show ↓/↑ bytes. Force-quit WhatsApp to close its connections and
   check that the Data sort then shows its bytes.
5. Open the **Connections** tab: every app's connections, newest first.
   Search for a hostname or app name, and filter by Open/Closed/Blocked.
6. Block an app (long-press ▸ Turn Internet Off), then use it: its new
   connections should appear as **Blocked**.
7. Leave the app, use other apps for a minute, return: their traffic from
   that time should be listed.
8. *Options ▸ Stop Capturing*: the toolbar should read "Not Capturing". With
   no apps blocked, the filter should turn off (Settings ▸ General ▸ VPN &
   Device Management).
9. *Options ▸ Show Demo Traffic* switches to the simulated apps and a
   **Requests** tab; *Show Device Traffic* switches back.
10. If apps never show up while "Live", find where the chain breaks with
    logs viewed in Console.app: in `FilterControlProvider.handle(_:)`, log
    `report.flow?.sourceAppIdentifier` (do reports arrive?) and whether
    `journal` is nil (is the app group available?), and log the error that
    `FlowJournalWriter.append` swallows (can it write?).
