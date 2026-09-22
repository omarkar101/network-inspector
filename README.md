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
