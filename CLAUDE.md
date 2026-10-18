# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Romo iOS SDK: an Objective-C (plus some Objective-C++/C++) library for controlling Romotive's discontinued Romo robot from an iPhone. Romotive open-sourced it, and Navideck maintains this continuation. It ships as a CocoaPod, `Romo` (`Romo.podspec`), with four subspecs, and as a Swift package (`Package.swift`) with RMShared, RMCore and RMCharacter only. Each subspec is a top-level directory:

| Subspec | Purpose | Depends on |
|---|---|---|
| `RMShared` | Math (quaternions, circle math), ring buffer, dispatch timer, logging, web socket | CocoaLumberjack, SocketRocket |
| `RMCore` (default subspec) | Hardware control: motors, head tilt, LEDs, IMU, stasis/bump sensing, firmware update | RMShared |
| `RMCharacter` | Romo's animated face, emotions/expressions, voice | RMShared, assets |
| `RMVision` | Camera-based computer vision | RMShared, GPUImage, OpenCV ~> 2.0 |

Each subspec directory contains `Classes/` (the source globbed by the podspec), optional `Assets/`, and `Examples/` (sample apps).

### CocoaPods and SwiftPM share the same sources
Every change to RMShared, RMCore or RMCharacter has to keep building under both:
- **Public headers** live in `<Module>/Classes/include/Romo/`. Only headers reachable from the umbrella headers (`RMShared.h`, `RMCore.h`, `RMCharacter.h`) or imported across modules belong there; everything else, including `*_Internal.h`, stays private next to its `.m`. CocoaPods flattens all headers into `Romo/`, so it doesn't care where they live.
- **Imports**: within a module use quoted imports (`"RMCoreMotor.h"`). Across modules use `<Romo/RMMath.h>`, and the imported header must be public in its module. A new private header directory needs a `.headerSearchPath` in `Package.swift`.
- **Prefix headers** (`*-Prefix.pch`) are used by neither CocoaPods nor SwiftPM. Import what each file needs explicitly.
- **CocoaLumberjack**'s SwiftPM package has no `CocoaLumberjack/CocoaLumberjack.h` umbrella; see the `__has_include` fallback in `RMLogFormatter.h`. Each SwiftPM target that includes `RMShared.h` must depend on CocoaLumberjack directly.
- **SocketRocket** doesn't support SwiftPM, so `Package.swift` excludes `RMWebSocket` and `RMWebSocketLogger`, and `RMShared.h` only imports the logger when `__has_include` finds it.
- **RMCharacter resources**: CocoaPods copies `Media.xcassets` files loose into the app's main bundle. SwiftPM compiles the catalog into the module's resource bundle. Code that loads assets branches on `#ifdef SWIFTPM_MODULE_BUNDLE`, using `imageNamed:inBundle:` and `NSDataAsset` under SwiftPM.

## Building / Testing

The repo has no top-level Xcode project, build script, linter, or CI. To build or exercise the code, use the example apps. Each one has a `Podfile` that points at the local podspec (`pod 'Romo', path: '../../..'`):

```sh
cd RMCore/Examples/HelloRMCore    # or any other Examples/* dir
pod install
open HelloRMCore.xcworkspace      # always the .xcworkspace, not the .xcodeproj
```

Example apps: `RMCore/Examples/{HelloRMCore, HelloRMCoreSwift, HelloRomo, RMCoreTest}`, `RMCharacter/Examples/{HelloRMCharacter, HelloRomo}`, `RMVision/Examples/{HelloRMVision, RMVisionSample}`, `RMShared/Examples/HelloRMShared`.

The only XCTest targets are in RMVision: `RMVisionSample` (targets `RMVisionSampleTests` and `RMVisionBenchmarks`) and `HelloRMVision/HelloRMVisionTests`. To run them from the command line:

```sh
xcodebuild test -workspace RMVision/Examples/RMVisionSample/RMVisionSample.xcworkspace \
  -scheme RMVisionSampleTests -destination 'platform=iOS Simulator,name=<device>'
# single test: add -only-testing:RMVisionSampleTests/RMVisionTests/<testMethod>
```

To build the Swift package (there is no macOS support, so `swift build` doesn't work; use xcodebuild from the repo root):

```sh
xcodebuild build -scheme Romo-Package -destination 'generic/platform=iOS Simulator'
```

The package has no test targets. To exercise it at runtime, depend on it from a scratch package by local path and run that package's tests on a simulator. Xcode 27's test runner needs an iOS 17+ simulator.

To validate the podspec, run `pod lib lint Romo.podspec`. The podspec excludes `arm64` for simulator builds, so simulator runs use x86_64/Rosetta. Real robot I/O only works on a physical device docked in a Romo. For hardware-free testing, use `+[RMCore connectToSimulatedRobot]`.

## Releases

- Bump `spec.version` in `Romo.podspec`.
- Add an entry to `VERSIONS.md`, with bullets prefixed by the component (`**RMCore**:`, `**POD**:`, etc.).
- Git tags must be `Romo_v<version>`, because the podspec source uses `:tag => "Romo_v#{spec.version}"`. SwiftPM only resolves plain semver tags (`0.5.3`), so a release needs both tags for SwiftPM users to depend on a version.
- `docs/` holds prebuilt Doxygen HTML and a docset. It is not regenerated automatically.

## Architecture

### RMCore connection & communication stack
- `RMCore` (`RMCore/Classes/RMCore.m`) is a singleton-style entry point with class methods (`setDelegate:`, `allowBackground:`, `connectedRobots`). It owns an `RMCoreRobotDataTransport` and listens to it as an `RMCoreRobotConnectionDelegate`.
- `RMCoreRobotDataTransport` (`Communication/`) wraps ExternalAccessory: it watches `EAAccessoryDidConnect/DisconnectNotification` for protocol `com.romotive.romo` and handles the NSStream session. It reads the firmware version and sets `usesOldProtocol` (firmware < 1.2).
- When a connection happens, `RMCore` creates an `RMCoreRobotRomo3`. Based on `usesOldProtocol`, the robot picks either `RMCoreRobotCommunication` or `RMCoreRobotCommunicationOld`. Both implement `RobotCommunicationProtocol`, so changes to the serial protocol usually have to be made in both.
- `Communication/FirmwareCommon/*.h` holds C headers for the wire protocol (`SerialProtocol.h`, `Romo3Defs.h`, LED/motor/device modes). They are shared with the firmware repo (Navideck/Romo-Firmware), so keep them in sync. `FirmwareUpdate/` implements STK500 programming from Intel HEX images.

### Robot capability protocols
- `RMCoreRobot` is the base class. Its capabilities are expressed as protocols: `DriveProtocol`, `DifferentialDriveProtocol`, `HeadTiltProtocol`, `LEDProtocol`, and `RobotMotionProtocol` (public, in `include/Romo/`), plus `HolonomicDriveProtocol` (private, in `Robot/Functionality/`).
- `RMCoreRobotRomo3` is the only concrete robot. Client code casts to `RMCoreRobot<HeadTiltProtocol, DriveProtocol, LEDProtocol>` after checking `isDrivable` / `isHeadTiltable` / `isLEDEquipped`.
- Actuation (`RMCoreMotor`, `RMCoreDifferentialDrive`, `RMCoreDriveController`, `RMCoreHeadTilt`) is built on the PID and DSP utilities in `Utilities/`. Sensing (`Inertial/`, `Stasis/`, `Bump/`) fuses device and platform IMU data.
- `*_Internal.h` headers expose private API between RMCore classes. Don't make them public.

### RMVision module system
- `RMVision` (`.mm`) runs the camera capture pipeline and sends each frame, as a `cv::Mat`, to every active module that conforms to `RMVisionModuleProtocol` (`activateModule:` / `activateModuleWithName:`).
- Modules live in `Classes/Modules/<Feature>/` (face, motion, color, line, object tracking, stasis, brightness, picture, video, and others). Several are GPUImage filter chains, with custom filters in `Classes/Filters/`.
- `RMFakeVision` is a stand-in for running without a camera.
- Files that touch OpenCV must be `.mm`. `RMVisionModuleProtocol.h` guards C++ with `#ifdef __cplusplus`, so it can still be included from plain `.m` files.

### RMCharacter
- `RMCharacter` (`+[RMCharacter Romo]`) is a facade over `RMCharacterFace` (eye, pupil, and animation views, driven by expressions and emotions), `RMCharacterVoice` (plays `.caf` sounds), and `RMCharacterPNS`. PNS is a "peripheral nervous system" timer that fires idle blink, look, and breathe signals.
- Assets in `RMCharacter/Assets/Media.xcassets` are images (looked up by imageset name), sprite-crop JSON and `.caf` sounds (both datasets). The podspec uses `resources` instead of a `resource_bundle`, and the README warns that CocoaPods consumers must not use `use_frameworks!`. See above for how SwiftPM loads them.

## Constraints

- Minimum iOS version is 15.5 (podspec, example Podfiles, and example Xcode projects), with ARC. The README advertises iOS 15.5–17 support.
- Apps using RMCore need `com.romotive.romo` under `Supported external accessory protocols` in their Info.plist. Background mode also needs "App communicates with an accessory".
