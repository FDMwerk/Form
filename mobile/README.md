# Form for iPhone and iPad — development prototype

A separate UIKit/WKWebView application for iOS/iPadOS 17+, sharing the local Form renderer. This is not the released macOS application and is not yet on TestFlight or the App Store.

## Build

From the repository root (Node 22.12+, Xcode with an installed iOS simulator runtime, XcodeGen):

```sh
npm ci
npm run build
xcodegen generate --spec mobile/project.yml
xcodebuild -project mobile/FormMobile.xcodeproj -scheme FormMobile -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
node mobile/viewport-test.mjs
node mobile/native-chrome-test.mjs
```

Open `mobile/FormMobile.xcodeproj`, select `FormMobile`, then an iPhone/iPad simulator. For real-device installation select an authorized development team and provision the separate `de.fdmwerk.form.mobile` identifier. No new distribution certificate or Store submission is performed by these steps.

Run hosted WebKit integration tests with `xcodebuild ... -destination 'platform=iOS Simulator,id=DEVICE_UUID' test`. The tests queue valid/invalid/valid imports before readiness, verify both valid models appear, check phone overflow and the mobile adapter; they also reject remote-page URLs and unknown extensions.

## Bundled example

The original `3DBenchy.stl` from MakerWorld 40146 is included unchanged under `Resources/Examples/`, with provenance and attribution (CreativeTools, shared by Bambu Lab, CC BY-ND 4.0). It is **not MIT-licensed**. Tap **3DBenchy** on the empty screen or below Open in the sidebar; no download is required. The in-app Privacy & Licenses page includes the credit. Sharing this example also supplies its attribution file. A hash-checked native test opens it through that same example button. Debug builds support `--example` for simulator demo startup.

## Implemented first slice

- Native multi-file picker for Files/iCloud providers and document-open registration for supported model attachments (STL, STEP/STP, IGES, BREP, OBJ, PLY, 3MF, GLB/GLTF).
- Coordinated security-scoped reads, sequential imports, per-file 100 MiB ceiling, isolated session copies; source documents stay untouched. Web renderer has additional geometry validation.
- Existing local CAD/mesh renderer, model tree, visibility, measurements, sections, materials and information panels. One-finger orbit, two-finger pan/pinch; taps measure. Gesture end is gated so navigation does not create extra measurements.
- Native system navigation/toolbars and SF Symbols (Liquid Glass on iOS 26+), fewer primary actions on iPhone, additional direct actions on wide iPads; all secondary tools and units remain reachable through native menus. Modern UIScene lifecycle supports separate document windows.
- Phone overlays for tree/info; wider tablet layout; scrollable 44pt icon controls. System language and existing viewer translations; mobile panel labels in DE/EN/ZH/JA/HI/RU.
- Native share sheet for the **original** imported file and screenshot. Sharing does not export transformations, measurements or the scene and does not confirm slicing or printing. Only apps accepting the actual type appear in Apple's sheet.
- Nonpersistent web storage; local preference persistence; privacy manifest; no automatic model upload, analytics or Bambu credentials.

## Still required before release

Physical iPhone/iPad validation of Mail, Files/iCloud providers, memory/large CAD imports, accessibility/VoiceOver, touch measurements/cube and landscape. Some native prototype errors remain English. Multi-file external GLTF/OBJ dependencies need explicit packaging support. Harden resource/memory recovery and session-copy cleanup. Add verified machine/nozzle/profile catalogue and prototype setup UI; selecting PLA/PETG must not pretend to produce G-code. Follow the [Bambu investigation](../docs/MOBILE_BAMBU_HANDOFF.md) before promising a supported direct-print route. Add device signing/TestFlight, mobile icons/screenshots, full localization and a separate Store review only after these checks.

The macOS app already submitted to Apple stays at its immutable release build. Building this prototype does not replace `/Applications/Form.app`.
